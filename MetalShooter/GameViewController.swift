//
//  GameViewController.swift
//  MetalShooter
//
//  Created by eric_wang on 2025/8/6.
//

import Cocoa
import MetalKit

/// macOS游戏视图控制器
/// 注意：当前版本使用GameEngine进行初始化，此视图控制器主要用于storyboard兼容性
class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 游戏引擎现在在AppDelegate中启动
        // 此视图控制器保留用于storyboard兼容性
        print("🎮 GameViewController已加载 - 游戏引擎通过AppDelegate管理")
        
        guard let mtkView = self.view as? MTKView else {
            print("⚠️ View attached to GameViewController is not an MTKView")
            return
        }
        
        print("🖥️ MTKView已找到: \(mtkView)")
    }
}
