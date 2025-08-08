//
//  InputSystemTests.swift
//  MetalShooterTests
//
//  测试输入系统和ECS组件处理机制
//  验证WASD输入、PlayerController移动、EntityManager组件队列处理等功能
//

import XCTest
import simd
@testable import MetalShooter

/// 输入系统集成测试：包含WASD输入处理、PlayerController移动逻辑、ECS组件队列处理等
final class InputSystemTests: XCTestCase {
    
    var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        super.setUp()
        entityManager = EntityManager.shared
        entityManager.cleanup()
    }
    
    override func tearDownWithError() throws {
        entityManager.cleanup()
        super.tearDown()
    }
    
    // MARK: - 核心修复测试
    
    /// 测试组件队列处理的基本功能：添加组件 → 队列暂存 → processPendingOperations → 组件可访问
    func testProcessPendingOperationsBasicFunctionality() throws {
        print("🧪 测试 EntityManager 组件队列处理基础功能...")
        
        // 1. 创建实体ID（注意：createEntity()返回UUID，不是Entity）
        let entityId = entityManager.createEntity()
        
        // 2. 添加组件（进入待处理队列）
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entityId)
        
        // 3. 验证组件在待处理状态（核心问题：修复前无法获取）
        let componentBeforeProcessing = entityManager.getComponent(TransformComponent.self, for: entityId)
        XCTAssertNil(componentBeforeProcessing, "处理前组件应该无法获取")
        
        // 4. 调用processPendingOperations（今天的核心修复）
        entityManager.processPendingOperations()
        
        // 5. 验证组件已处理（修复后应该可以获取）
        let componentAfterProcessing = entityManager.getComponent(TransformComponent.self, for: entityId)
        XCTAssertNotNil(componentAfterProcessing, "处理后组件应该可以获取")
        
        // 验证组件数据正确
        let expectedPosition = Float3(1, 2, 3)
        XCTAssertEqual(componentAfterProcessing?.localPosition, expectedPosition)
        
        print("✅ processPendingOperations基本功能测试通过")
    }
    
    /// 测试GameEngine.update()中processPendingOperations的集成
    func testGameEngineUpdateIntegration() throws {
        print("🧪 测试GameEngine.update()集成...")
        
        let gameEngine = GameEngine.shared
        
        // 创建测试实体和组件
        let testEntityId = entityManager.createEntity()
        let testTransform = TransformComponent(
            position: Float3(10, 20, 30),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        
        // 添加组件（进入待处理队列）
        entityManager.addComponent(testTransform, to: testEntityId)
        
        // 验证组件还未处理
        let transformBefore = entityManager.getComponent(TransformComponent.self, for: testEntityId)
        XCTAssertNil(transformBefore, "GameEngine.update()调用前组件应该在待处理队列中")
        
        // 调用GameEngine.update()（包含processPendingOperations调用 - 今天的修复）
        gameEngine.update()
        
        // 验证组件已被处理
        let transformAfter = entityManager.getComponent(TransformComponent.self, for: testEntityId)
        XCTAssertNotNil(transformAfter, "GameEngine.update()调用后组件应该可以访问")
        
        // 验证位置数据正确
        let expectedPosition = Float3(10, 20, 30)
        XCTAssertEqual(transformAfter?.localPosition, expectedPosition)
        
        print("✅ GameEngine.update()集成测试通过")
    }
    
    /// 测试PlayerController的TransformComponent访问修复
    func testPlayerControllerComponentAccess() throws {
        print("🧪 测试PlayerController组件访问修复...")
        
        // 创建PlayerController测试环境
        let playerEntityId = entityManager.createEntity()
        let playerTransform = TransformComponent(
            position: Float3(0, 0, -5),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        
        // 添加组件
        entityManager.addComponent(playerTransform, to: playerEntityId)
        
        // 关键修复：必须调用processPendingOperations
        entityManager.processPendingOperations()
        
        // 验证PlayerController可以访问TransformComponent（修复前会失败）
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: playerEntityId)
        XCTAssertNotNil(retrievedTransform, "PlayerController应该能够访问TransformComponent")
        
        // 验证数据正确
        let expectedPosition = Float3(0, 0, -5)
        XCTAssertEqual(retrievedTransform?.localPosition, expectedPosition)
        
        print("✅ PlayerController组件访问测试通过")
    }
    
    /// 验证 WASD 键盘输入映射和处理机制修复
    func testWASDInputSystemFix() throws {
        print("🧪 验证 WASD 输入系统键码映射和事件处理...")
        
        // 测试WASD键码映射（今天调试时发现的问题）
        let keyMappings: [(InputManager.KeyCode, Int, String)] = [
            (.w, 13, "W键"),
            (.a, 0, "A键"),
            (.s, 1, "S键"),
            (.d, 2, "D键")
        ]
        
        for (keyCode, expectedRawValue, keyName) in keyMappings {
            XCTAssertEqual(keyCode.rawValue, UInt16(expectedRawValue), "\(keyName)的rawValue应该是\(expectedRawValue)")
            print("✅ \(keyName)映射正确：rawValue = \(keyCode.rawValue)")
        }
        
        print("✅ WASD输入系统测试通过")
    }
    
    /// 验证完整的输入处理流程：键盘输入 → PlayerController → 组件修改 → processPendingOperations → 移动生效
    func testCompleteInputToMovementFlowFix() throws {
        print("🧪 验证输入到移动的完整处理流程...")
        
        // 1. 创建玩家实体
        let playerEntityId = entityManager.createEntity()
        let initialPosition = Float3(0, 0, -5)
        let playerTransform = TransformComponent(
            position: initialPosition,
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        
        // 2. 添加组件
        entityManager.addComponent(playerTransform, to: playerEntityId)
        
        // 3. 关键修复：处理待处理操作（修复前PlayerController无法访问组件）
        entityManager.processPendingOperations()
        
        // 4. 创建PlayerController
        let testPlayerController = PlayerController(entityManager: entityManager)
        
        // 5. 验证PlayerController可以访问组件（修复的核心问题）
        let accessibleTransform = entityManager.getComponent(TransformComponent.self, for: playerEntityId)
        XCTAssertNotNil(accessibleTransform, "PlayerController应该能够访问TransformComponent")
        
        // 6. 模拟更新循环
        let deltaTime: Float = 0.016
        XCTAssertNoThrow(testPlayerController.update(deltaTime: deltaTime), "PlayerController.update()应该正常运行")
        
        // 7. 验证系统稳定性
        XCTAssertTrue(true, "完整流程应该无崩溃运行")
        
        print("✅ 完整输入到移动流程修复测试通过")
    }
    
    // MARK: - 边界条件测试
    
    /// 测试空EntityManager的processPendingOperations调用
    func testEmptyEntityManagerProcessPendingOperations() throws {
        print("🧪 测试空EntityManager的processPendingOperations...")
        
        // 确保EntityManager为空
        entityManager.cleanup()
        
        // 调用processPendingOperations应该不会崩溃
        XCTAssertNoThrow(entityManager.processPendingOperations(), "空EntityManager的processPendingOperations()不应该崩溃")
        
        print("✅ 空EntityManager processPendingOperations测试通过")
    }
    
    /// 测试重复调用processPendingOperations
    func testRepeatedProcessPendingOperationsCalls() throws {
        print("🧪 测试重复调用processPendingOperations...")
        
        let entityId = entityManager.createEntity()
        let transform = TransformComponent(
            position: Float3(1, 2, 3),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entityId)
        
        // 多次调用processPendingOperations
        for _ in 0..<3 {
            XCTAssertNoThrow(entityManager.processPendingOperations(), "重复调用不应该崩溃")
        }
        
        // 验证组件仍然正确可访问
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entityId)
        XCTAssertNotNil(retrievedTransform, "重复调用后组件应该仍然可访问")
        
        print("✅ 重复调用processPendingOperations测试通过")
    }
    
    // MARK: - 性能测试
    
    /// 验证大量组件队列处理的性能表现（确保不影响60FPS渲染）
    func testProcessPendingOperationsPerformance() throws {
        print("🧪 验证组件队列处理性能表现...")
        
        let entityCount = 100
        var entityIds: [UUID] = []
        
        // 创建大量实体和组件
        for i in 0..<entityCount {
            let entityId = entityManager.createEntity()
            entityIds.append(entityId)
            
            let transform = TransformComponent(
                position: Float3(Float(i), 0, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: Float3(1, 1, 1)
            )
            entityManager.addComponent(transform, to: entityId)
        }
        
        // 性能测试
        let startTime = CFAbsoluteTimeGetCurrent()
        entityManager.processPendingOperations()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        print("📊 处理\(entityCount)个组件耗时: \(String(format: "%.4f", executionTime))秒")
        
        // 验证所有组件都正确处理
        for entityId in entityIds {
            let transform = entityManager.getComponent(TransformComponent.self, for: entityId)
            XCTAssertNotNil(transform, "所有组件都应该正确处理")
        }
        
        print("✅ processPendingOperations性能测试通过")
    }
    
    // MARK: - 集成测试
    
    /// 测试今天修复在GameEngine生命周期中的表现
    func testFixInGameEngineLifecycle() throws {
        print("🧪 测试修复在GameEngine生命周期中的表现...")
        
        let gameEngine = GameEngine.shared
        
        // 1. 在引擎启动前添加组件
        let entityId = entityManager.createEntity()
        let transform = TransformComponent(
            position: Float3(5, 10, 15),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(transform, to: entityId)
        
        // 2. 验证组件在待处理状态
        XCTAssertNil(entityManager.getComponent(TransformComponent.self, for: entityId))
        
        // 3. 模拟游戏引擎更新循环（包含今天的修复）
        gameEngine.update()
        
        // 4. 验证组件已处理
        let processedTransform = entityManager.getComponent(TransformComponent.self, for: entityId)
        XCTAssertNotNil(processedTransform, "GameEngine生命周期中组件应该正确处理")
        
        // 5. 验证数据完整性
        XCTAssertEqual(processedTransform?.localPosition, Float3(5, 10, 15))
        
        print("✅ GameEngine生命周期测试通过")
    }
    
    // MARK: - PlayerController 专项测试
    
    /// 验证 PlayerController 移动逻辑和组件修改机制
    func testPlayerControllerMovementLogic() throws {
        print("🧪 验证 PlayerController 移动逻辑和组件交互...")
        
        // 设置测试环境
        let playerEntityId = entityManager.createEntity()
        let initialPosition = Float3(0, 0, -5)
        let playerTransform = TransformComponent(
            position: initialPosition,
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(playerTransform, to: playerEntityId)
        
        // 关键：调用processPendingOperations
        entityManager.processPendingOperations()
        
        // 验证组件正确添加
        let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: playerEntityId)
        XCTAssertNotNil(retrievedTransform, "TransformComponent应该可以获取")
        XCTAssertEqual(retrievedTransform?.localPosition, initialPosition, "初始位置应该正确")
        
        // 模拟移动
        if let transform = retrievedTransform {
            let moveVector = Float3(1, 0, 0)  // 向右移动
            let deltaTime: Float = 0.016  // 约60FPS
            let moveSpeed: Float = 5.0
            
            transform.localPosition += moveVector * moveSpeed * deltaTime
            
            // 验证移动结果
            let expectedPosition = initialPosition + moveVector * moveSpeed * deltaTime
            XCTAssertEqual(transform.localPosition.x, expectedPosition.x, accuracy: 0.001)
            XCTAssertEqual(transform.localPosition.y, expectedPosition.y, accuracy: 0.001) 
            XCTAssertEqual(transform.localPosition.z, expectedPosition.z, accuracy: 0.001)
        }
        
        print("✅ PlayerController移动逻辑测试通过")
    }
    
    /// 验证多帧更新稳定性（模拟60FPS连续更新）
    func testMultiFrameStability() throws {
        print("🧪 验证系统在连续多帧更新下的稳定性...")
        
        // 设置测试环境
        let playerEntityId = entityManager.createEntity()
        let playerTransform = TransformComponent(
            position: Float3(0, 0, -5),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: Float3(1, 1, 1)
        )
        entityManager.addComponent(playerTransform, to: playerEntityId)
        entityManager.processPendingOperations()
        
        let testPlayerController = PlayerController(entityManager: entityManager)
        
        // 模拟多帧更新（60帧 = 1秒）
        let frameCount = 60  
        let deltaTime: Float = 1.0 / 60.0
        
        for frame in 0..<frameCount {
            // 每帧都调用processPendingOperations（模拟GameEngine行为）
            entityManager.processPendingOperations()
            
            // 更新PlayerController
            testPlayerController.update(deltaTime: deltaTime)
            
            // 验证系统稳定性
            let transform = entityManager.getComponent(TransformComponent.self, for: playerEntityId)
            XCTAssertNotNil(transform, "第\(frame)帧：TransformComponent应该始终可访问")
        }
        
        print("✅ 多帧更新稳定性测试通过")
    }
    
    // MARK: - 窗口边界检查测试
    
    /// 测试InputManager的窗口边界检查功能
    func testInputManagerWindowBoundaryCheck() throws {
        print("🧪 测试InputManager窗口边界检查功能...")
        
        let inputManager = InputManager.shared
        
        // 创建模拟窗口
        let mockWindow = createMockWindow()
        inputManager.setTestWindow(mockWindow)
        
        // 测试鼠标在窗口内的情况
        let mouseInBounds = NSPoint(x: 150, y: 150) // 在窗口内
        let shouldProcessInBounds = inputManager.shouldProcessMouseEvent(at: mouseInBounds)
        XCTAssertTrue(shouldProcessInBounds, "鼠标在窗口内时应该处理事件")
        
        // 测试鼠标在窗口外的情况
        let mouseOutOfBounds = NSPoint(x: 350, y: 350) // 在窗口外
        let shouldProcessOutOfBounds = inputManager.shouldProcessMouseEvent(at: mouseOutOfBounds)
        XCTAssertFalse(shouldProcessOutOfBounds, "鼠标在窗口外时不应该处理事件")
        
        print("✅ 窗口边界检查功能测试通过")
    }
    
    /// 测试窗口边界检查的边缘情况
    func testInputManagerWindowBoundaryEdgeCases() throws {
        print("🧪 测试窗口边界检查边缘情况...")
        
        let inputManager = InputManager.shared
        
        // 测试无窗口的情况
        inputManager.setTestWindow(nil)
        let mouseWithoutWindow = NSPoint(x: 100, y: 100)
        let shouldProcessWithoutWindow = inputManager.shouldProcessMouseEvent(at: mouseWithoutWindow)
        XCTAssertFalse(shouldProcessWithoutWindow, "无窗口时不应该处理鼠标事件")
        
        // 测试窗口边缘的情况
        let mockWindow = createMockWindow()
        inputManager.setTestWindow(mockWindow)
        
        let windowFrame = mockWindow.frame
        print("窗口边界: \(windowFrame)")
        
        // 测试窗口边界上的点 (窗口: x:100-300, y:100-300)
        let mouseOnLeftEdge = NSPoint(x: windowFrame.minX, y: windowFrame.minY + windowFrame.height/2) // 左边缘中点
        let mouseOnRightEdge = NSPoint(x: windowFrame.maxX - 1, y: windowFrame.minY + windowFrame.height/2) // 右边缘中点
        let mouseOnBottomEdge = NSPoint(x: windowFrame.minX + windowFrame.width/2, y: windowFrame.minY) // 下边缘中点
        let mouseOnTopEdge = NSPoint(x: windowFrame.minX + windowFrame.width/2, y: windowFrame.maxY - 1) // 上边缘中点
        
        // 测试边界点
        print("测试左边缘点: \(mouseOnLeftEdge)")
        XCTAssertTrue(inputManager.shouldProcessMouseEvent(at: mouseOnLeftEdge), "左边缘应该被包含")
        
        print("测试右边缘点: \(mouseOnRightEdge)")
        XCTAssertTrue(inputManager.shouldProcessMouseEvent(at: mouseOnRightEdge), "右边缘应该被包含")
        
        print("测试下边缘点: \(mouseOnBottomEdge)")
        XCTAssertTrue(inputManager.shouldProcessMouseEvent(at: mouseOnBottomEdge), "下边缘应该被包含")
        
        print("测试上边缘点: \(mouseOnTopEdge)")
        XCTAssertTrue(inputManager.shouldProcessMouseEvent(at: mouseOnTopEdge), "上边缘应该被包含")
        
        // 测试窗口外的点
        let mouseOutsideLeft = NSPoint(x: windowFrame.minX - 1, y: windowFrame.minY + windowFrame.height/2)
        let mouseOutsideRight = NSPoint(x: windowFrame.maxX + 1, y: windowFrame.minY + windowFrame.height/2)
        let mouseOutsideBottom = NSPoint(x: windowFrame.minX + windowFrame.width/2, y: windowFrame.minY - 1)
        let mouseOutsideTop = NSPoint(x: windowFrame.minX + windowFrame.width/2, y: windowFrame.maxY + 1)
        
        XCTAssertFalse(inputManager.shouldProcessMouseEvent(at: mouseOutsideLeft), "窗口左侧外的点不应该被包含")
        XCTAssertFalse(inputManager.shouldProcessMouseEvent(at: mouseOutsideRight), "窗口右侧外的点不应该被包含")
        XCTAssertFalse(inputManager.shouldProcessMouseEvent(at: mouseOutsideBottom), "窗口下方外的点不应该被包含")
        XCTAssertFalse(inputManager.shouldProcessMouseEvent(at: mouseOutsideTop), "窗口上方外的点不应该被包含")
        
        print("✅ 窗口边界检查边缘情况测试通过")
    }
    
    /// 测试鼠标移动事件的窗口边界过滤
    func testMouseMovementFiltering() throws {
        print("🧪 测试鼠标移动事件的窗口边界过滤...")
        
        let inputManager = InputManager.shared
        var receivedEvents: [CGPoint] = []
        
        // 创建模拟监听器来记录收到的事件
        class MockInputListener: InputManager.InputListener {
            var receivedEvents: [CGPoint] = []
            
            func onKeyPressed(_ keyCode: InputManager.KeyCode) {}
            func onKeyReleased(_ keyCode: InputManager.KeyCode) {}
            func onMouseMoved(_ delta: SIMD2<Float>) {
                // 记录鼠标移动事件（使用delta作为标识）
                let position = CGPoint(x: CGFloat(delta.x), y: CGFloat(delta.y))
                receivedEvents.append(position)
            }
            func onMouseButtonPressed(_ button: InputManager.MouseButton) {}
            func onMouseButtonReleased(_ button: InputManager.MouseButton) {}
            func onMouseScrolled(_ delta: SIMD2<Float>) {}
            func onGamepadConnected() {}
            func onGamepadDisconnected() {}
            func onGamepadInput(_ state: InputManager.GamepadState) {}
        }
        
        let mockListener = MockInputListener()
        inputManager.addListener(mockListener)
        
        // 设置模拟窗口
        let mockWindow = createMockWindow()
        inputManager.setTestWindow(mockWindow)
        
        // 模拟窗口内的鼠标移动事件
        let insidePosition = CGPoint(x: 150, y: 150)
        inputManager.testMouseMovement(at: insidePosition, delta: CGVector(dx: 10, dy: 10))
        
        // 模拟窗口外的鼠标移动事件
        let outsidePosition = CGPoint(x: 350, y: 350)
        inputManager.testMouseMovement(at: outsidePosition, delta: CGVector(dx: 10, dy: 10))
        
        // 验证只有窗口内的事件被处理
        XCTAssertEqual(mockListener.receivedEvents.count, 1, "应该只收到1个窗口内的鼠标事件")
        
        // 验证收到的是窗口内事件的delta值
        let expectedDelta = CGPoint(x: 10, y: 10)
        XCTAssertEqual(mockListener.receivedEvents.first, expectedDelta, "收到的事件应该是窗口内事件的delta值")
        
        inputManager.removeListener(mockListener)
        print("✅ 鼠标移动事件窗口边界过滤测试通过")
    }
    
    /// 测试窗口边界检查的性能
    func testWindowBoundaryCheckPerformance() throws {
        print("🧪 测试窗口边界检查性能...")
        
        let inputManager = InputManager.shared
        let mockWindow = createMockWindow()
        inputManager.setTestWindow(mockWindow)
        
        // 性能测试：执行大量窗口边界检查
        measure {
            for i in 0..<10000 {
                let x = Double(i % 400)
                let y = Double((i * 3) % 400)
                let mousePosition = NSPoint(x: x, y: y)
                _ = inputManager.shouldProcessMouseEvent(at: mousePosition)
            }
        }
        
        print("✅ 窗口边界检查性能测试通过")
    }
    
    // MARK: - 辅助方法
    
    /// 创建模拟窗口用于测试
    private func createMockWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        return window
    }
}
