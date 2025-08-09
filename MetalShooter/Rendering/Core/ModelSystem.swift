//
//  ModelSystem.swift
//  MetalShooter
//
//  Stage 4 - 3D模型系统核心
//  负责3D模型的加载、管理和渲染
//

import Foundation
import Metal
import MetalKit
import ModelIO
import simd

// MARK: - 类型定义

/// 内置模型类型
enum BuiltInModelType {
    case firstPersonRifle    // 第一人称步枪
    case firstPersonArms     // 第一人称手臂
    case cube               // 立方体
}

// MARK: - 3D模型数据结构

/// 顶点数据结构 - 支持完整的3D模型属性
struct ModelVertex {
    var position: Float3
    var normal: Float3
    var texCoords: Float2
    var tangent: Float3
    var bitangent: Float3
    var boneIndices: SIMD4<UInt16>  // 骨骼索引 (用于动画)
    var boneWeights: Float4         // 骨骼权重 (用于动画)
    
    init(position: Float3 = Float3(0,0,0),
         normal: Float3 = Float3(0,1,0),
         texCoords: Float2 = Float2(0,0),
         tangent: Float3 = Float3(1,0,0),
         bitangent: Float3 = Float3(0,0,1),
         boneIndices: SIMD4<UInt16> = SIMD4<UInt16>(0,0,0,0),
         boneWeights: Float4 = Float4(1,0,0,0)) {
        self.position = position
        self.normal = normal
        self.texCoords = texCoords
        self.tangent = tangent
        self.bitangent = bitangent
        self.boneIndices = boneIndices
        self.boneWeights = boneWeights
    }
}

/// 3D网格数据
class Model3D {
    let name: String
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer?
    let vertexCount: Int
    let indexCount: Int
    let primitiveType: MTLPrimitiveType
    let material: MaterialData?
    let boundingBox: AABB
    
    init(name: String,
         device: MTLDevice,
         vertices: [ModelVertex],
         indices: [UInt32]? = nil,
         material: MaterialData? = nil) {
        
        self.name = name
        self.vertexCount = vertices.count
        self.primitiveType = .triangle
        self.material = material
        
        // 创建顶点缓冲区
        guard let vertBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<ModelVertex>.stride,
            options: .storageModeShared
        ) else {
            fatalError("❌ 无法创建顶点缓冲区: \(name)")
        }
        self.vertexBuffer = vertBuffer
        
        // 创建索引缓冲区
        if let indices = indices {
            self.indexCount = indices.count
            guard let idxBuffer = device.makeBuffer(
                bytes: indices,
                length: indices.count * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ) else {
                fatalError("❌ 无法创建索引缓冲区: \(name)")
            }
            self.indexBuffer = idxBuffer
        } else {
            self.indexCount = 0
            self.indexBuffer = nil
        }
        
        // 计算包围盒
        self.boundingBox = Self.calculateBoundingBox(vertices: vertices)
        
        print("✅ 3D模型创建成功: \(name) (顶点: \(vertexCount), 索引: \(indexCount))")
    }
    
    /// 计算模型的包围盒
    private static func calculateBoundingBox(vertices: [ModelVertex]) -> AABB {
        guard !vertices.isEmpty else {
            return AABB(min: Float3(0,0,0), max: Float3(0,0,0))
        }
        
        let positions = vertices.map { $0.position }
        let minPos = Float3(
            positions.map { $0.x }.min()!,
            positions.map { $0.y }.min()!,
            positions.map { $0.z }.min()!
        )
        let maxPos = Float3(
            positions.map { $0.x }.max()!,
            positions.map { $0.y }.max()!,
            positions.map { $0.z }.max()!
        )
        
        return AABB(min: minPos, max: maxPos)
    }
    
    /// 绘制模型
    func draw(with encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        if let indexBuffer = indexBuffer {
            encoder.drawIndexedPrimitives(
                type: primitiveType,
                indexCount: indexCount,
                indexType: .uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        } else {
            encoder.drawPrimitives(
                type: primitiveType,
                vertexStart: 0,
                vertexCount: vertexCount
            )
        }
    }
}

// MARK: - 模型管理器

/// 3D模型管理器 - 负责所有3D模型的加载和管理
class ModelManager {
    
    static let shared = ModelManager()
    
    private var device: MTLDevice?
    private var models: [String: Model3D] = [:]
    private var loadedModelPaths: Set<String> = []
    
    private init() {}
    
    /// 初始化模型管理器
    func initialize(device: MTLDevice) {
        self.device = device
        print("🎨 ModelManager 初始化成功")
    }
    
    /// 获取模型
    func getModel(_ name: String) -> Model3D? {
        return models[name]
    }
    
    /// 创建内置模型
    func createBuiltInModel(_ type: BuiltInModelType, name: String) -> Model3D? {
        guard let device = device else {
            print("❌ ModelManager 未初始化")
            return nil
        }
        
        let model: Model3D
        
        switch type {
        case .firstPersonRifle:
            model = createFirstPersonWeapon(device: device, name: name)
        case .firstPersonArms:
            model = createFirstPersonArms(device: device, name: name)
        case .cube:
            model = createCube(device: device, name: name)
        }
        
        models[name] = model
        return model
    }
    
    /// 创建预定义的基础模型
    func createBuiltinModels() {
        guard let device = device else {
            print("❌ ModelManager 未初始化")
            return
        }
        
        // 创建第一人称武器模型
        _ = createBuiltInModel(.firstPersonRifle, name: "FirstPersonRifle")
        
        // 创建第一人称手臂模型
        _ = createBuiltInModel(.firstPersonArms, name: "FirstPersonArms")
        
        // 创建基础几何体
        _ = createBuiltInModel(.cube, name: "Cube")
        
        print("🔫 内置模型创建完成")
    }
    
    /// 创建第一人称武器模型
    private func createFirstPersonWeapon(device: MTLDevice, name: String) -> Model3D {
        // 简单的FPS步枪模型 (基于盒子几何体)
        let vertices = createWeaponVertices()
        let indices = createWeaponIndices()
        
        return Model3D(
            name: name,
            device: device,
            vertices: vertices,
            indices: indices
        )
    }
    
    /// 创建第一人称手臂模型
    private func createFirstPersonArms(device: MTLDevice, name: String) -> Model3D {
        // 简单的手臂模型
        let vertices = createArmsVertices()
        let indices = createArmsIndices()
        
        return Model3D(
            name: name,
            device: device,
            vertices: vertices,
            indices: indices
        )
    }
    
    /// 创建立方体模型
    private func createCube(device: MTLDevice, name: String) -> Model3D {
        // 立方体模型
        let vertices = createCubeVertices()
        let indices = createCubeIndices()
        
        return Model3D(
            name: name,
            device: device,
            vertices: vertices,
            indices: indices
        )
    }
    
    /// 清理资源
    func cleanup() {
        models.removeAll()
        loadedModelPaths.removeAll()
        device = nil
        print("🧹 ModelManager 资源清理完成")
    }
}

// MARK: - 几何体生成辅助方法

extension ModelManager {
    
    /// 创建武器顶点数据 (简化的FPS步枪)
    private func createWeaponVertices() -> [ModelVertex] {
        // FPS武器的关键部件顶点
        // 枪身、枪管、握把、扳机护圈等
        var vertices: [ModelVertex] = []
        
        // 枪身主体 (矩形盒子)
        let bodyLength: Float = 1.0
        let bodyWidth: Float = 0.1
        let bodyHeight: Float = 0.15
        
        // 前端 (枪口)
        let front = Float3(bodyLength/2, 0, 0)
        // 后端 (枪托)
        let back = Float3(-bodyLength/2, 0, 0)
        
        // 生成枪身的8个顶点
        let positions = [
            Float3(back.x, -bodyWidth/2, -bodyHeight/2),   // 0: 后左下
            Float3(back.x, bodyWidth/2, -bodyHeight/2),    // 1: 后右下
            Float3(back.x, bodyWidth/2, bodyHeight/2),     // 2: 后右上
            Float3(back.x, -bodyWidth/2, bodyHeight/2),    // 3: 后左上
            Float3(front.x, -bodyWidth/2, -bodyHeight/2),  // 4: 前左下
            Float3(front.x, bodyWidth/2, -bodyHeight/2),   // 5: 前右下
            Float3(front.x, bodyWidth/2, bodyHeight/2),    // 6: 前右上
            Float3(front.x, -bodyWidth/2, bodyHeight/2)    // 7: 前左上
        ]
        
        // 为每个位置创建顶点
        for (i, pos) in positions.enumerated() {
            let texCoord = Float2(Float(i % 2), Float((i / 2) % 2))
            vertices.append(ModelVertex(
                position: pos,
                normal: Float3(0, 0, 1), // 临时法线
                texCoords: texCoord
            ))
        }
        
        return vertices
    }
    
    /// 创建武器索引数据
    private func createWeaponIndices() -> [UInt32] {
        // 立方体的12个三角形 (每个面2个三角形)
        return [
            // 前面
            4, 5, 6,  4, 6, 7,
            // 后面
            0, 2, 1,  0, 3, 2,
            // 左面
            0, 4, 7,  0, 7, 3,
            // 右面
            1, 2, 6,  1, 6, 5,
            // 上面
            3, 7, 6,  3, 6, 2,
            // 下面
            0, 1, 5,  0, 5, 4
        ]
    }
    
    /// 创建手臂顶点数据
    private func createArmsVertices() -> [ModelVertex] {
        var vertices: [ModelVertex] = []
        
        // 右手臂 (简单的圆柱体)
        let armLength: Float = 0.8
        let armRadius: Float = 0.08
        let segments = 8
        
        for i in 0..<segments {
            let angle = Float(i) * 2.0 * .pi / Float(segments)
            let x = cos(angle) * armRadius
            let z = sin(angle) * armRadius
            
            // 手臂起始点 (肩膀)
            vertices.append(ModelVertex(
                position: Float3(x, 0, z),
                normal: Float3(x, 0, z).normalized,
                texCoords: Float2(Float(i) / Float(segments), 0)
            ))
            
            // 手臂结束点 (手腕)
            vertices.append(ModelVertex(
                position: Float3(x, -armLength, z),
                normal: Float3(x, 0, z).normalized,
                texCoords: Float2(Float(i) / Float(segments), 1)
            ))
        }
        
        return vertices
    }
    
    /// 创建手臂索引数据
    private func createArmsIndices() -> [UInt32] {
        var indices: [UInt32] = []
        let segments = 8
        
        for i in 0..<segments {
            let current = i * 2
            let next = ((i + 1) % segments) * 2
            
            // 每个段创建2个三角形
            indices.append(contentsOf: [
                UInt32(current), UInt32(current + 1), UInt32(next),
                UInt32(current + 1), UInt32(next + 1), UInt32(next)
            ])
        }
        
        return indices
    }
    
    /// 创建立方体顶点数据
    private func createCubeVertices() -> [ModelVertex] {
        return [
            // 前面 (Z+)
            ModelVertex(position: Float3(-0.5, -0.5,  0.5), normal: Float3(0, 0, 1), texCoords: Float2(0, 0)),
            ModelVertex(position: Float3( 0.5, -0.5,  0.5), normal: Float3(0, 0, 1), texCoords: Float2(1, 0)),
            ModelVertex(position: Float3( 0.5,  0.5,  0.5), normal: Float3(0, 0, 1), texCoords: Float2(1, 1)),
            ModelVertex(position: Float3(-0.5,  0.5,  0.5), normal: Float3(0, 0, 1), texCoords: Float2(0, 1)),
            
            // 后面 (Z-)
            ModelVertex(position: Float3(-0.5, -0.5, -0.5), normal: Float3(0, 0, -1), texCoords: Float2(1, 0)),
            ModelVertex(position: Float3(-0.5,  0.5, -0.5), normal: Float3(0, 0, -1), texCoords: Float2(1, 1)),
            ModelVertex(position: Float3( 0.5,  0.5, -0.5), normal: Float3(0, 0, -1), texCoords: Float2(0, 1)),
            ModelVertex(position: Float3( 0.5, -0.5, -0.5), normal: Float3(0, 0, -1), texCoords: Float2(0, 0)),
            
            // 左面 (X-)
            ModelVertex(position: Float3(-0.5, -0.5, -0.5), normal: Float3(-1, 0, 0), texCoords: Float2(0, 0)),
            ModelVertex(position: Float3(-0.5, -0.5,  0.5), normal: Float3(-1, 0, 0), texCoords: Float2(1, 0)),
            ModelVertex(position: Float3(-0.5,  0.5,  0.5), normal: Float3(-1, 0, 0), texCoords: Float2(1, 1)),
            ModelVertex(position: Float3(-0.5,  0.5, -0.5), normal: Float3(-1, 0, 0), texCoords: Float2(0, 1)),
            
            // 右面 (X+)
            ModelVertex(position: Float3( 0.5, -0.5, -0.5), normal: Float3(1, 0, 0), texCoords: Float2(1, 0)),
            ModelVertex(position: Float3( 0.5,  0.5, -0.5), normal: Float3(1, 0, 0), texCoords: Float2(1, 1)),
            ModelVertex(position: Float3( 0.5,  0.5,  0.5), normal: Float3(1, 0, 0), texCoords: Float2(0, 1)),
            ModelVertex(position: Float3( 0.5, -0.5,  0.5), normal: Float3(1, 0, 0), texCoords: Float2(0, 0)),
            
            // 上面 (Y+)
            ModelVertex(position: Float3(-0.5,  0.5, -0.5), normal: Float3(0, 1, 0), texCoords: Float2(0, 1)),
            ModelVertex(position: Float3(-0.5,  0.5,  0.5), normal: Float3(0, 1, 0), texCoords: Float2(0, 0)),
            ModelVertex(position: Float3( 0.5,  0.5,  0.5), normal: Float3(0, 1, 0), texCoords: Float2(1, 0)),
            ModelVertex(position: Float3( 0.5,  0.5, -0.5), normal: Float3(0, 1, 0), texCoords: Float2(1, 1)),
            
            // 下面 (Y-)
            ModelVertex(position: Float3(-0.5, -0.5, -0.5), normal: Float3(0, -1, 0), texCoords: Float2(0, 0)),
            ModelVertex(position: Float3( 0.5, -0.5, -0.5), normal: Float3(0, -1, 0), texCoords: Float2(1, 0)),
            ModelVertex(position: Float3( 0.5, -0.5,  0.5), normal: Float3(0, -1, 0), texCoords: Float2(1, 1)),
            ModelVertex(position: Float3(-0.5, -0.5,  0.5), normal: Float3(0, -1, 0), texCoords: Float2(0, 1))
        ]
    }
    
    /// 创建立方体索引数据
    private func createCubeIndices() -> [UInt32] {
        return [
            // 前面
            0, 1, 2,  0, 2, 3,
            // 后面
            4, 5, 6,  4, 6, 7,
            // 左面
            8, 9, 10,  8, 10, 11,
            // 右面
            12, 13, 14,  12, 14, 15,
            // 上面
            16, 17, 18,  16, 18, 19,
            // 下面
            20, 21, 22,  20, 22, 23
        ]
    }
}


