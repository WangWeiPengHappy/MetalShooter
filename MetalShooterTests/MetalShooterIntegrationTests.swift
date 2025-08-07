//
//  MetalShooterIntegrationTests.swift
//  MetalShooterTests
//
//  Metal4 射击游戏集成测试
//  测试Phase 2各系统之间的集成和协作
//

import XCTest
import Metal
import MetalKit
@testable import MetalShooter

/// Metal4 射击游戏集成测试类
final class MetalShooterIntegrationTests: XCTestCase {

    // MARK: - 测试生命周期
    
    override func setUpWithError() throws {
        super.setUp()
    }

    override func tearDownWithError() throws {
        super.tearDown()
        // 确保测试后清理状态
        GameEngine.shared.stop()
    }

    // MARK: - Phase 2 完整工作流程测试
    
    /// 测试完整的Phase 2启动流程
    func testCompletePhase2StartupFlow() throws {
        print("🧪 测试完整的Phase 2启动流程...")
        
        let gameEngine = GameEngine.shared
        
        // 1. 验证初始状态
        XCTAssertFalse(gameEngine.currentlyRunning, "游戏引擎初始时不应运行")
        XCTAssertFalse(gameEngine.currentlyPaused, "游戏引擎初始时不应暂停")
        
        // 2. 初始化游戏引擎
        XCTAssertNoThrow(try gameEngine.initialize(), "游戏引擎初始化应该成功")
        
        // 3. 验证关键系统已初始化
        XCTAssertNotNil(gameEngine.metalRenderer, "Metal渲染器应该已创建")
        XCTAssertNotNil(gameEngine.currentTimeManager, "时间管理器应该已创建")
        XCTAssertNotNil(gameEngine.currentEntityManager, "实体管理器应该已创建")
        
        // 4. 启动游戏引擎
        gameEngine.start()
        XCTAssertTrue(gameEngine.currentlyRunning, "游戏引擎启动后应该运行")
        
        // 5. 验证Metal渲染器状态
        let renderer = gameEngine.metalRenderer!
        XCTAssertNotNil(renderer.currentDevice, "Metal设备应该已设置")
        XCTAssertNotNil(renderer.currentCommandQueue, "命令队列应该已创建")
        XCTAssertNotNil(renderer.currentRenderPipelineState, "渲染管线状态应该已创建")
        
        // 6. 验证时间系统运行
        let timeManager = gameEngine.currentTimeManager
        XCTAssertNotNil(timeManager, "时间管理器应该可用")
        
        print("✅ Phase 2启动流程测试通过")
    }
    
    /// 测试渲染器与时间系统协作
    func testRendererTimeSystemIntegration() throws {
        print("🧪 测试渲染器与时间系统协作...")
        
        let gameEngine = GameEngine.shared
        try gameEngine.initialize()
        gameEngine.start()
        
        let renderer = gameEngine.metalRenderer!
        let timeManager = gameEngine.currentTimeManager
        
        // 模拟几帧的渲染循环
        for frame in 1...5 {
            print("🎬 模拟第\(frame)帧...")
            
            // 更新时间系统
            timeManager.update()
            
            // 验证时间数据
            XCTAssertGreaterThan(timeManager.frameCount, 0, "帧数应该增加")
            if frame > 1 {
                XCTAssertGreaterThan(timeManager.deltaTime, 0, "deltaTime应该大于0")
            }
            
            // 模拟渲染器使用时间数据
            let currentFrame = Int(timeManager.frameCount)
            XCTAssertEqual(currentFrame, frame, "帧数应该匹配")
            
            // 短暂等待模拟真实帧间隔
            Thread.sleep(forTimeInterval: 0.016) // ~60 FPS
        }
        
        print("✅ 渲染器与时间系统协作测试通过")
    }
    
    /// 测试ECS系统与渲染器协作
    func testECSRendererIntegration() throws {
        print("🧪 测试ECS系统与渲染器协作...")
        
        let gameEngine = GameEngine.shared
        try gameEngine.initialize()
        
        let entityManager = gameEngine.currentEntityManager
        let renderer = gameEngine.metalRenderer!
        
        // 创建一个具有渲染组件的实体
        let entityId = entityManager.createEntity()
        
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(angle: 0, axis: Float3(0, 1, 0)),
            scale: Float3(1, 1, 1)
        )
        
        let renderComponent = RenderComponent()
        renderComponent.isVisible = true
        
        entityManager.addComponent(transform, to: entityId)
        entityManager.addComponent(renderComponent, to: entityId)
        
        // 验证实体组件已正确设置
        guard let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entityId),
              let retrievedRender = entityManager.getComponent(RenderComponent.self, for: entityId) else {
            XCTFail("无法获取实体组件")
            return
        }
        
        XCTAssertEqual(retrievedTransform.localPosition, Float3(1, 2, 3), "位置应该正确")
        XCTAssertTrue(retrievedRender.isVisible, "渲染组件应该可见")
        
        // 模拟渲染器处理这个实体（简化测试）
        let worldMatrix = retrievedTransform.worldMatrix
        XCTAssertNotNil(worldMatrix, "世界矩阵应该可计算")
        
        // 清理
        entityManager.destroyEntity(entityId)
        
        print("✅ ECS系统与渲染器协作测试通过")
    }
    
    /// 测试多个渲染实体的处理
    func testMultipleRenderEntitiesHandling() throws {
        print("🧪 测试多个渲染实体处理...")
        
        let gameEngine = GameEngine.shared
        try gameEngine.initialize()
        
        let entityManager = gameEngine.currentEntityManager
        var entities: [UUID] = []
        
        // 创建10个渲染实体
        for i in 0..<10 {
            let entityId = entityManager.createEntity()
            entities.append(entityId)
            
            let transform = TransformComponent(
                position: Float3(Float(i), 0, 0),
                rotation: simd_quatf(angle: Float(i) * 0.1, axis: Float3(0, 1, 0)),
                scale: Float3(1, 1, 1)
            )
            
            let renderComponent = RenderComponent()
            renderComponent.isVisible = (i % 2 == 0) // 一半可见，一半不可见
            
            entityManager.addComponent(transform, to: entityId)
            entityManager.addComponent(renderComponent, to: entityId)
        }
        
        // 验证所有实体都正确创建
        XCTAssertEqual(entities.count, 10, "应该创建10个实体")
        
        // 模拟渲染系统处理这些实体
        var visibleCount = 0
        var invisibleCount = 0
        
        for entityId in entities {
            if let renderComp = entityManager.getComponent(RenderComponent.self, for: entityId) {
                if renderComp.isVisible {
                    visibleCount += 1
                } else {
                    invisibleCount += 1
                }
            }
        }
        
        XCTAssertEqual(visibleCount, 5, "应该有5个可见实体")
        XCTAssertEqual(invisibleCount, 5, "应该有5个不可见实体")
        
        // 清理所有实体
        for entityId in entities {
            entityManager.destroyEntity(entityId)
        }
        
        print("✅ 多个渲染实体处理测试通过")
    }
    
    /// 测试相机系统与渲染器协作
    func testCameraRendererIntegration() throws {
        print("🧪 测试相机系统与渲染器协作...")
        
        let gameEngine = GameEngine.shared
        try gameEngine.initialize()
        
        let entityManager = gameEngine.currentEntityManager
        
        // 创建相机实体
        let cameraEntityId = entityManager.createEntity()
        
        let cameraTransform = TransformComponent(
            position: Float3(0, 0, 5),
            rotation: simd_quatf(angle: 0, axis: Float3(0, 1, 0)),
            scale: Float3(1, 1, 1)
        )
        
        let cameraComponent = CameraComponent()
        cameraComponent.fieldOfView = 60.0
        cameraComponent.nearPlane = 0.1
        cameraComponent.farPlane = 100.0
        cameraComponent.projectionType = .perspective
        
        entityManager.addComponent(cameraTransform, to: cameraEntityId)
        entityManager.addComponent(cameraComponent, to: cameraEntityId)
        
        // 验证相机设置
        guard let camera = entityManager.getComponent(CameraComponent.self, for: cameraEntityId),
              let transform = entityManager.getComponent(TransformComponent.self, for: cameraEntityId) else {
            XCTFail("无法获取相机组件")
            return
        }
        
        // 测试投影矩阵计算
        let projectionMatrix = camera.projectionMatrix
        XCTAssertNotNil(projectionMatrix, "投影矩阵应该可计算")
        
        // 测试视图矩阵计算
        let viewMatrix = camera.viewMatrix
        XCTAssertNotNil(viewMatrix, "视图矩阵应该可计算")
        
        // 清理
        entityManager.destroyEntity(cameraEntityId)
        
        print("✅ 相机系统与渲染器协作测试通过")
    }
    
    /// 测试完整的渲染流程模拟
    func testCompleteRenderingPipelineSimulation() throws {
        print("🧪 测试完整的渲染流程模拟...")
        
        // 初始化整个系统
        let gameEngine = GameEngine.shared
        try gameEngine.initialize()
        gameEngine.start()
        
        let entityManager = gameEngine.currentEntityManager
        let renderer = gameEngine.metalRenderer!
        let timeManager = gameEngine.currentTimeManager
        
        // 创建场景：一个相机 + 多个渲染对象
        var sceneEntities: [UUID] = []
        
        // 1. 创建主相机
        let cameraId = entityManager.createEntity()
        sceneEntities.append(cameraId)
        
        let cameraTransform = TransformComponent(position: Float3(0, 0, 10))
        let camera = CameraComponent()
        
        entityManager.addComponent(cameraTransform, to: cameraId)
        entityManager.addComponent(camera, to: cameraId)
        
        // 2. 创建几个渲染对象
        for i in 0..<3 {
            let objectId = entityManager.createEntity()
            sceneEntities.append(objectId)
            
            let transform = TransformComponent(
                position: Float3(Float(i-1) * 2, 0, 0)
            )
            let renderComp = RenderComponent()
            renderComp.isVisible = true
            
            entityManager.addComponent(transform, to: objectId)
            entityManager.addComponent(renderComp, to: objectId)
        }
        
        // 3. 模拟渲染循环
        for frame in 1...3 {
            print("🎬 模拟渲染帧 \(frame)...")
            
            // 更新时间
            timeManager.update()
            
            // 模拟渲染器处理场景
            // （在真实渲染中，这里会调用beginFrame等方法）
            
            // 验证关键组件仍然存在且正常
            XCTAssertNotNil(entityManager.getComponent(CameraComponent.self, for: cameraId), 
                           "相机组件应该存在")
            
            let visibleObjects = sceneEntities.filter { entityId in
                if let render = entityManager.getComponent(RenderComponent.self, for: entityId) {
                    return render.isVisible
                }
                return false
            }
            
            XCTAssertEqual(visibleObjects.count, 3, "应该有3个可见的渲染对象")
            
            // 短暂等待模拟帧时间
            Thread.sleep(forTimeInterval: 0.016)
        }
        
        // 验证系统状态
        XCTAssertTrue(gameEngine.currentlyRunning, "游戏引擎应该仍在运行")
        XCTAssertGreaterThan(timeManager.frameCount, 0, "应该已处理多帧")
        
        // 清理场景
        for entityId in sceneEntities {
            entityManager.destroyEntity(entityId)
        }
        
        print("✅ 完整渲染流程模拟测试通过")
    }
    
    /// 测试错误恢复和边界情况
    func testErrorRecoveryAndEdgeCases() throws {
        print("🧪 测试错误恢复和边界情况...")
        
        let gameEngine = GameEngine.shared
        
        // 测试重复初始化
        try gameEngine.initialize()
        XCTAssertNoThrow(try gameEngine.initialize(), "重复初始化应该安全")
        
        // 测试重复启动
        gameEngine.start()
        gameEngine.start() // 应该安全
        XCTAssertTrue(gameEngine.currentlyRunning, "游戏引擎应该仍在运行")
        
        // 测试暂停/恢复循环
        for _ in 0..<3 {
            gameEngine.pause()
            XCTAssertTrue(gameEngine.currentlyPaused, "应该已暂停")
            
            gameEngine.resume()
            XCTAssertFalse(gameEngine.currentlyPaused, "应该已恢复")
        }
        
        // 测试停止后重启
        gameEngine.stop()
        XCTAssertFalse(gameEngine.currentlyRunning, "应该已停止")
        
        gameEngine.start()
        XCTAssertTrue(gameEngine.currentlyRunning, "应该可以重新启动")
        
        print("✅ 错误恢复和边界情况测试通过")
    }
}
