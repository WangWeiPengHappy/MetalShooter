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

    /// ShowGames菜单项（需要在Storyboard连接）
    @IBOutlet weak var showGamesMenuItem: NSMenuItem!

    /// 菜单状态同步（避免状态异常）
    private func syncMenuStates(showGamesMode: Bool) {
        if showGamesMode {
            showGamesMenuItem?.state = .on
            triangleMenuItem?.isEnabled = false
            triangleMenuItem?.state = .off
        } else {
            showGamesMenuItem?.state = .off
            triangleMenuItem?.isEnabled = true
            // 不自动选Triangle，保持当前 triangleVisible 状态
            triangleMenuItem?.state = triangleVisible ? .on : .off
        }
        updateDynamicTitles()
    }

    /// 动态更新菜单标题，展示当前模式和模型版本
    private func updateDynamicTitles() {
        let versionId = PlayerModelLoader.shared.currentVersion.identifier
        if showGamesMenuItem?.state == .on {
            showGamesMenuItem?.title = "ShowGames (\(versionId))"
        } else {
            showGamesMenuItem?.title = "ShowGames"
        }
        if triangleMenuItem?.isEnabled == false {
            triangleMenuItem?.title = "Show Triangle (disabled)"
        } else {
            triangleMenuItem?.title = triangleVisible ? "Show Triangle (on)" : "Show Triangle"
        }
    }
    
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
    // 启动游戏引擎
        
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
            // 确保菜单标题初始正确
            self.updateDynamicTitles()
            
            // 设置定时器定期更新鼠标捕获菜单状态（响应ESC键操作）
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.updateMouseCaptureMenuState()
            }

            // 默认进入 ShowGames 模式，直接显示玩家模型于窗口中心（无需用户点击菜单）
            // 延迟少许确保渲染器与系统初始化完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.showGamesMenuItem?.state != .on { // 避免重复切换
                    GameEngine.shared.setShowGamesMode(true)
                    self.showGamesMenuItem?.state = .on
                    self.triangleMenuItem?.isEnabled = false
                    self.triangleMenuItem?.state = .off
                    self.syncMenuStates(showGamesMode: true)
                    print("🚀 默认启用ShowGames模式: 玩家模型已显示在窗口中心")
                }
            }
        }
        print("🎮 游戏引擎已启动，准备渲染")
    }

    /// 若Storyboard未绑定ShowGames菜单项，运行时动态添加
    private func ensureShowGamesMenu() {
        // 生产环境：如果 storyboard 已正确配置，可直接返回；保留最小化安全逻辑（若缺失则静默添加）
        guard let mainMenu = NSApp.mainMenu else { return }
        // 若已存在直接返回
        if showGamesMenuItem != nil { return }
        // 查找同名条目
        for top in mainMenu.items where showGamesMenuItem == nil {
            if let sub = top.submenu, let found = sub.items.first(where: { $0.action == #selector(showGames(_:)) }) {
                showGamesMenuItem = found
                return
            }
        }
        // 最简兜底：附加到第一个有 submenu 的菜单
        if let first = mainMenu.items.first, let sub = first.submenu {
            let item = NSMenuItem(title: "ShowGames", action: #selector(showGames(_:)), keyEquivalent: "g")
            item.keyEquivalentModifierMask = [.command, .option]
            item.target = self
            sub.addItem(NSMenuItem.separator())
            sub.addItem(item)
            showGamesMenuItem = item
            syncMenuStates(showGamesMode: false)
        }
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
    
    
    // MARK: - ShowGames Menu Action
    
    /// showGames菜单项点击事件  
    @IBAction func showGames(_ sender: NSMenuItem) {
        print("🎮 showGames菜单被点击")
        // 判定当前是否已选中
        let currentlyOn = (showGamesMenuItem?.state == .on)
        if currentlyOn {
            // 关闭ShowGames模式
            GameEngine.shared.setShowGamesMode(false)
            showGamesMenuItem?.state = .off
            // 允许选择Triangle，但保持不选中（用户可手动再点）
            triangleMenuItem?.isEnabled = true
            triangleMenuItem?.state = .off
            print("🟡 已退出ShowGames模式，Triangle菜单恢复可用但未选中")
        } else {
            // 开启ShowGames模式
            GameEngine.shared.setShowGamesMode(true)
            showGamesMenuItem?.state = .on
            // 取消Triangle勾选并禁用
            triangleMenuItem?.state = .off
            triangleMenuItem?.isEnabled = false
            print("🟢 已进入ShowGames模式，Triangle菜单被禁用")
        }
        print("📌 当前玩家模型版本: \(PlayerModelLoader.shared.currentVersion.identifier)")
    syncMenuStates(showGamesMode: showGamesMenuItem?.state == .on)
    }
}
