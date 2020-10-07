//
//  AssetController.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/4.
//

import UIKit
import AVFoundation

class AssetController: UIViewController {
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var videoExport:AVAssetExportSession?
    var audioExport:AVAssetExportSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadAsset()
    }

    func loadAsset() {
        // 第一种方式
        let path = Bundle.main.path(forResource: "1", ofType: "mp4")
        let asset = AVAsset(url: URL(fileURLWithPath: path!, isDirectory: true))
        
//        // 第二种方式
//        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true];   // 获取精准的播放时间
//        let urlAsset = AVURLAsset(url: URL(fileURLWithPath: path!, isDirectory: true), options: options)
        
        // 播放视频
        let videoTrack = asset.tracks(withMediaType: .video)
        playTrack(track: videoTrack.first)
        
        getAssetAttribute()
        getImageByAsset()
        exportAsset()
    }

    // 播放
    func playTrack(track: AVAssetTrack?) {
        guard let asset = track?.asset else {
            return
        }
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        self.view.layer.addSublayer(playerLayer)
        player?.play()
    }
    
    // 获取Asset相关属性
    func getAssetAttribute() {
        let path = Bundle.main.path(forResource: "1", ofType: "mp4")
        let asset = AVAsset(url: URL(fileURLWithPath: path!, isDirectory: true))
        // 时长
        let duration = asset.duration.seconds
        // 歌词
        let lyrics = asset.lyrics
        // 创建时间，通常从相册加载会有数据
        let creatDate = asset.creationDate?.dateValue
        // 相关信息，如 iso
        let metadata = asset.metadata(forFormat: .isoUserData)
        
        print(duration, lyrics ?? "" , creatDate ?? "", metadata)
    }
    
    // 从视频中获取视频帧 图像
    func getImageByAsset() {
        let path = Bundle.main.path(forResource: "1", ofType: "mp4")
        let asset = AVAsset(url: URL(fileURLWithPath: path!, isDirectory: true))
        if asset.tracks(withMediaType: .video).count > 0 {
            let imgGen = AVAssetImageGenerator(asset: asset)
            // 最大尺寸
            imgGen.maximumSize = CGSize(width: 100, height: 100)
            // 光圈
            imgGen.apertureMode = AVAssetImageGenerator.ApertureMode.cleanAperture
            
            // 异步加载多个
            imgGen.generateCGImagesAsynchronously(forTimes: [NSValue(time:CMTime.zero)]) { (time1, cgimage, time2, result, error) in
                if let _cgimg = cgimage {
                    let img = UIImage(cgImage: _cgimg)
                    print("async get a image by asset")
                }
            }
            
            var actrueTime: CMTime = CMTime.zero
            // 同步加载一个
            if let cgimg = try? imgGen.copyCGImage(at: CMTime.zero, actualTime: &actrueTime) {
                let img = UIImage(cgImage: cgimg)
                print("sync get a image by asset")
            }
        }
    }
    
    // 导出视频或者音频
    func exportAsset() {
        guard let path = Bundle.main.path(forResource: "1", ofType: "mp4") else {
            return
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let videoTracks = asset.tracks(withMediaType: .video)
        let audioTracks = asset.tracks(withMediaType: .audio)
        let firstVideoTrack = videoTracks.first
        let firstAudioTrack = audioTracks.first
        
        // 视频
        let videoComposition = AVMutableComposition()
        if let compositionVideoTrack = videoComposition.addMutableTrack(withMediaType: .video, preferredTrackID: 0) {
            if firstVideoTrack != nil {
                try? compositionVideoTrack.insertTimeRange(firstVideoTrack!.timeRange, of: firstVideoTrack!, at: .zero)
                videoExportSession(asset: videoComposition)
                
            }
        }
        
        // 音频
        let audioComposition = AVMutableComposition()
        if let compositionAudioTrack = audioComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0) {
            if firstAudioTrack != nil {
                try? compositionAudioTrack.insertTimeRange(firstAudioTrack!.timeRange, of: firstAudioTrack!, at: .zero)
                audioExportSession(asset: audioComposition)
            }
        }
        
    }
    
}

extension AssetController {
    // 导出视频
    func videoExportSession(asset: AVAsset) {
        // presetNames 本视频支持导出的格式 AVAssetExportPresetPassthrough未模拟器支持格式
        let presetNames = AVAssetExportSession.exportPresets(compatibleWith: asset)
        // 设置 AVAssetExportPreset640x480等可选参数
        videoExport = AVAssetExportSession(asset: asset, presetName: presetNames.first ?? AVAssetExportPresetPassthrough)
        
        videoExport?.outputURL = getVideoUrl()
        videoExport?.outputFileType = AVFileType.mp4
        // 需要裁剪，设置相关参数
        videoExport?.timeRange = getTimeRange(asset: asset)
        videoExport?.exportAsynchronously(completionHandler: {[weak self] in
            print(self?.audioExport?.error)
        })
    }

    // 获取导出video的url
    func getVideoUrl() -> URL {
        let path =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "Quinn_export" + ".mp4"
        let url = path.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path){
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
    
    // 导出音频
    func audioExportSession(asset: AVAsset) {
        let presetNames = AVAssetExportSession.exportPresets(compatibleWith: asset)
        if presetNames.contains(AVAssetExportPresetAppleM4A) {
            audioExport = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        } else {
            audioExport = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        }
        audioExport?.outputURL = getAudioExportUrl()
        audioExport?.outputFileType = AVFileType.m4a
        audioExport?.shouldOptimizeForNetworkUse = true
        audioExport?.exportAsynchronously(completionHandler: {[weak self] in
            print(self?.audioExport?.error)
        })
    }
    
    // 获取导出的url
    func getAudioExportUrl() -> URL {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "Quinn_export" + ".m4a"
        let url = path.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    
}


extension AssetController {
    // 公共函数
    // 设置裁剪参数
    func getTimeRange(asset: AVAsset) -> CMTimeRange {
        let start = CMTimeMake(value: Int64(asset.duration.timescale * 10), timescale: asset.duration.timescale)
        let end = CMTimeMake(value: Int64(asset.duration.timescale * 30), timescale: asset.duration.timescale)
        let range = CMTimeRange(start: start, end: end)
        return range
    }
}
