//
//  VideoEncoder.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/20.
//

import UIKit
import VideoToolbox

class VideoEncoder: NSObject {
    var frameID: Int64 = 0
    var hasSpsPps = false
    var width: Int32 = 480
    var height: Int32 = 640
    var bitRate: Int32 = 480 * 640 * 3 * 4
    var fps: Int32 = 10
    var encodeQueue = DispatchQueue(label: "encode")
    var callBackQueue = DispatchQueue(label: "callback")
    
    var encodeSession: VTCompressionSession!
    var encodeCallBack: VTCompressionOutputCallback?
    
    var videoEncodeCallback: ((Data)-> Void)?
    func videoEncodeCallback(block:@escaping (Data)-> Void){
        self.videoEncodeCallback = block
    }
    var videoEncodeCallBackSPSAndPPS: ((Data,Data) -> Void)?
    func videoEncodeCallBackSPSAndPPS(block: @escaping (Data,Data) -> Void) {
        videoEncodeCallBackSPSAndPPS = block
    }
    
    init(width: Int32 = 480, height: Int32 = 640, bitRate: Int32? = nil, fps: Int32? = nil) {
        self.width = width
        self.height = height
        self.bitRate = bitRate != nil ? bitRate! : 480 * 640 * 3 * 4
        self.fps = fps != nil ? fps! : 10
        
        super.init()
        
        setCallBack()
        initVideoToolBox()
    }
    
    // 初始化编码器
    func initVideoToolBox() {
        // 创建VTCompressionSession
        /**
         参数解析
         allocator: 分配器，设置nil为默认分配
         width: 宽度
         height: 高度
         codecType: 编码类型，如kCMVideoCodecType_H264
         encoderSpecification: 编码规范，设置nil由videoToolbox自主选择
         imageBufferAttributes: 源像素缓冲区属性，设置nil不让videoToolbox创建，而是自己创建
         compressedDataAllocator: 压缩数据分配器，设置nil为默认的分配
         outputCallback: 回调，当VTCompressionSessionEncodeFrame被调用压缩一次后会被异步调用，设置nil时，需要调用VTCompressionSessionEncodeFrameWithOutputHandler方法进行压缩帧处理
         refcon: 回调客户定义的参考值
         compressionSessionOut: 编码会话变量
         */
        let state = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: width, height: height, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: encodeCallBack, refcon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self), compressionSessionOut: &self.encodeSession)
        if state != noErr {
            print("creat VTCompressionSession failed")
            return
        }
        // 设置实时编码输出
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        // 设置编码方式
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        // 设置是否产生B帧（B帧非必要，解码是可以抛弃）
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        // 设置关键帧时间间隔
        var frameInterval = 10
        let number = CFNumberCreate(kCFAllocatorDefault, .intType, &frameInterval)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: number)
        // 设置期望帧率 不代表实际帧率
        let fpscf = CFNumberCreate(kCFAllocatorDefault, .intType, &fps)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fpscf)
        // 设置平均码率 单位bps。 码率大，视频清晰，文件大。码率小，视频模糊，文件小
        let bitRateAvg = CFNumberCreate(kCFAllocatorDefault, .intType, &bitRate)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_AverageBitRate, value: bitRateAvg)
        // 码率限制
        let bitRateLimit: CFArray = [bitRate * 2, 1] as CFArray
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_DataRateLimits, value: bitRateLimit)
    }
    
    // 开始编码
    func encodeVideo(sampleBuffer: CMSampleBuffer) {
        if self.encodeSession == nil {
            initVideoToolBox()
        }
        encodeQueue.async {
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let time = CMTime(value: self.frameID, timescale: 1000)
            var flags: VTEncodeInfoFlags = VTEncodeInfoFlags()
            // 开始编码
            /**
             参数解析
             session: 编码会话变量
             imageBuffer: 未编码的数据
             presentationTimeStamp: 获取到的这个sampleBuffer数据的展示时间戳，每一个传给session的时间戳都要大于前一个展示的时间戳
             duration: 对于获取到sampleBuffer数据，这个帧的展示时间，如果没有展示时间信息，则设置为kCMTimeInvalid
             frameProperties: 包含这个帧的属性，帧的改变会影响后面的编码帧
             infoFlagsOut: 指向一个VTEncodeInfoFlags来接受一个编码操作
             outputHandler: 回调函数
             */
            VTCompressionSessionEncodeFrame(self.encodeSession, imageBuffer: imageBuffer!, presentationTimeStamp: time, duration: .invalid, frameProperties: nil, infoFlagsOut: &flags){ (status, flags, buffer) in
                if(status != noErr) {
                    print("H.264:VTCompressionSessionEncodeFrame faild with %d",status)
                }
                print("H264:VTCompressionSessionEncodeFrame Success");
            }
        }
    }
    
    // 设置回调
    func setCallBack() {
        // 编码完成回调
        encodeCallBack = {(outputCallbackRefCon, sourceFrameRefCon, status, flag, sampleBuffer) in
            // 指针对象转换
            let encoder: VideoEncoder = unsafeBitCast(outputCallbackRefCon, to: VideoEncoder.self)
            
            guard sampleBuffer != nil else {
                return
            }
            
            // 1.原始字节数据 8字节
            let buffer: [UInt8] = [0x00, 0x00, 0x00,0x01]
            // 2.字节转换 [UInt8] -> UnsafeBufferPointer<UInt8>
            let unsafeBufferPointer = buffer.withUnsafeBufferPointer {$0}
            // 3.格式转换 UnsafeBufferPointer<UInt8> -> UnsafePointer<UInt8>
            let unsafePointer = unsafeBufferPointer.baseAddress
            guard let startCode = unsafePointer else {
                return
            }
            // 判断当前是否关键帧
            let attachArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, createIfNecessary: false)
            let strKey = unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self)
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachArray, 0), to: CFDictionary.self)
            let keyFrame = !CFDictionaryContainsKey(dict, strKey)  // 没有strKey就是关键帧
            
            // 获取sps pps
            if keyFrame && !encoder.hasSpsPps {
                if let description = CMSampleBufferGetFormatDescription(sampleBuffer!) {
                    var spsSize: Int = 0, spsCount: Int = 0, spsHeaderLength: Int32 = 0
                    var ppsSize: Int = 0, ppsCount: Int = 0, ppsHeaderLength: Int32 = 0
                    
                    var spsDataPointer: UnsafePointer<UInt8>? = UnsafePointer(UnsafeMutablePointer<UInt8>.allocate(capacity: 0))
                    var ppsDataPointer : UnsafePointer<UInt8>? = UnsafePointer<UInt8>(bitPattern: 0)
                    
                    let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, parameterSetIndex: 1, parameterSetPointerOut: &spsDataPointer, parameterSetSizeOut: &spsSize, parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: &spsHeaderLength)
                    if spsStatus != noErr {
                        print("sps fail")
                    }
                    let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, parameterSetIndex: 1, parameterSetPointerOut: &ppsDataPointer, parameterSetSizeOut: &ppsSize, parameterSetCountOut: &ppsCount, nalUnitHeaderLengthOut: &ppsHeaderLength)
                    if ppsStatus != noErr {
                        print("pps fail")
                    }
                    
                    // 数据拼接
                    if let spsData = spsDataPointer, let ppsData = ppsDataPointer {
                        var spsDataValue = Data(capacity: 4 + spsSize)
                        spsDataValue.append(buffer, count: 4)
                        spsDataValue.append(spsData, count: spsSize)
                        
                        var ppsDataValue = Data(capacity: 4 + ppsSize)
                        ppsDataValue.append(startCode, count: 4)
                        ppsDataValue.append(ppsData, count: ppsSize)
                        
                        encoder.callBackQueue.async {
                            encoder.videoEncodeCallBackSPSAndPPS!(spsDataValue,ppsDataValue)
                        }
                    }
                }
            }
            
            let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer!)
            var dataPointer: UnsafeMutablePointer<Int8>? = nil
            var totalLength: Int = 0
            let blockState = CMBlockBufferGetDataPointer(dataBuffer!, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
            if blockState != noErr {
                print("获取data失败\(blockState)")
            }
            
            // NALU
            var offset: UInt32 = 0
            // 返回nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
            let lengthSize = 4
            // 循环写入nalu数据
            while offset < totalLength - lengthSize {
                // 获取nalu的数据长度
                var naluDataLength: UInt32 = 0
                memcpy(&naluDataLength, dataPointer! + UnsafeMutablePointer<Int8>.Stride(offset), lengthSize)
                // 大端转系统端
                naluDataLength = CFSwapInt32BigToHost(naluDataLength)
                // 获取到编码好的视频数据
                var data = Data(capacity: Int(naluDataLength) + lengthSize)
                data.append(buffer, count: 4)
                // 转化pointer；UnsafeMutablePointer<Int8> -> UnsafePointer<UInt8>
                let naluUnsafePointer = unsafeBitCast(dataPointer, to: UnsafePointer<UInt8>.self)
                data.append(naluUnsafePointer + UnsafePointer<UInt8>.Stride(offset + UInt32(lengthSize)),count: Int(naluDataLength))
                
                encoder.callBackQueue.async {
                    encoder.videoEncodeCallback!(data)
                }
                offset += (naluDataLength + UInt32(lengthSize))
            }
        }
        
    }
    
    deinit {
        if encodeSession != nil {
            VTCompressionSessionCompleteFrames(encodeSession, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(encodeSession)
            encodeSession = nil
        }
    }
}
