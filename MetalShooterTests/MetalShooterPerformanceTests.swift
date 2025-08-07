//
//  MetalShooterPerformanceTests.swift
//  MetalShooterTests
//
//  Metal4 射击游戏性能测试
//  测试Phase 2渲染系统的性能指标
//

import XCTest
import Metal
import MetalKit
@testable import MetalShooter

/// Metal4 射击游戏性能测试类
final class MetalShooterPerformanceTests: XCTestCase {

    // MARK: - 测试生命周期
    
    override func setUpWithError() throws {
        super.setUp()
        // 性能测试前的准备工作
    }

    override func tearDownWithError() throws {
        super.tearDown()
        // 性能测试后的清理工作
    }

    // MARK: - 渲染性能测试
    
    /// 测试MetalRenderer初始化性能
    func testMetalRendererInitializationPerformance() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal不可用，跳过性能测试")
            return
        }
        
        if !device.supportsFamily(.metal4) {
            XCTSkip("Metal 4不受支持，跳过测试")
        }
        
        let metalView = MTKView()
        metalView.device = device
        metalView.drawableSize = CGSize(width: 800, height: 600)
        
        measure {
            let renderer = MetalRenderer()
            try! renderer.initialize(with: metalView)
        }
    }
    
    /// 测试着色器编译性能
    func testShaderCompilationPerformance() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal不可用，跳过性能测试")
            return
        }
        
        measure {
            _ = device.makeDefaultLibrary()
        }
    }
    
    /// 测试帧渲染性能模拟
    func testFrameRenderingPerformance() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal不可用，跳过性能测试")
            return
        }
        
        if !device.supportsFamily(.metal4) {
            XCTSkip("Metal 4不受支持，跳过测试")
        }
        
        let metalView = MTKView()
        metalView.device = device
        metalView.drawableSize = CGSize(width: 800, height: 600)
        
        let renderer = MetalRenderer()
        try! renderer.initialize(with: metalView)
        
        // 模拟连续帧渲染性能
        measure {
            for _ in 0..<60 { // 模拟60帧
                // 模拟渲染循环的关键操作
                _ = renderer.getCurrentUniformBuffer()
                renderer.updateViewportSize(CGSize(width: 800, height: 600))
            }
        }
    }
    
    /// 测试Time系统更新性能
    func testTimeSystemPerformance() throws {
        let timeManager = Time.shared
        timeManager.start()
        
        measure {
            for _ in 0..<1000 { // 模拟1000次更新
                timeManager.update()
            }
        }
    }
    
    /// 测试ECS系统性能（大量实体）
    func testECSPerformanceWithManyEntities() throws {
        let entityManager = EntityManager.shared
        
        measure {
            var entities: [UUID] = []
            
            // 创建1000个实体
            for _ in 0..<1000 {
                let entityId = entityManager.createEntity()
                entities.append(entityId)
                
                // 为每个实体添加组件
                let transform = TransformComponent()
                let render = RenderComponent()
                
                entityManager.addComponent(transform, to: entityId)
                entityManager.addComponent(render, to: entityId)
            }
            
            // 清理
            for entityId in entities {
                entityManager.destroyEntity(entityId)
            }
        }
    }
    
    /// 测试组件查询性能
    func testComponentQueryPerformance() throws {
        let entityManager = EntityManager.shared
        var entities: [UUID] = []
        
        // 预先创建500个实体
        for _ in 0..<500 {
            let entityId = entityManager.createEntity()
            entities.append(entityId)
            
            let transform = TransformComponent()
            let render = RenderComponent()
            
            entityManager.addComponent(transform, to: entityId)
            entityManager.addComponent(render, to: entityId)
        }
        
        // 测试查询性能
        measure {
            for entityId in entities {
                _ = entityManager.getComponent(TransformComponent.self, for: entityId)
                _ = entityManager.getComponent(RenderComponent.self, for: entityId)
            }
        }
        
        // 清理
        for entityId in entities {
            entityManager.destroyEntity(entityId)
        }
    }
    
    /// 测试数学运算性能
    func testMathOperationsPerformance() throws {
        measure {
            for i in 0..<10000 {
                let pos = Float3(Float(i), Float(i*2), Float(i*3))
                let rot = simd_quatf(angle: Float(i) * 0.01, axis: Float3(0, 1, 0))
                let scale = Float3(1.5, 1.5, 1.5)
                
                // 模拟变换计算
                let rotMatrix = float4x4(rot)
                let scaleMatrix = matrix_float4x4(diagonal: simd_float4(scale.x, scale.y, scale.z, 1.0))
                let transMatrix = matrix_float4x4(
                    [1, 0, 0, pos.x],
                    [0, 1, 0, pos.y],
                    [0, 0, 1, pos.z],
                    [0, 0, 0, 1]
                )
                
                _ = transMatrix * rotMatrix * scaleMatrix
            }
        }
    }
    
    /// 测试GameEngine完整初始化性能
    func testGameEngineFullInitializationPerformance() throws {
        measure {
            let gameEngine = GameEngine.shared
            try! gameEngine.initialize()
            gameEngine.stop() // 确保停止以便重复测试
        }
    }
}
