import Foundation
import Metal
import simd

// ModelComponent定义（之前缺失导致编译错误）
struct ModelComponent {
    let vertices: [Vertex]
    let indices: [UInt32]
    let materialId: String
    var transform: PlayerTransform
    let name: String
}

/// 玩家模型数据结构
struct PlayerModel {
    /// 模型名称
    let name: String
    
    /// 所有组件
    let components: [ModelComponent]
    
    /// 材质组，按材质ID分组的组件
    let materialGroups: [String: [ModelComponent]]
    
    /// 总顶点数
    var totalVertices: Int {
        return components.reduce(0) { $0 + $1.vertices.count }
    }
    
    /// 总面数
    var totalFaces: Int {
        return components.reduce(0) { $0 + $1.indices.count } / 3
    }
    
    /// 边界盒
    let boundingBox: BoundingBox
    
    /// 创建日期
    let createdAt: Date
    
    init(name: String, components: [ModelComponent]) {
        self.name = name
        self.components = components
        self.createdAt = Date()
        
        // 按材质ID分组组件
        var groups: [String: [ModelComponent]] = [:]
        for component in components {
            if groups[component.materialId] == nil {
                groups[component.materialId] = []
            }
            groups[component.materialId]?.append(component)
        }
        self.materialGroups = groups
        
        // 计算边界盒
        self.boundingBox = BoundingBox.calculateFrom(components: components)
    }
}

/// 边界盒
struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    var center: SIMD3<Float> {
        return (min + max) * 0.5
    }
    
    var size: SIMD3<Float> {
        return max - min
    }
    
    static func calculateFrom(components: [ModelComponent]) -> BoundingBox {
        guard !components.isEmpty else {
            return BoundingBox(min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(0, 0, 0))
        }
        
        var minValues = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxValues = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        for component in components {
            for vertex in component.vertices {
                let pos = vertex.position
                minValues = SIMD3<Float>(
                    Swift.min(minValues.x, pos.x),
                    Swift.min(minValues.y, pos.y),
                    Swift.min(minValues.z, pos.z)
                )
                maxValues = SIMD3<Float>(
                    Swift.max(maxValues.x, pos.x),
                    Swift.max(maxValues.y, pos.y),
                    Swift.max(maxValues.z, pos.z)
                )
            }
        }
        
        return BoundingBox(min: minValues, max: maxValues)
    }
}

// MARK: - Metal集成数据结构

/// Metal渲染用的模型数据
struct MetalModelData {
    /// 顶点缓冲区
    let vertexBuffer: MTLBuffer
    
    /// 索引缓冲区
    let indexBuffer: MTLBuffer
    
    /// 索引数量
    let indexCount: Int
    
    /// 材质数据
    let materials: [String: MaterialData]
    
    /// 渲染命令，按材质分组
    let renderCommands: [RenderCommand]
}

/// 渲染命令
struct RenderCommand {
    /// 起始索引位置
    let startIndex: Int
    
    /// 索引数量
    let indexCount: Int
    
    /// 材质ID
    let materialId: String
}

// MARK: - 工厂方法和扩展

extension PlayerModel {
    /// 创建空模型
    static func empty() -> PlayerModel {
        return PlayerModel(name: "Empty", components: [])
    }
    
    /// 获取指定材质的所有组件
    func components(withMaterial materialId: String) -> [ModelComponent] {
        return materialGroups[materialId] ?? []
    }
    
    /// 模型统计信息
    var stats: String {
        return """
        模型: \(name)
        组件数: \(components.count)
        材质数: \(materialGroups.count)
        总顶点数: \(totalVertices)
        总面数: \(totalFaces)
        边界盒: \(boundingBox.size)
        创建时间: \(createdAt)
        """
    }
}

// MARK: - matrix_float4x4 扩展

extension matrix_float4x4 {
    /// 创建平移矩阵
    init(translation: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }
    
    /// 创建X轴旋转矩阵
    init(rotationX angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, c, -s, 0),
            SIMD4<Float>(0, s, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    /// 创建Y轴旋转矩阵
    init(rotationY angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(c, 0, s, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(-s, 0, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    /// 创建Z轴旋转矩阵
    init(rotationZ angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(c, -s, 0, 0),
            SIMD4<Float>(s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    /// 创建缩放矩阵
    init(scaling: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(scaling.x, 0, 0, 0),
            SIMD4<Float>(0, scaling.y, 0, 0),
            SIMD4<Float>(0, 0, scaling.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
