//
//  ECSTests.swift
//  MetalShooterTests
//
//  测试ECS系统核心功能
//  验证EntityManager组件管理、队列处理、生命周期等功能
//

import XCTest
import simd
@testable import MetalShooter

/// ECS系统测试类：验证EntityManager核心功能和组件生命周期管理
final class ECSTests: XCTestCase {
    
    var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        super.setUp()
        entityManager = EntityManager.shared
        entityManager.cleanup()  // 确保干净的测试环境
    }
    
    override func tearDownWithError() throws {
        entityManager.cleanup()
        super.tearDown()
    }
    
    // MARK: - processPendingOperations核心修复测试
    
    /// 测试processPendingOperations的基本功能
    func testProcessPendingOperationsBasicFunctionality() throws {
        print("🧪 测试processPendingOperations基本功能...")
        
        // 1. 创建实体
        let entity = entityManager.createEntity()
        XCTAssertNotNil(entity, "实体创建应该成功")
        
        // 2. 添加组件（进入待处理队列）
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        
        // 3. 验证组件在待处理状态
        let componentBeforeProcessing = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNil(componentBeforeProcessing, "处理前组件应该无法获取")
        
        // 4. 调用processPendingOperations（核心修复）
        entityManager.processPendingOperations()
        
        // 5. 验证组件已处理
        let componentAfterProcessing = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNotNil(componentAfterProcessing, "处理后组件应该可以获取")
        XCTAssertEqual(componentAfterProcessing?.localPosition, Float3(1, 2, 3))
        
        print("✅ processPendingOperations基本功能测试通过")
    }
    
    /// 测试多个组件的批量处理
    func testMultipleComponentsBatchProcessing() throws {
        print("🧪 测试多个组件批量处理...")
        
        let entity = entityManager.createEntity()
        
        // 添加多个组件
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        
        let renderComponent = RenderComponent()
        entityManager.addComponent(renderComponent, to: entity)
        
        // 验证都在待处理状态
        XCTAssertNil(entityManager.getComponent(TransformComponent.self, for: entity))
        XCTAssertNil(entityManager.getComponent(RenderComponent.self, for: entity))
        
        // 批量处理
        entityManager.processPendingOperations()
        
        // 验证都已处理
        XCTAssertNotNil(entityManager.getComponent(TransformComponent.self, for: entity))
        XCTAssertNotNil(entityManager.getComponent(RenderComponent.self, for: entity))
        
        print("✅ 多组件批量处理测试通过")
    }
    
    /// 测试多个实体的组件处理
    func testMultipleEntitiesComponentProcessing() throws {
        print("🧪 测试多个实体组件处理...")
        
        var entities: [UUID] = []
        let entityCount = 5
        
        // 创建多个实体并添加组件
        for i in 0..<entityCount {
            let entity = entityManager.createEntity()
            entities.append(entity)
            
            let transform = TransformComponent(
                position: Float3(Float(i), Float(i * 2), Float(i * 3)),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: Float3(1, 1, 1)
            )
            entityManager.addComponent(transform, to: entity)
        }
        
        // 验证所有组件都在待处理状态
        for entity in entities {
            XCTAssertNil(entityManager.getComponent(TransformComponent.self, for: entity))
        }
        
        // 处理所有待处理操作
        entityManager.processPendingOperations()
        
        // 验证所有组件都已处理
        for (index, entity) in entities.enumerated() {
            let transform = entityManager.getComponent(TransformComponent.self, for: entity)
            XCTAssertNotNil(transform, "实体\(index)的组件应该可以访问")
            XCTAssertEqual(transform?.localPosition.x ?? 0, Float(index), accuracy: 0.001)
        }
        
        print("✅ 多实体组件处理测试通过")
    }
    
    // MARK: - 组件生命周期测试
    
    /// 测试组件添加→处理→访问的完整生命周期
    func testComponentLifecycle() throws {
        print("🧪 测试组件完整生命周期...")
        
        let entity = entityManager.createEntity()
        
        // 阶段1：组件添加
        let originalTransform = TransformComponent(
            position: Float3(10, 20, 30),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(2, 2, 2)
        )
        entityManager.addComponent(originalTransform, to: entity)
        
        // 阶段2：验证待处理状态
        XCTAssertNil(entityManager.getComponent(TransformComponent.self, for: entity))
        
        // 阶段3：处理
        entityManager.processPendingOperations()
        
        // 阶段4：访问和验证
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNotNil(retrievedTransform)
        XCTAssertEqual(retrievedTransform?.localPosition, Float3(10, 20, 30))
        XCTAssertEqual(retrievedTransform?.localScale, Float3(2, 2, 2))
        
        // 阶段5：修改组件
        retrievedTransform?.localPosition = Float3(100, 200, 300)
        
        // 阶段6：验证修改持久化
        let modifiedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertEqual(modifiedTransform?.localPosition, Float3(100, 200, 300))
        
        print("✅ 组件生命周期测试通过")
    }
    
    /// 测试组件删除的处理
    func testComponentRemovalProcessing() throws {
        print("🧪 测试组件删除处理...")
        
        let entity = entityManager.createEntity()
        
        // 添加并处理组件
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        entityManager.processPendingOperations()
        
        // 验证组件存在
        XCTAssertNotNil(entityManager.getComponent(TransformComponent.self, for: entity))
        
        // 删除组件
        entityManager.removeComponent(TransformComponent.self, from: entity)
        
        // 处理删除操作
        entityManager.processPendingOperations()
        
        // 验证组件已删除
        XCTAssertNil(entityManager.getComponent(TransformComponent.self, for: entity))
        
        print("✅ 组件删除处理测试通过")
    }
    
    // MARK: - 错误处理和边界条件
    
    /// 测试重复调用processPendingOperations
    func testRepeatedProcessPendingOperationsCall() throws {
        print("🧪 测试重复调用processPendingOperations...")
        
        let entity = entityManager.createEntity()
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        
        // 多次调用processPendingOperations
        entityManager.processPendingOperations()
        entityManager.processPendingOperations()
        entityManager.processPendingOperations()
        
        // 验证组件仍然正确可访问
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNotNil(retrievedTransform)
        XCTAssertEqual(retrievedTransform?.localPosition, Float3(1, 2, 3))
        
        print("✅ 重复调用processPendingOperations测试通过")
    }
    
    /// 测试空队列的processPendingOperations调用
    func testProcessPendingOperationsWithEmptyQueue() throws {
        print("🧪 测试空队列processPendingOperations调用...")
        
        // 确保队列为空
        entityManager.cleanup()
        
        // 调用processPendingOperations应该不会崩溃
        XCTAssertNoThrow(entityManager.processPendingOperations())
        
        // 再次调用也应该安全
        XCTAssertNoThrow(entityManager.processPendingOperations())
        
        print("✅ 空队列processPendingOperations测试通过")
    }
    
    /// 测试无效实体ID的组件操作
    func testInvalidEntityIdComponentOperations() throws {
        print("🧪 测试无效实体ID组件操作...")
        
        // 创建无效的UUID
        let invalidEntityId = UUID()
        
        // 尝试为无效实体添加组件
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        
        // 这应该不会崩溃，但也不会有效果
        let dummyEntity = invalidEntityId
        entityManager.addComponent(transform, to: dummyEntity)
        entityManager.processPendingOperations()
        
        // 尝试获取组件应该返回nil
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: invalidEntityId)
        XCTAssertNil(retrievedTransform, "无效实体ID应该返回nil组件")
        
        print("✅ 无效实体ID组件操作测试通过")
    }
    
    // MARK: - 性能和压力测试
    
    /// 测试大量组件处理的性能
    func testLargeScaleComponentProcessingPerformance() throws {
        print("🧪 测试大量组件处理性能...")
        
        let entityCount = 1000
        var entities: [UUID] = []
        
        measure {
            // 创建大量实体和组件
            for i in 0..<entityCount {
                let entity = entityManager.createEntity()
                entities.append(entity)
                
                let transform = TransformComponent(
                    position: Float3(Float(i), 0, 0),
                    rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                    scale: Float3(1, 1, 1)
                )
                entityManager.addComponent(transform, to: entity)
            }
            
            // 批量处理所有组件
            entityManager.processPendingOperations()
            
            // 清理
            for entity in entities {
                entityManager.destroyEntity(entity)
            }
            entityManager.processPendingOperations()
            entities.removeAll()
        }
        
        print("✅ 大量组件处理性能测试完成")
    }
    
    /// 测试频繁的添加/删除/处理循环
    func testFrequentAddRemoveProcessCycle() throws {
        print("🧪 测试频繁添加/删除/处理循环...")
        
        let entity = entityManager.createEntity()
        let cycleCount = 50
        
        measure {
            for cycle in 0..<cycleCount {
                // 添加组件
                let transform = TransformComponent(
                    position: Float3(Float(cycle), 0, 0),
                    rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                    scale: Float3(1, 1, 1)
                )
                entityManager.addComponent(transform, to: entity)
                
                // 处理
                entityManager.processPendingOperations()
                
                // 验证
                let retrieved = entityManager.getComponent(TransformComponent.self, for: entity)
                XCTAssertNotNil(retrieved)
                
                // 删除
                entityManager.removeComponent(TransformComponent.self, from: entity)
                entityManager.processPendingOperations()
                
                // 验证删除
                let afterRemoval = entityManager.getComponent(TransformComponent.self, for: entity)
                XCTAssertNil(afterRemoval)
            }
        }
        
        print("✅ 频繁添加/删除/处理循环测试完成")
    }
    
    // MARK: - 集成测试
    
    /// 测试与GameEngine.update()的集成
    func testIntegrationWithGameEngineUpdate() throws {
        print("🧪 测试与GameEngine.update()集成...")
        
        let gameEngine = GameEngine.shared
        let entity = entityManager.createEntity()
        
        // 添加组件
        let transform = TransformComponent(
            position: Float3(5, 10, 15),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entity)
        
        // 验证组件在待处理状态
        XCTAssertNil(entityManager.getComponent(TransformComponent.self, for: entity))
        
        // 调用GameEngine.update()（应该调用processPendingOperations）
        gameEngine.update()
        
        // 验证组件已处理
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entity)
        XCTAssertNotNil(retrievedTransform, "GameEngine.update()后组件应该可访问")
        XCTAssertEqual(retrievedTransform?.localPosition, Float3(5, 10, 15))
        
        print("✅ GameEngine.update()集成测试通过")
    }
}
