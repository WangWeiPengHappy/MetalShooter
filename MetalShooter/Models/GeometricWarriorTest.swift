import Foundation
import Metal
import simd

/// 几何战士测试类 - 提供模型生成和验证功能
class GeometricWarriorTest {
    
    /// 运行所有测试
    static func runAllTests() {
        print("=== 几何战士模型测试开始 ===")
        
        testModelGeneration()
        testModelValidation()
        
        print("=== 几何战士模型测试完成 ===")
    }
    
    /// 测试模型生成
    private static func testModelGeneration() {
        print("📦 测试模型生成...")
        
        let generator = GeometricWarriorGenerator()
        let model = generator.generateModel()
        
        print("✅ 模型生成成功")
        print("   - 组件数量: \(model.components.count)")
        print("   - 总顶点数: \(model.components.map { $0.vertices.count }.reduce(0, +))")
        print("   - 总索引数: \(model.components.map { $0.indices.count }.reduce(0, +))")
    }
    
    /// 测试模型验证
    private static func testModelValidation() {
        print("🔍 测试模型验证...")
        
        let generator = GeometricWarriorGenerator()
        let model = generator.generateModel()
        
        // 验证基本结构
        assert(!model.components.isEmpty, "模型应该包含至少一个组件")
        
        for component in model.components {
            assert(!component.vertices.isEmpty, "组件应该包含顶点")
            assert(!component.indices.isEmpty, "组件应该包含索引")
            assert(!component.name.isEmpty, "组件应该有名称")
        }
        
        print("✅ 模型验证通过")
    }
}
