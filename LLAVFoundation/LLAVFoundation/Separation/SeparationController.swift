//
//  SeparationController.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/7.
//

import UIKit
import AVFoundation

class SeparationController: UIViewController {

    var audioExport:AVAssetExportSession?
    var audioComposition: AVMutableComposition?

    var videoExport:AVAssetExportSession?
    var videoComposition: AVMutableComposition?

    var mutableExport:AVAssetExportSession?
    var mutableComposition: AVMutableComposition?
    
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    @IBOutlet weak var playerView: PlayerView?


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func audioExport(_sender: Any) {
        setAudioAndExport()
    }

    @IBAction func videoExport(_sender: Any) {
        setVideoExport()
    }

    @IBAction func multiExport(_sender: Any) {
        setMultiExport()
    }

    func play(asset: AVAsset) {
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        playerView?.player = player
        player?.play()
    }
}


// 音频拼接导出
extension SeparationController {
    func setAudioAndExport() {
        guard let path = Bundle.main.path(forResource: "1", ofType: "mp3") else {
            return
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let audioTracks = asset.tracks(withMediaType: .audio)
        let firstAudioTrack = audioTracks.first
        
        guard let spath = Bundle.main.path(forResource: "2", ofType: "mp3") else {
            return
        }
        let surl = URL(fileURLWithPath: spath)
        let sAsset = AVAsset(url: surl)
        let sAudioTracks = sAsset.tracks(withMediaType: .audio)
        let aFirstAudioTrack = sAudioTracks.first
        
        // 音频拼接
        audioComposition = AVMutableComposition()
        if let compositionAudioTrack = audioComposition?.addMutableTrack(withMediaType: .audio, preferredTrackID: 0) {
            try? compositionAudioTrack.insertTimeRanges([NSValue(timeRange: firstAudioTrack!.timeRange) ,NSValue(timeRange: firstAudioTrack!.timeRange)], of: [aFirstAudioTrack!,firstAudioTrack!], at: .zero)
            AudioExportSession(asset: audioComposition!)
        }
    }
    
    func AudioExportSession(asset: AVAsset) {
        let presetNames = AVAssetExportSession.exportPresets(compatibleWith: asset)
        if presetNames.contains(AVAssetExportPresetAppleM4A) {
            audioExport = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        } else {
            audioExport = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        }
        audioExport?.outputURL = getExportUlrWithFileName(fileName: "export_separation_audio.m4a")
        audioExport?.outputFileType = AVFileType.m4a
//        if isSimulator() {
//            audioExport?.outputFileType = AVFileType.caf
//        } else {
//            audioExport?.outputFileType = AVFileType.m4a
//        }
        audioExport?.shouldOptimizeForNetworkUse = true
        audioExport?.exportAsynchronously(completionHandler: {
            
        })
    }
}

// 视频拼接导出
extension SeparationController {
    func setVideoExport() {
        guard let path = Bundle.main.path(forResource: "1", ofType: "mp4") else {
            return
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let videoTracks = asset.tracks(withMediaType: .video)
        let firstVideoTrack = videoTracks.first

        guard let spath = Bundle.main.path(forResource: "2", ofType: "mp4") else {
            return
        }
        let surl = URL(fileURLWithPath: spath)
        let sasset = AVAsset(url: surl)
        let svideoTracks = sasset.tracks(withMediaType: .video)
        let sfirstVideoTrack = svideoTracks.first

        videoComposition = AVMutableComposition()
        if let compositionVideoTrack = videoComposition?.addMutableTrack(withMediaType: .video, preferredTrackID: 0) {
            if firstVideoTrack != nil {
                try? compositionVideoTrack.insertTimeRange(firstVideoTrack!.timeRange, of: firstVideoTrack!, at: .zero)
                try? compositionVideoTrack.insertTimeRange(sfirstVideoTrack!.timeRange, of: sfirstVideoTrack!, at: .zero)
                videoExportSession(asset: videoComposition!)
            }
        }
    }
    
    func videoExportSession(asset: AVAsset) {
        let presetNames = AVAssetExportSession.exportPresets(compatibleWith: asset)
        videoExport = AVAssetExportSession(asset: asset, presetName: presetNames.first ?? AVAssetExportPresetPassthrough)
        videoExport?.outputURL = getExportUlrWithFileName(fileName: "export_separation_video.mp4")
        videoExport?.outputFileType = AVFileType.mp4
        videoExport?.exportAsynchronously(completionHandler: {
            
        })
    }
}

// 多音视频拼接
extension SeparationController {
    func setMultiExport() {
        //video track
        //video asset1
        guard let path = Bundle.main.path(forResource: "1", ofType: "mp4") else {
            return
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let videoTracks = asset.tracks(withMediaType: .video)
        let firstVideoTrack = videoTracks.first
        //video asset2
        guard let spath = Bundle.main.path(forResource: "2", ofType: "mp4") else {
            return
        }
        let surl = URL(fileURLWithPath: spath)
        let sasset = AVAsset(url: surl)
        let svideoTracks = sasset.tracks(withMediaType: .video)
        let sfirstVideoTrack = svideoTracks.first
        //audio track
        //audio asset1
        guard let audioPath = Bundle.main.path(forResource: "1", ofType: "mp3") else {
            return
        }
        let audioUrl = URL(fileURLWithPath: audioPath)
        let audioAsset = AVAsset(url: audioUrl)
        let audioTracks = audioAsset.tracks(withMediaType: .audio)
        let firstAudioTrack = audioTracks.first
        
        //audio asset2
        guard let saudioPath = Bundle.main.path(forResource: "2", ofType: "mp3") else {
            return
        }
        let saudioUrl = URL(fileURLWithPath: saudioPath)
        let saudioAsset = AVAsset(url: saudioUrl)
        let saudioTracks = saudioAsset.tracks(withMediaType: .audio)
        let sfirstAudioTrack = saudioTracks.first
        //保证总时长一致
        //视频
        mutableComposition = AVMutableComposition()
        let timeRange = CMTimeRange(start: CMTime(value: 0, timescale: 1), end: CMTime(value: 60, timescale: 1))
        
        if let compositionVideoTrack = mutableComposition?.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            if firstVideoTrack != nil {
                try? compositionVideoTrack.insertTimeRange(timeRange, of: firstVideoTrack!, at: .zero)
                try? compositionVideoTrack.insertTimeRange(timeRange, of: sfirstVideoTrack!, at: .zero)
            }
        }
        if let compositionAudioTrack = mutableComposition?.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compositionAudioTrack.insertTimeRange(timeRange, of: firstAudioTrack!, at: .zero)
            try? compositionAudioTrack.insertTimeRange(timeRange, of: sfirstAudioTrack!, at: .zero)
        }
        mutableExportSession(asset: mutableComposition!)
    }
    
    func mutableExportSession(asset: AVAsset) {
        let presetNames = AVAssetExportSession.exportPresets(compatibleWith: asset)
        mutableExport = AVAssetExportSession(asset: asset, presetName: presetNames.first ?? AVAssetExportPresetPassthrough)
        mutableExport?.outputURL = getExportUlrWithFileName(fileName: "export_separation_mutable_video.mp4")
        if isSimulator() {
            mutableExport?.outputFileType = AVFileType.mov
        } else {
            mutableExport?.outputFileType = AVFileType.mp4
        }
        mutableExport?.exportAsynchronously(completionHandler: {
            
        })
    }
}

// 公共函数
extension SeparationController {
    func getExportUlrWithFileName(fileName: String) -> URL {
        let path =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = path.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path){
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
    
    func isSimulator() -> Bool {
        var isSim = false
        #if arch(i386) || arch(x86_64)
        isSim = true
        #endif
        return isSim
    }
}
