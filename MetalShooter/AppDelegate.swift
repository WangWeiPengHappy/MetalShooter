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
    
    // MARK: - Menu Outlets
    
    /// Triangle菜单项
    @IBOutlet weak var triangleMenuItem: NSMenuItem!
    
    /// 鼠标捕获菜单项
    @IBOutlet weak var mouseCaptureMenuItem: NSMenuItem!
    
    /// Weapon菜单项
    @IBOutlet weak var weaponMenuItem: NSMenuItem!
    
    /// Arms菜单项
    @IBOutlet weak var armsMenuItem: NSMenuItem!
    
    // MARK: - Triangle Control Properties
    
    /// 三角形显示状态
    private var triangleVisible: Bool = true
    
    /// 武器显示状态
    private var weaponVisible: Bool = true
    
    /// 手臂显示状态 
    private var armsVisible: Bool = true
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        print("MetalShooter 启动完成")
        
        // 🚀 第二阶段：启动游戏引擎
        print("🚀 第二阶段开发：Metal渲染管线启动")
        
        // 初始化并启动游戏引擎
        let gameEngine = GameEngine.shared
        gameEngine.initialize()
        gameEngine.start()
        
        // 同步初始武器、手臂和三角形可见性状态
        DispatchQueue.main.async {
            self.updateWeaponVisibility()
            self.updateArmsVisibility()
            self.updateTriangleVisibility()
            self.updateTriangleMenuState()
            self.updateWeaponMenuState()
            self.updateArmsMenuState()
            self.updateMouseCaptureMenuState()
            
            // 设置定时器定期更新鼠标捕获菜单状态（响应ESC键操作）
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.updateMouseCaptureMenuState()
            }
            
            print("🔄 初始化武器、手臂、三角形和鼠标捕获状态同步完成")
        }
        
        print("🎮 Metal4 射击游戏引擎已启动")
        print("✨ 准备渲染第一个三角形...")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Triangle Control Actions
    
    /// 切换三角形显示状态
    @IBAction func toggleTriangle(_ sender: Any) {
        triangleVisible.toggle()
        let status = triangleVisible ? "显示" : "隐藏"
        print("🔄 菜单操作: 切换三角形显示状态 -> \(status)")
        updateTriangleVisibility()
        updateTriangleMenuState()
    }
    
    /// 更新三角形的显示状态
    private func updateTriangleVisibility() {
        // 通过GameEngine控制三角形显示
        GameEngine.shared.setTriangleVisible(triangleVisible)
        let status = triangleVisible ? "可见" : "隐藏"
        print("🔺 三角形显示状态已更新: \(status)")
    }
    
    /// 更新Triangle菜单项的checkbox状态
    private func updateTriangleMenuState() {
        triangleMenuItem?.state = triangleVisible ? .on : .off
    }
    
    // MARK: - Mouse Capture Control
    
    /// 切换鼠标捕获状态
    @IBAction func toggleMouseCapture(_ sender: Any) {
        InputManager.shared.toggleMouseCapture()
        updateMouseCaptureMenuState()
        
        let status = InputManager.shared.isMouseCaptured ? "启用" : "禁用"
        print("🖱️ 菜单操作: 鼠标捕获状态切换 -> \(status)")
    }
    
    /// 更新鼠标捕获菜单项状态
    private func updateMouseCaptureMenuState() {
        mouseCaptureMenuItem?.state = InputManager.shared.isMouseCaptured ? .on : .off
        let title = InputManager.shared.isMouseCaptured ? "Disable Mouse Capture" : "Enable Mouse Capture"
        mouseCaptureMenuItem?.title = title
    }
    
    // MARK: - First Person Rendering Control Actions
    
    /// 显示武器
    @IBAction func showWeapon(_ sender: Any) {
        print("🔫 菜单操作: 显示武器")
        weaponVisible = true
        updateWeaponVisibility()
    }
    
    /// 隐藏武器
    @IBAction func hideWeapon(_ sender: Any) {
        print("🔫 菜单操作: 隐藏武器")
        weaponVisible = false
        updateWeaponVisibility()
    }
    
    /// 切换武器显示状态
    @IBAction func toggleWeapon(_ sender: Any) {
        weaponVisible.toggle()
        let status = weaponVisible ? "显示" : "隐藏"
        print("🔫 菜单操作: 切换武器显示状态 -> \(status)")
        updateWeaponVisibility()
        updateWeaponMenuState()
    }
    
    /// 显示手臂
    @IBAction func showArms(_ sender: Any) {
        print("🖐 菜单操作: 显示手臂")
        armsVisible = true
        updateArmsVisibility()
    }
    
    /// 隐藏手臂
    @IBAction func hideArms(_ sender: Any) {
        print("🖐 菜单操作: 隐藏手臂")
        armsVisible = false
        updateArmsVisibility()
    }
    
    /// 切换手臂显示状态
    @IBAction func toggleArms(_ sender: Any) {
        armsVisible.toggle()
        let status = armsVisible ? "显示" : "隐藏"
        print("🖐 菜单操作: 切换手臂显示状态 -> \(status)")
        updateArmsVisibility()
        updateArmsMenuState()
    }
    
    /// 播放射击动画
    @IBAction func playShootAnimation(_ sender: Any) {
        print("💥 菜单操作: 播放射击动画")
        GameEngine.shared.playWeaponAnimation(.shoot)
    }
    
    /// 播放装弹动画
    @IBAction func playReloadAnimation(_ sender: Any) {
        print("🔄 菜单操作: 播放装弹动画")
        GameEngine.shared.playWeaponAnimation(.reload)
    }
    
    /// 重置武器动画
    @IBAction func resetWeaponAnimation(_ sender: Any) {
        print("🔄 菜单操作: 重置武器动画")
        GameEngine.shared.playWeaponAnimation(.idle)
    }
    
    /// 更新武器的显示状态
    private func updateWeaponVisibility() {
        GameEngine.shared.setWeaponVisible(weaponVisible)
        let status = weaponVisible ? "可见" : "隐藏"
        print("🔫 武器显示状态已更新: \(status)")
    }
    
    /// 更新手臂的显示状态
    private func updateArmsVisibility() {
        GameEngine.shared.setArmsVisible(armsVisible)
        let status = armsVisible ? "可见" : "隐藏"
        print("🖐 手臂显示状态已更新: \(status)")
    }
    
    /// 更新Weapon菜单项的checkbox状态
    private func updateWeaponMenuState() {
        weaponMenuItem?.state = weaponVisible ? .on : .off
    }
    
    /// 更新Arms菜单项的checkbox状态
    private func updateArmsMenuState() {
        armsMenuItem?.state = armsVisible ? .on : .off
    }
    
}
