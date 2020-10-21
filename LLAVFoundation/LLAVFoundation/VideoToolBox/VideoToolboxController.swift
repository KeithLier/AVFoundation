//
//  VideoToolboxController.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/21.
//

import UIKit
import AVFoundation
import VideoToolbox

class VideoToolboxController: UIViewController {

    var captureDeviceInput: AVCaptureDeviceInput?
    var captureSession: AVCaptureSession?
    var displayLayer: AVSampleBufferDisplayLayer?
    var captureQuene: DispatchQueue?
    var encodeQuene: DispatchQueue?
    var compressionSession: VTCompressionSession?
    var frameID: Int64 = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func captureClick(_sender: Any) {
        if captureSession == nil || captureSession?.isRunning == false {
            startCapture()
        } else {
            stopCapture()
        }
    }
    
    func startCapture() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            return
        }
        captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        captureQuene = DispatchQueue.global()
        encodeQuene = DispatchQueue.global()
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),captureSession.canAddInput(videoDeviceInput) else {
            return
        }
        captureSession.addInput(videoDeviceInput)
        
        let captureDataOutPut = AVCaptureVideoDataOutput()
        captureDataOutPut.alwaysDiscardsLateVideoFrames = false
        captureDataOutPut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        captureDataOutPut.setSampleBufferDelegate(self, queue: captureQuene)
        if captureSession.canAddOutput(captureDataOutPut) {
            captureSession.addOutput(captureDataOutPut)
        }
        let connection = captureDataOutPut.connection(with: .video)
        connection?.videoOrientation = .portrait
//        previewView.videoPreviewLayer.session = captureSession
//        previewView.videoPreviewLayer.videoGravity = .resizeAspect
        
        captureSession.startRunning()
    }
    
    func stopCapture() {
        captureSession?.stopRunning()
    }

    func encodeBuffer(buffer: CMSampleBuffer) {
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(buffer)!
        //􏴒􏸀􏶅􏱕􏵙􏳗􏲔􏲯􏲒􏴒􏸀􏴂􏹉􏷼􏱕􏵙􏹊􏳹􏸖􏳧􏱕􏵙􏷽􏰤 􏴒􏸀􏶅􏱕􏵙􏳗􏲔􏲯􏲒􏴒􏸀􏴂􏹉􏷼􏱕􏵙􏹊􏳹􏸖􏳧􏱕􏵙􏷽􏰤设置帧时间，如果不设置会导致时间轴过长，时间戳以ms为单位
        let timeStamp = CMTimeMake(value: frameID, timescale: 1000)
        var flags: VTEncodeInfoFlags = VTEncodeInfoFlags()
        
        VTCompressionSessionEncodeFrame(compressionSession!, imageBuffer: imageBuffer, presentationTimeStamp: timeStamp, duration: CMTime.invalid, frameProperties: nil, infoFlagsOut: &flags) { (status, flags, buffer) in
            if(status != noErr) {
                print("H.264:VTCompressionSessionEncodeFrame faild with %d",status)
                VTCompressionSessionInvalidate(self.compressionSession!)
                self.compressionSession = nil
            }
            print("H264:VTCompressionSessionEncodeFrame Success");
        }
    }
}

extension VideoToolboxController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.encodeQuene?.sync {
            self.encodeBuffer(buffer: sampleBuffer)
        }
    }
}

