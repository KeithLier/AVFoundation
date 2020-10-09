//
//  ViewController.swift
//  AVFoundation
//
//  Created by keith on 2020/9/30.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var array: NSArray = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "audioTableViewCell")
        array = [
            ["name":"AVAudioPlayer","vc":"AudioController"],
            ["name":"AVAseet","vc":"AssetController"],
            ["name":"AVPlayer","vc":"PlayerController"],
            ["name":"Separation","vc":"SeparationController"],
            ["name":"Camera","vc":"VideoCameraController"]

        ]
        tableView.reloadData();
    }    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return array.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "audioTableViewCell", for: indexPath)
        let item: Dictionary = array[indexPath.row] as! Dictionary<String, Any>
        let name:String = item["name"] as! String
        cell.textLabel?.text = name
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item: Dictionary = array[indexPath.row] as! Dictionary<String, Any>
        let vc:String = item["vc"] as! String
        let controller = getViewControllerWithCalssName(vc)
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func getViewControllerWithCalssName(_ className: String) -> UIViewController {
         
         // 准备工作: 命名空间: 必须指定那个bundle(包)
         // 从Info.plist中获取bundle的名字
         let namespace = Bundle.main.infoDictionary!["CFBundleName"] as! String
         // 0.将控制器的字符串转成控制器类型
         let classFromStr: AnyClass? = NSClassFromString(namespace + "." + className)
         let viewControllerClass = classFromStr as! UIViewController.Type
         // 1.创建控制器对象
         let viewController = viewControllerClass.init()
         
         return viewController;
         
     }
    
}


