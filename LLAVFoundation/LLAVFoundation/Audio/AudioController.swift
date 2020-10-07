//
//  AudioViewController.swift
//  AVFoundation
//
//  Created by keith on 2020/9/30.
//

import UIKit
import AVFoundation

class AudioController: UIViewController {

    var audioRecoder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    var index = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 创建音频会话
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch let error {
            debugPrint("Couldn't force audio to speaker: \(error)")
        }

    }

    // 存储录音的地址
    func saveAudioPath() -> String {
        let path:NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask,true).first! as NSString
        let audioName = String(NSDate().timeIntervalSince1970).appending(".caf")
        return path.appendingPathComponent(audioName)
    }
    
    func loadAllAudios() -> NSMutableArray {
        let path:NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask,true).first! as NSString
        let manager = FileManager()
        let allFiles = manager.subpaths(atPath: path as String)
        let audios = NSMutableArray()
        for item in allFiles! {
            let path = item as NSString
            if path.pathExtension == "caf" {
                audios.add(item)
            }
        }
        return audios
    }
    
    // 录音事件
    @IBAction func audioRecord(_ sender: Any) {
        let button:UIButton = sender as! UIButton
        if audioRecoder == nil {
            // 创建录音对象
            audioRecoder = try! AVAudioRecorder.init(url: NSURL.fileURL(withPath: saveAudioPath()), settings: [AVSampleRateKey:44100,AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue])
            audioRecoder.delegate = self
            audioRecoder!.prepareToRecord()
        }
        if(audioRecoder!.isRecording) {
            button.isSelected = false
            audioRecoder!.stop()
            audioRecoder = nil
        } else {
            button.isSelected = true
            audioRecoder!.record()
        }
    }

    // 播放录音事件
    @IBAction func audioPlay(_ sender: Any) {
        if audioPlayer != nil {
            audioPlayer = nil
            audioPlayer?.delegate = nil
        }
        let audios = loadAllAudios()
        let string: String = audios[index] as! String
        let path:NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask,true).first! as NSString
        let filePath = path.appendingPathComponent(string)
        let url: URL = NSURL.init(string: filePath)! as URL,
        audioPlayer = try! AVAudioPlayer.init(contentsOf: url)
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.play()
    }

}

// 设置录音代理
extension AudioController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        debugPrint("success");
    }

    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        debugPrint("error: \(String(describing: error))")
    }
}

// 设置播放录音的代理
extension AudioController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let audios = loadAllAudios()
        if index < audios.count {
            index += 1
        } else {
            index = 0
        }
        audioPlay((Any).self)
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        
    }
}
