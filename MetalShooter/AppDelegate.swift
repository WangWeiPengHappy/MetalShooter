//
//  AppDelegate.swift
//  MetalShooter
//
//  Created by eric_wang on 2025/8/6.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet var window: NSWindow!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        print("MetalShooter 启动完成")
        
        // 🚀 第二阶段：启动游戏引擎
        print("🚀 第二阶段开发：Metal渲染管线启动")
        
        // 初始化并启动游戏引擎
        let gameEngine = GameEngine.shared
        gameEngine.initialize()
        gameEngine.start()
        
        print("🎮 Metal4 射击游戏引擎已启动")
        print("✨ 准备渲染第一个三角形...")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
