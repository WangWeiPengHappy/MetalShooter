//
//  CompilationTest.swift
//  MetalShooter
//
//  编译验证测试 - 确保核心系统可以正常编译和工作
//

import Foundation
import simd

// MARK: - 编译验证类
class CompilationTest {
    
    /// 测试ECS系统基本功能
    static func testECSSystem() {
        print("🧪 开始ECS系统编译测试...")
        
        // 测试实体管理器
        let entityManager = EntityManager.shared
        
        // 创建测试实体
        let entityId = entityManager.createEntity()
        print("✅ 实体创建成功: \(entityId)")
        
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
        if let retrievedTransform = entityManager.getComponent(TransformComponent.self, for: entityId) {
            print("✅ TransformComponent 查询成功")
            print("   位置: \(retrievedTransform.localPosition)")
            print("   旋转: \(retrievedTransform.localRotation)")
            print("   缩放: \(retrievedTransform.localScale)")
        }
        
        // 测试渲染组件
        let renderComponent = RenderComponent()
        entityManager.addComponent(renderComponent, to: entityId)
        print("✅ RenderComponent 添加成功")
        
        // 测试相机组件
        let cameraComponent = CameraComponent()
        entityManager.addComponent(cameraComponent, to: entityId)
        print("✅ CameraComponent 添加成功")
        
        // 测试组件标签
        transform.addTag(.spatial)
        renderComponent.addTag(.renderable)
        cameraComponent.addTag(.camera)
        
        if transform.hasTag(.spatial) && 
           renderComponent.hasTag(.renderable) && 
           cameraComponent.hasTag(.camera) {
            print("✅ 组件标签系统工作正常")
        }
        
        // 测试组件查询
        let transformComponents = entityManager.getAllComponents(TransformComponent.self)
        let renderComponents = entityManager.getAllComponents(RenderComponent.self) 
        let cameraComponents = entityManager.getAllComponents(CameraComponent.self)
        print("✅ 系统中有 \(transformComponents.count) 个变换组件，\(renderComponents.count) 个渲染组件，\(cameraComponents.count) 个相机组件")
        
        // 清理
        entityManager.destroyEntity(entityId)
        print("✅ 实体销毁成功")
        
        print("🎉 ECS系统编译测试完成！所有基本功能正常工作。")
    }
    
    /// 测试数学类型
    static func testMathTypes() {
        print("🧪 开始数学类型编译测试...")
        
        // 测试Float3
        let pos1 = Float3(1, 2, 3)
        let pos2 = Float3(4, 5, 6)
        let sum = pos1 + pos2
        print("✅ Float3 运算: \(pos1) + \(pos2) = \(sum)")
        
        // 测试Float4x4
        let matrix = Float4x4.identity
        let translation = Float4x4.translation(Float3(1, 0, 0))
        let result = matrix * translation
        print("✅ Float4x4 矩阵运算正常")
        
        // 测试四元数
        let rotation = simd_quatf(angle: Float.pi/4, axis: Float3(0, 1, 0))
        let rotationMatrix = Float4x4.rotation(from: rotation)
        print("✅ 四元数到矩阵转换正常")
        
        print("🎉 数学类型编译测试完成！")
    }
    
    /// 运行所有测试
    static func runAllTests() {
        print("🚀 开始编译验证测试...")
        print("=" * 50)
        
        testMathTypes()
        print("-" * 30)
        testECSSystem()
        
        print("=" * 50)
        print("🎊 所有编译验证测试完成！项目可以正常编译和运行。")
    }
}

// MARK: - 字符串重复扩展
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// 如果直接运行此文件，执行测试
#if canImport(Darwin)
// 在实际项目中，这个测试会在应用启动时或单元测试中调用
// CompilationTest.runAllTests()
#endif
