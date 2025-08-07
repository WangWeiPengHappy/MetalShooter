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
    
    /// 实体管理器
    private let entityManager = EntityManager.shared
    
    /// 时间管理器
    private let timeManager = Time.shared
    
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

    // MARK: - 初始化    /// 初始化游戏引擎
    func initialize() {
        print("🚀 GameEngine 初始化开始...")
        
        // 1. 设置游戏窗口（使用现有窗口）
        setupGameWindow()
        
        // 2. 创建Metal视图
        createMetalView()
        
        // 3. 初始化渲染器
        initializeRenderer()
        
        // 4. 注册游戏系统
        registerGameSystems()
        
        // 5. 初始化所有系统
        initializeGameSystems()
        
        // 6. 创建测试场景
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
        
        metalView = MTKView(frame: window.contentView?.bounds ?? NSRect.zero)
        metalView?.autoresizingMask = [.width, .height]
        
        // 配置Metal视图
        metalView?.preferredFramesPerSecond = 60
        metalView?.enableSetNeedsDisplay = false
        metalView?.isPaused = false
        
        window.contentView = metalView
        
        print("🖥️ Metal视图创建成功")
    }
    
    /// 初始化渲染器
    private func initializeRenderer() {
        guard let metalView = metalView else {
            fatalError("❌ Metal视图未创建")
        }
        
        renderer = MetalRenderer()
        renderer.initialize(with: metalView)
        
        print("🎨 渲染器初始化完成")
    }
    
    // MARK: - 系统管理
    
    /// 注册游戏系统
    private func registerGameSystems() {
        // 按执行顺序添加系统
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
        
        // 创建一个测试实体
        let testEntity = entityManager.createEntity()
        
        // 添加变换组件
        let transform = TransformComponent(
            position: Float3(0, 0, -5),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: testEntity)
        
        // 添加渲染组件
        let renderComponent = RenderComponent()
        entityManager.addComponent(renderComponent, to: testEntity)
        
        print("✅ 测试场景创建完成")
        print("   实体数量: 1")
        print("   测试实体ID: \(testEntity)")
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
        
        // 当前使用测试渲染
        renderer.renderTestTriangle()
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

// MARK: - 扩展EntityManager

extension EntityManager {
    /// 获取实体总数
    func getEntityCount() -> Int {
        // 需要在EntityManager中实现这个方法
        return 1 // 临时返回值
    }
}
