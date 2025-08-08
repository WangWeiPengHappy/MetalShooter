//
//  GameEngineTests.swift
//  MetalShooterTests
//
//  测试GameEngine核心功能
//  验证GameEngine与ECS系统的集成、更新循环、组件处理等功能
//

import XCTest
import simd
@testable import MetalShooter

/// GameEngine测试类：验证游戏引擎核心功能和ECS集成
final class GameEngineTests: XCTestCase {
    
    var gameEngine: GameEngine!
    var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // 使用单例实例
        gameEngine = GameEngine.shared
        entityManager = gameEngine.currentEntityManager
        
        // 确保引擎是干净状态
        if gameEngine.currentlyRunning {
            gameEngine.stop()
        }
    }
    
    override func tearDownWithError() throws {
        // 清理测试环境
        if gameEngine.currentlyRunning {
            gameEngine.stop()
        }
        entityManager.cleanup()
        
        super.tearDown()
    }
    
    // MARK: - GameEngine.update()修复测试
    
    /// 测试GameEngine.update()中processPendingOperations的集成
    func testGameEngineUpdateProcessPendingOperations() throws {
        print("🧪 测试GameEngine.update()中processPendingOperations集成...")
        
        // 创建测试实体和组件
        let testEntity = entityManager.createEntity()
        let testTransform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        
        // 添加组件（进入待处理队列）
        entityManager.addComponent(testTransform, to: testEntity)
        
        // 验证组件还未处理
        let transformBefore = entityManager.getComponent(TransformComponent.self, for: testEntity)
        XCTAssertNil(transformBefore, "update()调用前组件应该在待处理队列中")
        
        // 调用GameEngine.update()（包含processPendingOperations调用）
        gameEngine.update()
        
        // 验证组件已被处理
        let transformAfter = entityManager.getComponent(TransformComponent.self, for: testEntity)
        XCTAssertNotNil(transformAfter, "update()调用后组件应该可以访问")
        
        if let transform = transformAfter {
            XCTAssertEqual(transform.localPosition.x, 1.0, accuracy: 0.001)
            XCTAssertEqual(transform.localPosition.y, 2.0, accuracy: 0.001)  
            XCTAssertEqual(transform.localPosition.z, 3.0, accuracy: 0.001)
        }
        
        print("✅ GameEngine.update() processPendingOperations集成测试通过")
    }
    
    /// 测试多次update()调用的稳定性
    func testMultipleUpdateCallsStability() throws {
        print("🧪 测试多次GameEngine.update()调用稳定性...")
        
        var testEntities: [UUID] = []
        
        // 创建多个测试实体
        for i in 0..<10 {
            let entity = entityManager.createEntity()
            testEntities.append(entity)
            
            let transform = TransformComponent(
                position: Float3(Float(i), 0, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: Float3(1, 1, 1)
            )
            entityManager.addComponent(transform, to: entity)
        }
        
        // 多次调用update()
        for updateCount in 0..<5 {
            gameEngine.update()
            
            // 验证所有组件都已正确处理
            for (index, entity) in testEntities.enumerated() {
                let transform = entityManager.getComponent(TransformComponent.self, for: entity)
                XCTAssertNotNil(transform, "第\(updateCount)次update后，实体\(index)的组件应该可访问")
            }
        }
        
        print("✅ 多次update()调用稳定性测试通过")
    }
    
    /// 测试GameEngine生命周期中的processPendingOperations
    func testGameEngineLifecycleProcessPendingOperations() throws {
        print("🧪 测试GameEngine生命周期中processPendingOperations...")
        
        // 1. 启动前添加组件
        let preStartEntity = entityManager.createEntity()
        let preStartTransform = TransformComponent(
            position: Float3(10, 20, 30),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(preStartTransform, to: preStartEntity)
        
        // 验证启动前组件在待处理队列
        let transformBeforeStart = entityManager.getComponent(TransformComponent.self, for: preStartEntity)
        XCTAssertNil(transformBeforeStart, "启动前组件应该在待处理队列")
        
        // 2. 启动GameEngine并运行一帧
        gameEngine.start()
        XCTAssertTrue(gameEngine.currentlyRunning, "GameEngine应该在运行")
        
        gameEngine.update()  // 触发processPendingOperations
        
        // 验证启动后组件已处理
        let transformAfterStart = entityManager.getComponent(TransformComponent.self, for: preStartEntity)
        XCTAssertNotNil(transformAfterStart, "启动后组件应该可访问")
        
        // 3. 运行期间添加新组件
        let runtimeEntity = entityManager.createEntity()
        let runtimeTransform = TransformComponent(
            position: Float3(40, 50, 60),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(runtimeTransform, to: runtimeEntity)
        
        gameEngine.update()  // 再次触发processPendingOperations
        
        // 验证运行时组件也正确处理
        let runtimeTransformAfter = entityManager.getComponent(TransformComponent.self, for: runtimeEntity)
        XCTAssertNotNil(runtimeTransformAfter, "运行时添加的组件应该可访问")
        
        // 4. 停止GameEngine
        gameEngine.stop()
        XCTAssertFalse(gameEngine.currentlyRunning, "GameEngine应该已停止")
        
        print("✅ GameEngine生命周期processPendingOperations测试通过")
    }
    
    // MARK: - PlayerController集成测试
    
    /// 测试GameEngine与PlayerController的集成修复
    func testGameEnginePlayerControllerIntegration() throws {
        print("🧪 测试GameEngine与PlayerController集成修复...")
        
        // 初始化GameEngine（这会创建PlayerController）
        try gameEngine.initialize()
        
        // 获取PlayerController创建的实体
        let playerController = gameEngine.currentPlayerController
        XCTAssertNotNil(playerController, "PlayerController应该已创建")
        
        // 启动引擎
        gameEngine.start()
        
        // 运行几帧更新
        for frame in 0..<3 {
            gameEngine.update()
            print("✅ 第\(frame)帧更新完成")
        }
        
        // 验证PlayerController可以正常访问其组件
        if let pc = playerController,
           let playerEntity = pc.getPlayerEntity() {
            let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id)
            XCTAssertNotNil(transform, "PlayerController应该能访问其TransformComponent")
        }
        
        gameEngine.stop()
        
        print("✅ GameEngine与PlayerController集成测试通过")
    }
    
    // MARK: - 性能测试
    
    /// 测试GameEngine.update()的性能
    func testGameEngineUpdatePerformance() throws {
        print("🧪 测试GameEngine.update()性能...")
        
        // 创建大量测试实体
        var entities: [UUID] = []
        for i in 0..<100 {
            let entity = entityManager.createEntity()
            entities.append(entity)
            
            let transform = TransformComponent(
                position: Float3(Float(i), 0, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: Float3(1, 1, 1)
            )
            entityManager.addComponent(transform, to: entity)
        }
        
        // 性能测试
        measure {
            // 连续执行多次update
            for _ in 0..<10 {
                gameEngine.update()
            }
        }
        
        // 清理
        for entity in entities {
            entityManager.destroyEntity(entity)
        }
        gameEngine.update()  // 处理删除操作
        
        print("✅ GameEngine.update()性能测试完成")
    }
    
    // MARK: - 边界条件测试
    
    /// 测试空EntityManager的update()调用
    func testUpdateWithEmptyEntityManager() throws {
        print("🧪 测试空EntityManager的update()调用...")
        
        // 确保EntityManager为空
        entityManager.cleanup()
        
        // 调用update应该不会崩溃
        XCTAssertNoThrow(gameEngine.update(), "空EntityManager的update()不应该崩溃")
        
        print("✅ 空EntityManager update()测试通过")
    }
    
    /// 测试在停止状态下调用update()
    func testUpdateWhenStopped() throws {
        print("🧪 测试停止状态下的update()调用...")
        
        // 确保GameEngine已停止
        gameEngine.stop()
        XCTAssertFalse(gameEngine.currentlyRunning, "GameEngine应该已停止")
        
        // 添加测试组件
        let entity = entityManager.createEntity()
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        
        // 在停止状态调用update
        gameEngine.update()
        
        // 组件应该仍然在待处理队列中（因为引擎已停止）
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNil(retrievedTransform, "停止状态下组件应该仍在待处理队列")
        
        print("✅ 停止状态update()测试通过")
    }
    
    /// 测试暂停状态下的update()
    func testUpdateWhenPaused() throws {
        print("🧪 测试暂停状态下的update()调用...")
        
        // 启动并暂停GameEngine
        gameEngine.start()
        gameEngine.pause()
        XCTAssertTrue(gameEngine.currentlyPaused, "GameEngine应该已暂停")
        
        // 添加测试组件
        let entity = entityManager.createEntity()
        let transform = TransformComponent(
            position: Float3(4, 5, 6),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        
        // 在暂停状态调用update
        gameEngine.update()
        
        // 组件应该仍然在待处理队列中（因为引擎已暂停）
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNil(retrievedTransform, "暂停状态下组件应该仍在待处理队列")
        
        // 恢复并更新
        gameEngine.resume()
        gameEngine.update()
        
        // 现在组件应该可以访问
        let resumedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNotNil(resumedTransform, "恢复后组件应该可以访问")
        
        gameEngine.stop()
        
        print("✅ 暂停状态update()测试通过")
    }
}
