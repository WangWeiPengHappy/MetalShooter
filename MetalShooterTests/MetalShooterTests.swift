//
//  MetalShooterTests.swift
//  MetalShooterTests
//
//  Metal4 射击游戏单元测试
//  测试ECS架构和数学系统的正确性
//

import XCTest
import simd
import Metal
import MetalKit
@testable import MetalShooter

/// Metal4 射击游戏核心系统单元测试
final class MetalShooterTests: XCTestCase {

    // MARK: - 测试生命周期
    
    override func setUpWithError() throws {
        // 在每个测试方法运行前调用
        super.setUp()
    }

    override func tearDownWithError() throws {
        // 在每个测试方法运行后调用
        super.tearDown()
    }

    // MARK: - ECS系统测试
    
    /// 测试实体管理器基本功能
    func testEntityManagerBasicOperations() throws {
        print("🧪 测试实体管理器基本操作...")
        
        let entityManager = EntityManager.shared
        
        // 测试实体创建
        let entityId = entityManager.createEntity()
        XCTAssertNotNil(entityId, "实体ID不应为空")
        print("✅ 实体创建成功: \(entityId)")
        
        // 测试实体销毁
        entityManager.destroyEntity(entityId)
        print("✅ 实体销毁成功")
    }
    
    /// 测试TransformComponent组件功能
    func testTransformComponent() throws {
        print("🧪 测试TransformComponent组件...")
        
        let entityManager = EntityManager.shared
        let entityId = entityManager.createEntity()
        
        // 创建变换组件
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        
        // 添加组件到实体
        entityManager.addComponent(transform, to: entityId)
        print("✅ TransformComponent 添加成功")
        
        // 查询组件
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entityId)
        XCTAssertNotNil(retrievedTransform, "应该能够查询到已添加的TransformComponent")
        
        if let retrievedTransform = retrievedTransform {
            XCTAssertEqual(retrievedTransform.localPosition, Float3(1, 2, 3), "位置应该匹配")
            XCTAssertEqual(retrievedTransform.localScale, Float3(1, 1, 1), "缩放应该匹配")
            print("✅ TransformComponent 查询成功")
            print("   位置: \(retrievedTransform.localPosition)")
            print("   旋转: \(retrievedTransform.localRotation)")
            print("   缩放: \(retrievedTransform.localScale)")
        }
        
        // 清理
        entityManager.destroyEntity(entityId)
    }
    
    /// 测试RenderComponent组件功能
    func testRenderComponent() throws {
        print("🧪 测试RenderComponent组件...")
        
        let entityManager = EntityManager.shared
        let entityId = entityManager.createEntity()
        
        // 测试渲染组件
        let renderComponent = RenderComponent()
        entityManager.addComponent(renderComponent, to: entityId)
        print("✅ RenderComponent 添加成功")
        
        // 验证组件存在
        let retrievedRender = entityManager.getComponent(RenderComponent.self, for: entityId)
        XCTAssertNotNil(retrievedRender, "应该能够查询到已添加的RenderComponent")
        
        // 清理
        entityManager.destroyEntity(entityId)
    }
    
    /// 测试CameraComponent组件功能
    func testCameraComponent() throws {
        print("🧪 测试CameraComponent组件...")
        
        let entityManager = EntityManager.shared
        let entityId = entityManager.createEntity()
        
        // 测试相机组件
        let cameraComponent = CameraComponent()
        entityManager.addComponent(cameraComponent, to: entityId)
        print("✅ CameraComponent 添加成功")
        
        // 验证组件存在
        let retrievedCamera = entityManager.getComponent(CameraComponent.self, for: entityId)
        XCTAssertNotNil(retrievedCamera, "应该能够查询到已添加的CameraComponent")
        
        // 清理
        entityManager.destroyEntity(entityId)
    }
    
    /// 测试组件标签系统
    func testComponentTagSystem() throws {
        print("🧪 测试组件标签系统...")
        
        let entityManager = EntityManager.shared
        let entityId = entityManager.createEntity()
        
        // 创建组件
        let transform = TransformComponent()
        let renderComponent = RenderComponent()
        let cameraComponent = CameraComponent()
        
        // 添加组件
        entityManager.addComponent(transform, to: entityId)
        entityManager.addComponent(renderComponent, to: entityId)
        entityManager.addComponent(cameraComponent, to: entityId)
        
        // 测试组件标签
        transform.addTag(.spatial)
        renderComponent.addTag(.renderable)
        cameraComponent.addTag(.camera)
        
        XCTAssertTrue(transform.hasTag(.spatial), "Transform组件应该有spatial标签")
        XCTAssertTrue(renderComponent.hasTag(.renderable), "Render组件应该有renderable标签")
        XCTAssertTrue(cameraComponent.hasTag(.camera), "Camera组件应该有camera标签")
        
        print("✅ 组件标签系统工作正常")
        
        // 清理
        entityManager.destroyEntity(entityId)
    }
    
    /// 测试组件查询系统
    func testComponentQuerySystem() throws {
        print("🧪 测试组件查询系统...")
        
        let entityManager = EntityManager.shared
        let entityId1 = entityManager.createEntity()
        let entityId2 = entityManager.createEntity()
        
        // 添加不同的组件
        entityManager.addComponent(TransformComponent(), to: entityId1)
        entityManager.addComponent(RenderComponent(), to: entityId1)
        entityManager.addComponent(TransformComponent(), to: entityId2)
        
        // 测试组件查询
        let transformComponents = entityManager.getAllComponents(TransformComponent.self)
        let renderComponents = entityManager.getAllComponents(RenderComponent.self)
        let cameraComponents = entityManager.getAllComponents(CameraComponent.self)
        
        XCTAssertEqual(transformComponents.count, 2, "应该有2个Transform组件")
        XCTAssertEqual(renderComponents.count, 1, "应该有1个Render组件")
        XCTAssertEqual(cameraComponents.count, 0, "应该有0个Camera组件")
        
        print("✅ 系统中有 \(transformComponents.count) 个变换组件，\(renderComponents.count) 个渲染组件，\(cameraComponents.count) 个相机组件")
        
        // 清理
        entityManager.destroyEntity(entityId1)
        entityManager.destroyEntity(entityId2)
    }

    // MARK: - 数学系统测试
    
    /// 测试Float3向量运算
    func testFloat3VectorOperations() throws {
        print("🧪 测试Float3向量运算...")
        
        let pos1 = Float3(1, 2, 3)
        let pos2 = Float3(4, 5, 6)
        let sum = pos1 + pos2
        let expectedSum = Float3(5, 7, 9)
        
        XCTAssertEqual(sum, expectedSum, "Float3加法运算结果应该正确")
        print("✅ Float3 运算: \(pos1) + \(pos2) = \(sum)")
        
        // 测试向量长度
        let vector = Float3(3, 4, 0)
        let length = vector.length
        XCTAssertEqual(length, 5.0, accuracy: 0.001, "向量长度计算应该正确")
        
        // 测试向量单位化
        let normalized = vector.normalized
        XCTAssertEqual(normalized.length, 1.0, accuracy: 0.001, "单位化向量长度应该为1")
    }
    
    /// 测试Float4x4矩阵运算
    func testFloat4x4MatrixOperations() throws {
        print("🧪 测试Float4x4矩阵运算...")
        
        let identity = Float4x4.identity
        let translation = Float4x4.translation(Float3(1, 0, 0))
        let result = identity * translation
        
        // 验证单位矩阵
        XCTAssertEqual(identity.columns.0.x, 1.0, "单位矩阵第一列第一行应该为1")
        XCTAssertEqual(identity.columns.1.y, 1.0, "单位矩阵第二列第二行应该为1")
        XCTAssertEqual(identity.columns.2.z, 1.0, "单位矩阵第三列第三行应该为1")
        XCTAssertEqual(identity.columns.3.w, 1.0, "单位矩阵第四列第四行应该为1")
        
        // 验证平移矩阵
        XCTAssertEqual(translation.columns.3.x, 1.0, "平移矩阵X分量应该正确")
        
        print("✅ Float4x4 矩阵运算正常")
    }
    
    /// 测试四元数运算
    func testQuaternionOperations() throws {
        print("🧪 测试四元数运算...")
        
        let rotation = simd_quatf(angle: Float.pi/4, axis: Float3(0, 1, 0))
        let rotationMatrix = Float4x4.rotation(from: rotation)
        
        // 验证四元数不为零
        XCTAssertNotEqual(rotation.vector.x, 0, "四元数应该有有效值")
        
        // 验证旋转矩阵不为零矩阵
        let matrixSum = rotationMatrix.columns.0.x + rotationMatrix.columns.1.y + 
                       rotationMatrix.columns.2.z + rotationMatrix.columns.3.w
        XCTAssertNotEqual(matrixSum, 0, "旋转矩阵应该有有效值")
        
        print("✅ 四元数到矩阵转换正常")
    }
    
    /// 测试AABB包围盒
    func testAABBBoundingBox() throws {
        print("🧪 测试AABB包围盒...")
        
        let aabb = AABB(min: Float3(-1, -1, -1), max: Float3(1, 1, 1))
        
        // 测试点包含检测
        XCTAssertTrue(aabb.contains(Float3(0, 0, 0)), "原点应该在包围盒内")
        XCTAssertFalse(aabb.contains(Float3(2, 2, 2)), "外部点不应该在包围盒内")
        
        // 测试包围盒属性
        XCTAssertEqual(aabb.center, Float3(0, 0, 0), "包围盒中心应该在原点")
        XCTAssertEqual(aabb.size, Float3(2, 2, 2), "包围盒大小应该正确")
        
        print("✅ AABB包围盒测试通过")
    }

    // MARK: - 性能测试
    
    /// 测试实体创建性能
    func testEntityCreationPerformance() throws {
        self.measure {
            let entityManager = EntityManager.shared
            var entities: [UUID] = []
            
            // 创建1000个实体
            for _ in 0..<1000 {
                entities.append(entityManager.createEntity())
            }
            
            // 清理
            for entityId in entities {
                entityManager.destroyEntity(entityId)
            }
        }
    }
    
    /// 测试组件添加性能
    func testComponentAddPerformance() throws {
        let entityManager = EntityManager.shared
        var entities: [UUID] = []
        
        // 预创建实体
        for _ in 0..<100 {
            entities.append(entityManager.createEntity())
        }
        
        self.measure {
            // 为每个实体添加组件
            for entityId in entities {
                entityManager.addComponent(TransformComponent(), to: entityId)
                entityManager.addComponent(RenderComponent(), to: entityId)
            }
        }
        
        // 清理
        for entityId in entities {
            entityManager.destroyEntity(entityId)
        }
    }

    // MARK: - 集成测试
    
    /// 综合测试ECS系统完整功能
    func testECSSystemIntegration() throws {
        print("🧪 综合测试ECS系统...")
        
        let entityManager = EntityManager.shared
        
        // 创建一个游戏对象实体
        let gameObjectId = entityManager.createEntity()
        
        // 添加所有核心组件
        let transform = TransformComponent(
            position: Float3(10, 5, -3),
            rotation: simd_quatf(angle: Float.pi/6, axis: Float3(0, 1, 0)),
            scale: Float3(2, 2, 2)
        )
        let render = RenderComponent()
        let camera = CameraComponent()
        
        entityManager.addComponent(transform, to: gameObjectId)
        entityManager.addComponent(render, to: gameObjectId)
        entityManager.addComponent(camera, to: gameObjectId)
        
        // 验证所有组件都存在
        XCTAssertNotNil(entityManager.getComponent(TransformComponent.self, for: gameObjectId))
        XCTAssertNotNil(entityManager.getComponent(RenderComponent.self, for: gameObjectId))
        XCTAssertNotNil(entityManager.getComponent(CameraComponent.self, for: gameObjectId))
        
        // 测试组件数据
        if let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: gameObjectId) {
            XCTAssertEqual(retrievedTransform.localPosition, Float3(10, 5, -3))
            XCTAssertEqual(retrievedTransform.localScale, Float3(2, 2, 2))
        }
        
        print("✅ ECS系统集成测试通过")
        
        // 清理
        entityManager.destroyEntity(gameObjectId)
    }
    
    // MARK: - Phase 2 Metal渲染系统测试
    
    /// 测试Metal渲染器初始化
    func testMetalRendererInitialization() throws {
        print("🧪 测试MetalRenderer初始化...")
        
        // 创建测试用MTKView
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal不可用，跳过Metal渲染器测试")
            return
        }
        
        // 验证Metal 4支持
        if !device.supportsFamily(.metal4) {
            XCTSkip("Metal 4不受支持，跳过测试")
        }
        
        let metalView = MTKView()
        metalView.device = device
        metalView.drawableSize = CGSize(width: 800, height: 600)
        
        // 创建渲染器
        let renderer = MetalRenderer()
        
        // 测试初始化
        XCTAssertNoThrow(try renderer.initialize(with: metalView), "MetalRenderer初始化不应抛出异常")
        
        // 验证设备设置
        XCTAssertNotNil(renderer.currentDevice, "Metal设备应该已设置")
        XCTAssertNotNil(renderer.currentCommandQueue, "命令队列应该已创建")
        
        print("✅ MetalRenderer初始化测试通过")
    }
    
    /// 测试GameEngine生命周期
    func testGameEngineLifecycle() throws {
        print("🧪 测试GameEngine生命周期...")
        
        let gameEngine = GameEngine.shared
        
        // 测试初始状态
        XCTAssertFalse(gameEngine.currentlyRunning, "GameEngine初始时不应该运行")
        XCTAssertFalse(gameEngine.currentlyPaused, "GameEngine初始时不应该暂停")
        
        // 测试初始化
        XCTAssertNoThrow(try gameEngine.initialize(), "GameEngine初始化不应抛出异常")
        
        // 测试启动
        gameEngine.start()
        XCTAssertTrue(gameEngine.currentlyRunning, "GameEngine启动后应该在运行状态")
        XCTAssertFalse(gameEngine.currentlyPaused, "GameEngine启动后不应该暂停")
        
        // 测试暂停
        gameEngine.pause()
        XCTAssertTrue(gameEngine.currentlyPaused, "GameEngine暂停后应该处于暂停状态")
        
        // 测试恢复
        gameEngine.resume()
        XCTAssertFalse(gameEngine.currentlyPaused, "GameEngine恢复后不应该暂停")
        
        // 测试停止
        gameEngine.stop()
        XCTAssertFalse(gameEngine.currentlyRunning, "GameEngine停止后不应该运行")
        
        print("✅ GameEngine生命周期测试通过")
    }
    
    /// 测试Time系统功能
    func testTimeSystem() throws {
        print("🧪 测试Time系统...")
        
        let timeManager = Time.shared
        
        // 测试初始状态
        XCTAssertEqual(timeManager.deltaTime, 0, accuracy: 0.001, "初始deltaTime应为0")
        XCTAssertEqual(timeManager.totalTime, 0, accuracy: 0.001, "初始totalTime应为0")
        XCTAssertEqual(timeManager.frameCount, 0, "初始frameCount应为0")
        
        // 测试启动
        timeManager.start()
        
        // 等待一小段时间模拟帧更新
        let expectation = XCTestExpectation(description: "Time system update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            timeManager.update()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // 验证时间更新
        XCTAssertGreaterThan(timeManager.deltaTime, 0, "deltaTime应该大于0")
        XCTAssertGreaterThan(timeManager.totalTime, 0, "totalTime应该大于0")
        XCTAssertGreaterThan(timeManager.frameCount, 0, "frameCount应该大于0")
        
        // 测试FPS计算
        XCTAssertGreaterThan(timeManager.fps, 0, "FPS应该大于0")
        
        // 测试重置
        timeManager.reset()
        XCTAssertEqual(timeManager.deltaTime, 0, accuracy: 0.001, "重置后deltaTime应为0")
        XCTAssertEqual(timeManager.totalTime, 0, accuracy: 0.001, "重置后totalTime应为0")
        XCTAssertEqual(timeManager.frameCount, 0, "重置后frameCount应为0")
        
        print("✅ Time系统测试通过")
    }
    
    /// 测试渲染管道验证
    func testRenderPipelineValidation() throws {
        print("🧪 测试渲染管道验证...")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal不可用，跳过渲染管道测试")
            return
        }
        
        if !device.supportsFamily(.metal4) {
            XCTSkip("Metal 4不受支持，跳过测试")
        }
        
        let metalView = MTKView()
        metalView.device = device
        metalView.drawableSize = CGSize(width: 800, height: 600)
        
        let renderer = MetalRenderer()
        
        XCTAssertNoThrow(try renderer.initialize(with: metalView), "渲染器初始化不应失败")
        
        // 验证渲染管道状态
        XCTAssertNotNil(renderer.currentRenderPipelineState, "渲染管道状态应该已创建")
        XCTAssertNotNil(renderer.currentDepthStencilState, "深度模板状态应该已创建")
        
        // 验证Uniform缓冲区
        XCTAssertEqual(renderer.currentUniformBuffers.count, renderer.currentMaxBuffersInFlight, "Uniform缓冲区数量应该正确")
        
        // 验证视口大小
        XCTAssertEqual(renderer.currentViewportSize.width, 800, "视口宽度应该正确")
        XCTAssertEqual(renderer.currentViewportSize.height, 600, "视口高度应该正确")
        
        print("✅ 渲染管道验证测试通过")
    }
    
    /// 测试着色器编译
    func testShaderCompilation() throws {
        print("🧪 测试着色器编译...")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal不可用，跳过着色器测试")
            return
        }
        
        // 测试着色器库加载
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            XCTFail("无法加载默认着色器库")
            return
        }
        
        // 测试顶点着色器函数
        let vertexFunction = defaultLibrary.makeFunction(name: "vertex_main")
        XCTAssertNotNil(vertexFunction, "vertex_main函数应该存在")
        
        // 测试片元着色器函数
        let fragmentFunction = defaultLibrary.makeFunction(name: "fragment_main")
        XCTAssertNotNil(fragmentFunction, "fragment_main函数应该存在")
        
        // 测试简单顶点着色器函数
        let simpleVertexFunction = defaultLibrary.makeFunction(name: "vertex_simple")
        XCTAssertNotNil(simpleVertexFunction, "vertex_simple函数应该存在")
        
        // 测试简单片元着色器函数
        let simpleFragmentFunction = defaultLibrary.makeFunction(name: "fragment_simple")
        XCTAssertNotNil(simpleFragmentFunction, "fragment_simple函数应该存在")
        
        print("✅ 着色器编译测试通过")
    }
    
    /// 测试Phase 2系统集成
    func testPhase2SystemIntegration() throws {
        print("🧪 测试Phase 2系统集成...")
        
        // 测试GameEngine和MetalRenderer集成
        let gameEngine = GameEngine.shared
        
        // 初始化游戏引擎（这会创建Metal渲染器）
        XCTAssertNoThrow(try gameEngine.initialize(), "GameEngine初始化应该成功")
        
        // 验证渲染器已创建
        XCTAssertNotNil(gameEngine.metalRenderer, "MetalRenderer应该已创建")
        
        // 验证时间系统集成
        XCTAssertNotNil(gameEngine.currentTimeManager, "时间管理器应该存在")
        
        // 验证实体管理器集成
        XCTAssertNotNil(gameEngine.currentEntityManager, "实体管理器应该存在")
        
        // 启动引擎
        gameEngine.start()
        XCTAssertTrue(gameEngine.currentlyRunning, "游戏引擎应该在运行")
        
        // 停止引擎
        gameEngine.stop()
        XCTAssertFalse(gameEngine.currentlyRunning, "游戏引擎应该已停止")
        
        print("✅ Phase 2系统集成测试通过")
    }
}
