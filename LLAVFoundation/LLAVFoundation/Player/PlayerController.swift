//
//  PlayerController.swift
//  LLAVFoundation
//
//  Created by keith on 2020/10/5.
//

import UIKit
import AVFoundation

class PlayerController: UIViewController {

    @IBOutlet weak var playerView: PlayerView?
    @IBOutlet weak var playButton: UIButton?
    var player: AVPlayer?
    var playerItem: AVPlayerItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        syncUI()
        loadAssetFormFile()
        // Do any additional setup after loading the view.
    }

    @IBAction func play(_ sender: Any) {
        player?.play()
    }
    // 获取asset
    func loadAssetFormFile() {
        let fileUrl: URL = Bundle.main.url(forResource: "1", withExtension: "mp4")!
        let asset = AVURLAsset(url: fileUrl, options: nil)
        let trackKey: String = "tracks"
        asset.loadValuesAsynchronously(forKeys: [trackKey]) {
            DispatchQueue.main.async {
                let status: AVKeyValueStatus = asset.statusOfValue(forKey: trackKey, error: nil)
                if status == AVKeyValueStatus.loaded {
                    self.playerItem = AVPlayerItem(asset: asset)
                    self.playerItem?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.initial, context: nil)
                    NotificationCenter.default.addObserver(self, selector: #selector(self.palyerItemDidReachEnd), name:  NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem)
                    self.player = AVPlayer(playerItem: self.playerItem)
                    self.playerView?.player = self.player
                }
            }
        }
        
    }
    
    @objc func palyerItemDidReachEnd(noti: Notification) {
        self.player?.seek(to: CMTime.zero)
    }
    // 同步UI
    func syncUI() {
        if self.player?.currentItem != nil && self.player?.currentItem?.status == AVPlayerItem.Status.readyToPlay {
            self.playButton?.isEnabled = true
        } else {
            self.playButton?.isEnabled = false
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            DispatchQueue.main.async {
                self.syncUI()
            }
            return
        }
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
}
