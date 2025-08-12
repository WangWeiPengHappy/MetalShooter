//
//  GameEngine.swift
//  MetalShooter
//
//  游戏引擎核心 - 管理游戏循环、系统调度和渲染
//  整个游戏的主要控制中心
//

import Foundation
import Metal
import MetalKit
import Cocoa

/// 游戏引擎 - 整个游戏系统的核心管理器
/// 负责游戏循环、系统更新、渲染调度和生命周期管理
class GameEngine: NSObject {
    
    // MARK: - 单例
    
    /// 共享实例
    static let shared = GameEngine()
    
    /// 私有初始化器
    private override init() {
        super.init()
        print("🎮 GameEngine 创建")
    }
    
    // MARK: - 核心组件
    
    /// 渲染器
    private var renderer: MetalRenderer!
    
    /// 第一人称渲染器
    private var firstPersonRenderer: FirstPersonRenderer?
    
    /// 实体管理器
    private let entityManager = EntityManager.shared
    
    /// 时间管理器
    private let timeManager = Time.shared
    
    /// 输入管理器
    private let inputManager = InputManager.shared
    
    /// 玩家控制器
    private var playerController: PlayerController?
    
    /// Metal视图
    private var metalView: MTKView?
    
    /// 游戏窗口
    private var gameWindow: NSWindow?
    
    // MARK: - 游戏状态
    
    /// 游戏是否正在运行
    private var isRunning = false
    
    /// 游戏是否暂停
    private var isPaused = false
    
    /// 帧计数器
    private var frameCount: Int = 0
    
    /// 游戏系统列表
    private var gameSystems: [GameSystem] = []
    
    /// 上次快捷键触发时间
    private var lastHotkeyTime: Float = 0.0

    /// 是否处于ShowGames模式（显示外部OBJ PlayerModel）
    private var showGamesMode: Bool = false
    
    // MARK: - 公共访问器（用于测试）
    
    /// 获取游戏运行状态
    var currentlyRunning: Bool { return isRunning }
    
    /// 获取游戏暂停状态
    var currentlyPaused: Bool { return isPaused }
    
    /// 获取Metal渲染器（用于测试）
    var metalRenderer: MetalRenderer? { return renderer }
    
    /// 获取时间管理器（用于测试）
    var currentTimeManager: Time { return timeManager }
    
    /// 获取实体管理器（用于测试）
    var currentEntityManager: EntityManager { return entityManager }
    
    /// 获取PlayerController（用于测试）
    var currentPlayerController: PlayerController? { return playerController }

    // MARK: - 快捷键处理
    
    /// 处理简单快捷键
    private func handleSimpleHotkeys() {
        print("🔑 DEBUG: handleSimpleHotkeys() 方法被调用")
        
        // 检查P键：切换玩家模型显示
        let pKeyPressed = inputManager.isKeyPressed(.p)
        print("🔑 DEBUG: P键状态 = \(pKeyPressed)")
        
        if pKeyPressed {
            print("🔑 GameEngine: P键被按下！")
            // 使用简单的时间间隔防止重复触发
            let currentTime = timeManager.totalTime
            if currentTime - lastHotkeyTime > 0.3 { // 300ms间隔
                print("🔑 GameEngine: P键触发间隔检查通过")
                // 只有在非ShowGames模式且Triangle模式下才响应P键
                if !showGamesMode {
                    if renderer.isPlayerModelVisible {
                        // 如果当前显示的是程序生成模型并且P再次按下 -> 回到三角形
                        if PlayerModelLoader.shared.currentVersion == .generated {
                            print("🔄 P键: 隐藏程序生成玩家模型，回到三角形")
                            hidePlayerModelShowTriangle()
                        } else {
                            // 如果当前显示的不是generated（意外情况），仍然切回triangle
                            print("⚠️ 当前版本非generated却处于玩家模型显示，回退到三角形")
                            hidePlayerModelShowTriangle()
                        }
                    } else {
                        // 当前是Triangle -> 切换到程序生成玩家模型
                        print("🔄 P键: Triangle -> 显示程序生成玩家模型")
                        showGeneratedPlayerModel()
                    }
                } else {
                    print("ℹ️ 处于ShowGames模式，P键不执行切换")
                }
                lastHotkeyTime = currentTime
            } else {
                print("🔑 GameEngine: P键触发间隔未满，跳过")
            }
        }
        
        // 检查M键：运行模型测试
        if inputManager.isKeyPressed(.m) {
            let currentTime = timeManager.totalTime
            if currentTime - lastHotkeyTime > 0.5 { // 500ms间隔，防止重复测试
                runModelTest()
                lastHotkeyTime = currentTime
            }
        }
    }
    
    /// 运行模型测试
    private func runModelTest() {
        print("🧪 运行几何战士模型测试...")
        GeometricWarriorTest.runAllTests()
    }
    
    /// 设置测试三角形的可见性
    func setTestTriangleVisible(_ visible: Bool) {
        renderer?.isTestTriangleVisible = visible
        print("🔺 设置测试三角形可见性: \(visible)")
    }

    // MARK: - 初始化
    
    /// 初始化游戏引擎
    func initialize() {
        print("🚀 GameEngine 初始化开始...")
        
        // 1. 设置游戏窗口（使用现有窗口）
        setupGameWindow()
        
        // 2. 创建Metal视图
        createMetalView()
        
        // 3. 初始化渲染器
        initializeRenderer()
        
        // 4. 初始化输入管理器
        initializeInputManager()
        
        // 5. 初始化玩家控制器
        initializePlayerController()
        
        // 6. 注册游戏系统
        registerGameSystems()
        
        // 7. 初始化所有系统
        initializeGameSystems()
        
        // 8. 创建测试场景
        createTestScene()
        
        print("✅ GameEngine 初始化完成")
        print("   窗口大小: \(gameWindow?.frame.size ?? CGSize.zero)")
        print("   Metal视图: \(metalView?.drawableSize ?? CGSize.zero)")
    }
    
    // MARK: - 窗口和视图管理
    
    /// 设置游戏窗口（使用现有的主窗口）
    private func setupGameWindow() {
        // 使用应用程序的主窗口，而不是创建新窗口
        gameWindow = NSApplication.shared.mainWindow
        
        if gameWindow == nil {
            // 如果主窗口不存在，尝试从 windows 数组中获取第一个窗口
            gameWindow = NSApplication.shared.windows.first
        }
        
        guard let window = gameWindow else {
            fatalError("❌ 无法获取应用程序窗口")
        }
        
        window.title = "MetalShooter - Metal4 FPS Game"
        print("🏠 游戏窗口设置成功")
    }
    
    /// 创建Metal视图
    private func createMetalView() {
        guard let window = gameWindow else {
            fatalError("❌ 游戏窗口未创建")
        }
        // 直接替换窗口内容视图（还原简化逻辑）
        metalView = MTKView(frame: window.contentView?.bounds ?? window.frame)
        if let mv = metalView {
            mv.autoresizingMask = [.width, .height]
            mv.preferredFramesPerSecond = 60
            mv.enableSetNeedsDisplay = false
            mv.isPaused = false
            mv.clearColor = MTLClearColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
            window.contentView = mv
            print("🖥️ Metal视图创建并替换 contentView: size=\(mv.bounds.size)")
        } else {
            print("❌ 创建MTKView失败")
        }
        if let mainMenu = NSApp.mainMenu {
            let titles = mainMenu.items.map { $0.title }
            print("📋 当前主菜单项: \(titles)")
        } else {
            print("⚠️ 主菜单为 nil")
        }
    }
    
    /// 初始化渲染器
    private func initializeRenderer() {
        guard let metalView = metalView else {
            fatalError("❌ Metal视图未创建")
        }
        
        renderer = MetalRenderer()
        renderer.initialize(with: metalView)
        
        // 初始化第一人称渲染器
        initializeFirstPersonRenderer()
        
        print("🎨 渲染器初始化完成")
    }
    
    /// 初始化第一人称渲染器
    private func initializeFirstPersonRenderer() {
        guard let device = renderer.metalRenderer.device,
              let library = renderer.metalRenderer.library else {
            print("⚠️ 无法获取Metal设备或库，跳过第一人称渲染器初始化")
            return
        }
        
        firstPersonRenderer = FirstPersonRenderer(device: device, library: library)
        print("🔫 第一人称渲染器初始化完成")
    }
    
    /// 初始化输入管理器
    private func initializeInputManager() {
        guard let gameWindow = gameWindow else {
            fatalError("❌ 游戏窗口未设置")
        }
        
        inputManager.initialize(window: gameWindow)
        print("🎮 输入管理器初始化完成")
    }
    
    /// 初始化玩家控制器
    private func initializePlayerController() {
        playerController = PlayerController(entityManager: entityManager)
        
        // 将玩家控制器注册为输入监听器
        inputManager.addInputListener(playerController!)
        
        print("👤 玩家控制器初始化完成")
    }
    
    // MARK: - 系统管理
    
    /// 注册游戏系统
    private func registerGameSystems() {
        // 按执行顺序添加系统
        // CameraSystem 是单例，无需添加到gameSystems数组中
        // gameSystems.append(InputSystem())      // 输入系统
        // gameSystems.append(PhysicsSystem())    // 物理系统
        // gameSystems.append(AISystem())         // AI系统
        // gameSystems.append(AudioSystem())      // 音频系统
        // gameSystems.append(RenderSystem())     // 渲染系统
        
        print("📦 游戏系统注册完成 (\(gameSystems.count)个系统)")
    }
    
    /// 初始化所有游戏系统
    private func initializeGameSystems() {
        for system in gameSystems {
            system.initialize()
        }
        
        print("⚙️ 所有游戏系统初始化完成")
    }
    
    // MARK: - 场景管理
    
    /// 创建测试场景
    private func createTestScene() {
        print("🎬 创建测试场景...")
        
        // 使用 GameWorldSetup 创建完整的测试场景
        GameWorldSetup.shared.createBasicTestScene()
        
        // 添加一些障碍物
        GameWorldSetup.shared.addObstacles()
        
        // 创建几个简单敌人
        _ = GameWorldSetup.shared.createSimpleEnemy(at: Float3(7, 1, -10))
        _ = GameWorldSetup.shared.createSimpleEnemy(at: Float3(-5, 1, -8))
        _ = GameWorldSetup.shared.createSimpleEnemy(at: Float3(2, 1, -15))
        
        // 初始化第一人称模型
        initializeFirstPersonModels()
        
        print("✅ 完整测试场景创建完成")
        print("   包含: 地面、墙壁、目标、敌人、障碍物")
        print("   第一人称: 武器和手臂模型已加载")
        print("   武器系统: 已激活")
        print("   碰撞检测: 已激活")
        print("🎮 射击游戏已准备就绪 - WASD移动，鼠标视角，左键射击，R键装弹")
    }
    
    /// 初始化第一人称模型
    private func initializeFirstPersonModels() {
    // 创建第一人称武器模型（无需保存返回值）
    _ = ModelManager.shared.createBuiltInModel(.firstPersonRifle, name: "FirstPersonRifle")
        print("🔫 第一人称步枪模型创建完成")
        
    // 创建第一人称手臂模型  
    _ = ModelManager.shared.createBuiltInModel(.firstPersonArms, name: "FirstPersonArms")
        print("🖐 第一人称手臂模型创建完成")
    }
    
    // MARK: - 游戏循环控制
    
    /// 启动游戏引擎
    func start() {
        guard !isRunning else {
            print("⚠️ 游戏引擎已在运行")
            return
        }
        
        print("🎮 游戏引擎启动...")
        isRunning = true
        isPaused = false
        
        // 启动时间系统
        timeManager.start()
        
        // 开始渲染循环 (由MTKView的delegate自动处理)
        metalView?.isPaused = false
        
        print("✅ 游戏引擎启动成功")
        printGameStatus()
    }
    
    /// 暂停游戏引擎
    func pause() {
        guard isRunning && !isPaused else { return }
        
        print("⏸️ 游戏引擎暂停")
        isPaused = true
        metalView?.isPaused = true
    }
    
    /// 恢复游戏引擎
    func resume() {
        guard isRunning && isPaused else { return }
        
        print("▶️ 游戏引擎恢复")
        isPaused = false
        metalView?.isPaused = false
    }
    
    /// 停止游戏引擎
    func stop() {
        guard isRunning else { return }
        
        print("🛑 游戏引擎停止...")
        isRunning = false
        isPaused = false
        
        metalView?.isPaused = true
        
        // 清理所有系统
        for system in gameSystems {
            system.cleanup()
        }
        
        print("✅ 游戏引擎已停止")
    }
    
    // MARK: - 更新循环
    
    /// 更新游戏逻辑
    func update() {
        guard isRunning && !isPaused else { return }
        
        // 更新时间
        timeManager.update()
        
        // 处理简单快捷键
        handleSimpleHotkeys()
        
        // 处理待处理的实体和组件操作
        entityManager.processPendingOperations()
        
        // 更新玩家控制器
        if let playerController = playerController {
            playerController.update(deltaTime: timeManager.deltaTime)
        }
        
        // 更新武器系统
        WeaponSystem.shared.update(deltaTime: timeManager.deltaTime, currentTime: timeManager.totalTime)
        
        // 更新碰撞系统
        CollisionSystem.shared.update(deltaTime: timeManager.deltaTime)
        
        // 更新所有游戏系统
        for system in gameSystems {
            system.update(deltaTime: timeManager.deltaTime, entityManager: entityManager)
        }
        
        // 更新帧计数
        frameCount += 1
    }
    
    /// 渲染游戏画面
    func render() {
        guard isRunning && !isPaused else { return }
        
        // 使用新的第一人称渲染系统
        renderer.renderScene(firstPersonRenderer: firstPersonRenderer)
    }
    
    /// 设置测试三角形的可见性
    func setTriangleVisible(_ visible: Bool) {
        renderer.isTestTriangleVisible = visible
        print("🎮 GameEngine: 三角形可见性设置为 \(visible ? "可见" : "隐藏")")
        
        // 当三角形被设置为可见时，重置为首次出现状态
        if visible {
            renderer.resetTriangleToFirstAppearance()
        }
    }

    // MARK: - 显示模式控制 API

    /// 设置ShowGames模式（显示外部OBJ PlayerModel）
    func setShowGamesMode(_ on: Bool) {
        showGamesMode = on
        if on {
            print("🟢 进入ShowGames模式: 切换到BlenderMCP PlayerModel并显示")
            PlayerModelLoader.shared.switchToVersion(.blenderMCP)
            _ = PlayerModelLoader.shared.loadCurrentPlayerModel()
            renderer.isPlayerModelVisible = true
            renderer.isTestTriangleVisible = false
            // 确保模型数据立即加载（防止可见性早于渲染器完成初始化时错过 didSet）
            renderer.ensurePlayerModelLoaded()
            // 打印OBJ解析调试信息
            let info = PlayerModelLoader.shared.debugExternalOBJResolutionInfo()
            print("🧾 PlayerModel外部OBJ解析: \(info)")
            // 隐藏第一人称武器/手臂
            setWeaponVisible(false)
            setArmsVisible(false)
        } else {
            print("🟡 退出ShowGames模式: 隐藏玩家模型, 不自动显示三角形")
            renderer.isPlayerModelVisible = false
            renderer.isTestTriangleVisible = false
            // 恢复武器/手臂
            setWeaponVisible(true)
            setArmsVisible(true)
        }
    }

    /// 显示程序生成玩家模型（用于Triangle模式下P键）
    func showGeneratedPlayerModel() {
        PlayerModelLoader.shared.switchToVersion(.generated)
        _ = PlayerModelLoader.shared.loadCurrentPlayerModel()
        renderer.isPlayerModelVisible = true
        renderer.isTestTriangleVisible = false
        setWeaponVisible(false)
        setArmsVisible(false)
    }

    /// 隐藏玩家模型，显示三角形
    func hidePlayerModelShowTriangle() {
        renderer.isPlayerModelVisible = false
        renderer.isTestTriangleVisible = true
        // 恢复武器/手臂
        setWeaponVisible(true)
        setArmsVisible(true)
    }
    
    /// 设置第一人称武器可见性
    func setWeaponVisible(_ visible: Bool) {
        firstPersonRenderer?.setWeaponVisible(visible)
        print("🔫 GameEngine: 武器可见性设置为 \(visible ? "可见" : "隐藏")")
    }
    
    /// 设置第一人称手臂可见性
    func setArmsVisible(_ visible: Bool) {
        firstPersonRenderer?.setArmsVisible(visible)
        print("🖐 GameEngine: 手臂可见性设置为 \(visible ? "可见" : "隐藏")")
    }
    
    /// 播放武器动画
    func playWeaponAnimation(_ animation: WeaponAnimation) {
        firstPersonRenderer?.playWeaponAnimation(animation)
        print("🎬 GameEngine: 播放武器动画 \(animation)")
    }
    
    // MARK: - 调试和状态
    
    /// 打印游戏状态
    func printGameStatus() {
        print("📊 游戏引擎状态:")
        print("   运行状态: \(isRunning ? "运行中" : "已停止")")
        print("   暂停状态: \(isPaused ? "已暂停" : "正常")")
        print("   帧计数: \(frameCount)")
        print("   FPS: \(String(format: "%.1f", timeManager.fps))")
        print("   实体数量: \(entityManager.getEntityCount())")
        print("   系统数量: \(gameSystems.count)")
    }
    
    /// 获取性能统计
    func getPerformanceStats() -> String {
        return String(format: "FPS: %.1f | 实体: %d | 帧: %d",
                     timeManager.fps,
                     entityManager.getEntityCount(),
                     frameCount)
    }
    
    // MARK: - 清理资源
    
    /// 清理游戏引擎资源
    func shutdown() {
        print("🛑 GameEngine 开始清理...")
        
        // 停止游戏循环
        stop()
        
        // 清理第一人称渲染器
        firstPersonRenderer?.cleanup()
        firstPersonRenderer = nil
        
        // 清理玩家控制器
        if let playerController = playerController {
            inputManager.removeInputListener(playerController)
            playerController.cleanup()
            self.playerController = nil
        }
        
        // 清理输入管理器
        inputManager.cleanup()
        
        // 清理所有游戏系统
        for system in gameSystems {
            system.cleanup()
        }
        gameSystems.removeAll()
        
        // 清理实体
        entityManager.cleanup()
        
        print("✅ GameEngine 清理完成")
    }
    
    deinit {
        shutdown()
        print("🗑️ GameEngine 已销毁")
    }
}

// MARK: - 游戏系统协议

/// 游戏系统基础协议
protocol GameSystem: AnyObject {
    /// 系统初始化
    func initialize()
    
    /// 系统更新
    /// - Parameters:
    ///   - deltaTime: 帧间隔时间
    ///   - entityManager: 实体管理器
    func update(deltaTime: Float, entityManager: EntityManager)
    
    /// 系统清理
    func cleanup()
}
