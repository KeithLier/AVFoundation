//
//  VideoCameraController.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/8.
//

import UIKit
import AVFoundation
import VideoToolbox

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
}

class VideoCameraController: UIViewController {

    var captureDeviceInput: AVCaptureDeviceInput?
    var captureSession: AVCaptureSession?
    var displayLayer: AVSampleBufferDisplayLayer?
    var captureQuene: DispatchQueue?
    var encodeQuene: DispatchQueue?
    var compressionSession: VTCompressionSession?
    var frameID: Int64 = 0
    @IBOutlet var previewView: PreviewView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCaptureSession()
                }
            }
        case .denied:
            return
        case .restricted:
            return
        default:
            return
        }

    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            return
        }
        captureSession.beginConfiguration()
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),captureSession.canAddInput(videoDeviceInput) else {
            return
        }
        captureSession.addInput(videoDeviceInput)
        let photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else {
            return
        }
        captureSession.sessionPreset = .photo
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()
        
        previewView.videoPreviewLayer.session = captureSession
        
        captureSession.startRunning()
    }
}

extension VideoCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.encodeQuene?.sync {
        }
    }
}
