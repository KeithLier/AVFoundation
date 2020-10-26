//
//  VideoToolboxController.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/21.
//

import UIKit
import AVFoundation
import Photos
import VideoToolbox

class VideoToolboxController: UIViewController {
    //按钮
    var recodButton:UIButton!
    
    var session : AVCaptureSession = AVCaptureSession()
    var queue = DispatchQueue(label: "quque")
    var input: AVCaptureDeviceInput?
    lazy var previewLayer  = AVCaptureVideoPreviewLayer(session: self.session)
    lazy var recordOutput = AVCaptureMovieFileOutput()
    
    let output = AVCaptureVideoDataOutput()
    
    var encodeSession:VTCompressionSession!
    var encodeCallBack:VTCompressionOutputCallback?
    
    var encoder : VideoEncoder!
    var decoder: VideoDecoder!
    var player: AAPLEAGLLayer?
    
    var fileHandle : FileHandle?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        previewLayer.frame = view.bounds
        previewLayer.isHidden = true
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        player = AAPLEAGLLayer(frame: view.bounds)
        view.layer.addSublayer(player!)
        
        recodButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        recodButton.backgroundColor = .gray
        recodButton.center.x = view.center.x
        recodButton.setTitle("start record", for: .normal)
        recodButton.addTarget(self, action: #selector(recordAction(btn:)), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: recodButton)
                
        startCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.height / 2)
        player?.frame = CGRect(x: 0, y: view.bounds.size.height / 2, width: view.bounds.size.width, height: view.bounds.size.height / 2)
    }
    
    func startCapture(){
        
        guard let device = getCamera(postion: .back) else{
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else{
            return
        }
        self.input = input
        if session.canAddInput(input) {
            session.addInput(input)
        }
        previewLayer.isHidden = false
        //视图重力
        previewLayer.videoGravity = .resizeAspect
        session.startRunning()
        
        //编码
        encoder = VideoEncoder(width: 480, height: 640)
        encoder.videoEncodeCallback {[weak self] (data) in
            self?.writeTofile(data: data)
            self?.decoder.decode(data: data)
        }
        encoder.videoEncodeCallBackSPSAndPPS {[weak self] (sps, pps) in
            //存入文件
            self?.writeTofile(data: sps)
            self?.writeTofile(data: pps)
            //直接解码
            self?.decoder.decode(data: sps)
            self?.decoder.decode(data: pps)
        }
        //解码
        decoder = VideoDecoder(width: 480, height: 640)
        decoder.setVideoDecodeCallBack { (image) in
            self.player?.pixelBuffer = image
        }
    }
    
    func writeTofile(data: Data){
        if #available(iOS 13.4, *) {
            try? self.fileHandle?.seekToEnd()
        } else {
            self.fileHandle?.seekToEndOfFile()
        }
        self.fileHandle?.write(data)
    }
    
    @objc func recordAction(btn:UIButton){
        btn.isSelected = !btn.isSelected
        if !session.isRunning{
            session.startRunning()
        }
        if btn.isSelected {
            
            btn.setTitle("stop record", for: .normal)
            
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output){
                session.addOutput(output)
            }
            output.alwaysDiscardsLateVideoFrames = false
            //这里设置格式为BGRA，而不用YUV的颜色空间，避免使用Shader转换
            //注意:这里必须和后面CVMetalTextureCacheCreateTextureFromImage 保存图像像素存储格式保持一致.否则视频会出现异常现象.
            output.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey)  :NSNumber(value: kCVPixelFormatType_32BGRA) ]
//            let connection: AVCaptureConnection = output.connection(with: .video)!
//            connection.videoOrientation = .portrait
            
            if fileHandle == nil{
                //生成的文件地址
                guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return  }
                let filePath =  "\(path)/video.h264"
                try? FileManager.default.removeItem(atPath: filePath)
                if FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil){
                    print("创建264文件成功")
                }else{
                    print("创建264文件失败")
                }
                fileHandle = FileHandle(forWritingAtPath: filePath)
            }
            
        }else{
            session.removeOutput(output)
            btn.setTitle("start record", for: .normal)
        }
    }
    
    //获取相机设备
    func getCamera(postion: AVCaptureDevice.Position) -> AVCaptureDevice? {
        var devices = [AVCaptureDevice]()
        
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
            devices = discoverySession.devices
        } else {
            devices = AVCaptureDevice.devices(for: AVMediaType.video)
        }
        
        for device in devices {
            if device.position == postion {
                return device
            }
        }
        return nil
    }

}

//MARK: -AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoToolboxController : AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //采集结果
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        encoder.encodeVideo(sampleBuffer: sampleBuffer)
    }
    
}
//MARK: -AVCaptureFileOutputRecordingDelegate
extension VideoToolboxController : AVCaptureFileOutputRecordingDelegate {
    
    //录制完成
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }
        
}

