import Foundation
import Metal
import simd

/// 玩家模型加载错误
enum PlayerModelError: Error {
    case metalBufferCreationFailed
    case modelNotFound
    case invalidModelData
    case materialNotFound
}

/// 玩家模型加载器 - 管理玩家3D模型的加载和缓存
class PlayerModelLoader {
    
    // MARK: - 单例
    static let shared = PlayerModelLoader()
    
    // MARK: - 缓存
    private var modelCache: [String: PlayerModel] = [:]
    private var metalDataCache: [String: MetalModelData] = [:]
    
    // MARK: - 配置
    private var currentModelVersion: ModelVersion = .generated
    
    enum ModelVersion {
        case generated      // Swift程序化生成
        case blenderMCP     // Blender MCP生成
        case professional  // 专业建模师作品
        
        var identifier: String {
            switch self {
            case .generated: return "geometric_warrior_v1"
            case .blenderMCP: return "geometric_warrior_v2"
            case .professional: return "geometric_warrior_v3"
            }
        }
    }
    
    private init() {
        print("🏗️ PlayerModelLoader 初始化")
    }
    
    // MARK: - 公共接口
    
    /// 加载当前版本的玩家模型
    func loadCurrentPlayerModel() -> PlayerModel {
        let identifier = currentModelVersion.identifier
        
        if let cachedModel = modelCache[identifier] {
            print("📦 从缓存加载玩家模型: \(identifier)")
            return cachedModel
        }
        
        let model = loadModelForVersion(currentModelVersion)
        modelCache[identifier] = model
        print("✨ 新加载玩家模型: \(identifier)")
        
        return model
    }
    
    /// 为Metal渲染加载玩家模型数据
    func loadCurrentPlayerModelForMetal(device: MTLDevice) throws -> MetalModelData {
        let identifier = currentModelVersion.identifier
        
        if let cachedData = metalDataCache[identifier] {
            print("📦 从缓存加载Metal模型数据: \(identifier)")
            return cachedData
        }
        
        let model = loadCurrentPlayerModel()
        let metalData = try createMetalData(from: model, device: device)
        metalDataCache[identifier] = metalData
        print("✨ 新创建Metal模型数据: \(identifier)")
        
        return metalData
    }
    
    /// 创建Metal数据
    private func createMetalData(from model: PlayerModel, device: MTLDevice) throws -> MetalModelData {
        // 收集所有顶点和索引
        var allVertices: [Vertex] = []
        var allIndices: [UInt32] = []
        var renderCommands: [RenderCommand] = []
        var materials: [String: MaterialData] = [:]
        
        for component in model.components {
            let startIndex = UInt32(allVertices.count)
            allVertices.append(contentsOf: component.vertices)
            
            // 调整索引偏移
            let adjustedIndices = component.indices.map { $0 + startIndex }
            allIndices.append(contentsOf: adjustedIndices)
            
            // 创建渲染命令
            renderCommands.append(RenderCommand(
                startIndex: Int(startIndex),
                indexCount: component.indices.count,
                materialId: component.materialId
            ))
            
            // 创建材质数据
            materials[component.materialId] = MaterialData(
                albedo: simd_float4(0.7, 0.7, 0.7, 1.0),
                metallic: 0.1,
                roughness: 0.8,
                ao: 1.0,
                emission: 0.0,
                normalStrength: 1.0,
                padding1: 0.0,
                padding2: 0.0
            )
        }
        
        // 创建缓冲区
        guard let vertexBuffer = device.makeBuffer(bytes: allVertices, length: MemoryLayout<Vertex>.stride * allVertices.count, options: []) else {
            throw PlayerModelError.metalBufferCreationFailed
        }
        
        guard let indexBuffer = device.makeBuffer(bytes: allIndices, length: MemoryLayout<UInt32>.size * allIndices.count, options: []) else {
            throw PlayerModelError.metalBufferCreationFailed
        }
        
        return MetalModelData(
            vertexBuffer: vertexBuffer,
            indexBuffer: indexBuffer,
            indexCount: allIndices.count,
            materials: materials,
            renderCommands: renderCommands
        )
    }
    
    /// 切换模型版本
    func switchToVersion(_ version: ModelVersion) {
        print("🔄 切换玩家模型版本: \(currentModelVersion.identifier) -> \(version.identifier)")
        currentModelVersion = version
    }
    
    /// 预加载所有版本
    func preloadAllVersions(device: MTLDevice) {
        print("🚀 预加载所有玩家模型版本...")
        
        for version in [ModelVersion.generated, .blenderMCP, .professional] {
            let oldVersion = currentModelVersion
            currentModelVersion = version
            
            do {
                let _ = try loadCurrentPlayerModelForMetal(device: device)
                print("✅ 预加载成功: \(version.identifier)")
            } catch {
                print("❌ 预加载失败: \(version.identifier) - \(error)")
            }
            
            currentModelVersion = oldVersion
        }
        
        print("🎉 预加载完成")
    }
    
    /// 清除缓存
    func clearCache() {
        modelCache.removeAll()
        metalDataCache.removeAll()
        print("🧹 PlayerModelLoader 缓存已清除")
    }
    
    /// 获取模型统计信息
    func getModelStatistics() -> (vertexCount: Int, triangleCount: Int, componentCount: Int)? {
        let model = loadCurrentPlayerModel()
        let vertexCount = model.components.map { $0.vertices.count }.reduce(0, +)
        let triangleCount = model.components.map { $0.indices.count / 3 }.reduce(0, +)
        return (vertexCount: vertexCount, triangleCount: triangleCount, componentCount: model.components.count)
    }
    
    // MARK: - 私有方法
    
    /// 根据版本加载模型
    private func loadModelForVersion(_ version: ModelVersion) -> PlayerModel {
        switch version {
        case .generated:
            return loadGeneratedModel()
        case .blenderMCP:
            return loadBlenderMCPModel()
        case .professional:
            return loadProfessionalModel()
        }
    }
    
    /// 加载程序生成的模型
    private func loadGeneratedModel() -> PlayerModel {
        print("🔨 加载程序生成的几何战士模型...")
        return GeometricWarriorGenerator.generateModel()
    }
    
    /// 加载Blender MCP生成的模型
    private func loadBlenderMCPModel() -> PlayerModel {
        print("🎨 加载Blender MCP生成的模型...")
        // 目前回退到程序生成版本
        print("⚠️ Blender MCP版本尚未实现，使用程序生成版本")
        return loadGeneratedModel()
    }
    
    /// 加载专业建模师制作的模型
    private func loadProfessionalModel() -> PlayerModel {
        print("💎 加载专业建模师模型...")
        // 目前回退到程序生成版本
        print("⚠️ 专业版本尚未实现，使用程序生成版本")
        return loadGeneratedModel()
    }
}

// MARK: - MetalRenderer集成扩展
extension PlayerModelLoader {
    
    /// 便捷方法：直接为MetalRenderer创建几何战士
    static func createGeometricWarriorForRenderer(device: MTLDevice) throws -> MetalModelData {
        let loader = PlayerModelLoader()
        loader.switchToVersion(.generated)
        return try loader.loadCurrentPlayerModelForMetal(device: device)
    }
    
    /// 便捷方法：获取模型规格（用于调试）
    static func getGeometricWarriorSpecs() -> (vertexCount: Int, faceCount: Int, componentCount: Int) {
        let model = GeometricWarriorGenerator.generateModel()
        let vertexCount = model.components.map { $0.vertices.count }.reduce(0, +)
        let faceCount = model.components.map { $0.indices.count / 3 }.reduce(0, +)
        return (vertexCount: vertexCount, faceCount: faceCount, componentCount: model.components.count)
    }
}

// MARK: - 调试和测试支持
extension PlayerModelLoader {
    
    /// 打印当前加载的模型信息
    func printCurrentModelInfo() {
        let model = loadCurrentPlayerModel()
        let vertexCount = model.components.map { $0.vertices.count }.reduce(0, +)
        let triangleCount = model.components.map { $0.indices.count / 3 }.reduce(0, +)
        let memoryEstimate = vertexCount * MemoryLayout<Vertex>.size + triangleCount * 3 * MemoryLayout<UInt32>.size
        
        print("📋 当前玩家模型信息:")
        print("   版本: \(currentModelVersion.identifier)")
        print("   名称: \(model.name)")
        print("   组件数量: \(model.components.count)")
        print("   顶点总数: \(vertexCount)")
        print("   三角形总数: \(triangleCount)")
        print("   材质数量: \(Set(model.components.map { $0.materialId }).count)")
        print("   边界框: min=\(model.boundingBox.min) max=\(model.boundingBox.max)")
        print("   预估内存: \(memoryEstimate) 字节")
    }
    
    /// 验证模型数据完整性
    func validateCurrentModel() -> Bool {
        let model = loadCurrentPlayerModel()
        
        // 基本验证
        guard !model.components.isEmpty else {
            print("❌ 模型验证失败：无组件")
            return false
        }
        
        // 收集所有使用的材质ID
        let usedMaterialIds = Set(model.components.map { $0.materialId })
        guard !usedMaterialIds.isEmpty else {
            print("❌ 模型验证失败：无材质")
            return false
        }
        
        // 验证每个组件
        for component in model.components {
            guard !component.vertices.isEmpty else {
                print("❌ 模型验证失败：组件 \(component.name) 无顶点")
                return false
            }
            
            guard !component.indices.isEmpty else {
                print("❌ 模型验证失败：组件 \(component.name) 无索引")
                return false
            }
            
            // 检查材质ID格式
            guard !component.materialId.isEmpty else {
                print("❌ 模型验证失败：组件 \(component.name) 材质ID为空")
                return false
            }
        }
        
        print("✅ 模型验证通过")
        return true
    }
    
    /// 生成OBJ文件用于外部查看
    func exportCurrentModelToOBJ(filePath: String) throws {
        let model = loadCurrentPlayerModel()
        let objContent = generateOBJContent(model: model)
        
        try objContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("📁 模型已导出到: \(filePath)")
    }
    
    private func generateOBJContent(model: PlayerModel) -> String {
        var content = "# Generated by MetalShooter PlayerModelLoader\n"
        content += "# Model: \(model.name)\n"
        content += "# Created: \(model.createdAt)\n\n"
        
        var vertexIndex = 1
        
        for component in model.components {
            content += "# Component: \(component.name)\n"
            content += "g \(component.name)\n"
            
            // 写入顶点
            for vertex in component.vertices {
                content += "v \(vertex.position.x) \(vertex.position.y) \(vertex.position.z)\n"
            }
            
            // 写入纹理坐标
            for vertex in component.vertices {
                content += "vt \(vertex.texCoords.x) \(vertex.texCoords.y)\n"
            }
            
            // 写入法线
            for vertex in component.vertices {
                content += "vn \(vertex.normal.x) \(vertex.normal.y) \(vertex.normal.z)\n"
            }
            
            // 写入面
            for i in stride(from: 0, to: component.indices.count, by: 3) {
                let i1 = Int(component.indices[i]) + vertexIndex
                let i2 = Int(component.indices[i + 1]) + vertexIndex
                let i3 = Int(component.indices[i + 2]) + vertexIndex
                content += "f \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2) \(i3)/\(i3)/\(i3)\n"
            }
            
            vertexIndex += component.vertices.count
            content += "\n"
        }
        
        return content
    }
}
