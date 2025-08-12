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

    // MARK: - 最近一次外部OBJ解析记录 (用于运行时调试)
    private(set) var lastResolvedOBJPath: String? = nil            // 解析成功的绝对/相对路径
    private(set) var lastResolvedOBJFileName: String? = nil        // 实际使用的文件名
    private(set) var lastResolvedOBJResolutionStage: String? = nil // 解析阶段标记
    private(set) var lastTriedOBJPaths: [String] = []              // 未成功前尝试的候选路径集合

    /// 当前模型版本（只读访问器，供外部查询显示哪一个模型在使用）
    var currentVersion: ModelVersion { currentModelVersion }
    
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
            // 记录当前顶点与索引起点
            let vertexStart = UInt32(allVertices.count)
            let indexStart = allIndices.count // 以索引为单位的偏移（真正用于 indexBufferOffset）

            allVertices.append(contentsOf: component.vertices)

            // 调整索引偏移到全局顶点空间
            let adjustedIndices = component.indices.map { $0 + vertexStart }
            allIndices.append(contentsOf: adjustedIndices)

            // 创建渲染命令（现在 startIndex 代表索引缓冲区中的起始索引，而不是顶点起始位置）
            renderCommands.append(RenderCommand(
                startIndex: indexStart,
                indexCount: component.indices.count,
                materialId: component.materialId
            ))

            // 创建材质数据（若已存在则不覆盖，避免重复分配）
            if materials[component.materialId] == nil {
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

            #if DEBUG
            print("🧩 RenderCommand 生成: material=\(component.materialId) vertexStart=\(vertexStart) indexStart=\(indexStart) indexCount=\(component.indices.count)")
            #endif
        }
        
        // 处理空模型：如果没有任何顶点（外部OBJ缺失时可能发生）
        if allVertices.isEmpty || allIndices.isEmpty {
            print("⚠️ createMetalData: 模型为空，创建占位缓冲区以避免崩溃")
            var dummyVertex = Vertex(
                position: SIMD3<Float>(0,0,0),
                normal: SIMD3<Float>(0,1,0),
                texCoords: SIMD2<Float>(0,0),
                color: SIMD4<Float>(1,1,1,1),
                tangent: SIMD3<Float>(1,0,0)
            )
            var dummyIndex: UInt32 = 0
            guard let vbuf = device.makeBuffer(bytes: &dummyVertex, length: MemoryLayout<Vertex>.stride, options: []),
                  let ibuf = device.makeBuffer(bytes: &dummyIndex, length: MemoryLayout<UInt32>.size, options: []) else {
                throw PlayerModelError.metalBufferCreationFailed
            }
            return MetalModelData(
                vertexBuffer: vbuf,
                indexBuffer: ibuf,
                indexCount: 0,
                materials: materials,
                renderCommands: []
            )
        }

        // 创建缓冲区（非空）
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
        print("🎨 加载外部玩家OBJ模型 (ShowGames 模式)...")

        // 支持的候选文件名（按优先级）
    // 新增新版资源文件优先级: PlayerModel2.obj > PlayerModel.obj > player_geometric_warrior_v1.obj
        let candidateNames = [
            "PlayerModel2.obj", "playerModel2.obj", // 新模型大小写两种
            "PlayerModel.obj", "playerModel.obj",   // 旧模型大小写两种
            "player_geometric_warrior_v1.obj"
        ]
    var triedPaths: [String] = []
    var foundPath: String? = nil
    var chosenFileName: String = "PlayerModel.obj"
    var resolutionStage: String? = nil

    print("🗂️ 外部OBJ候选列表: PlayerModel2.obj / PlayerModel.obj / player_geometric_warrior_v1.obj (按此优先级)")
    // 在Bundle中查找（记录Bundle资源根路径）
        if let bundleResPath = Bundle.main.resourcePath {
            print("🔎 Bundle resourcePath = \(bundleResPath)")
        } else {
            print("⚠️ 无法获取 Bundle.resourcePath")
        }
        
        // 在Bundle中查找
        for name in candidateNames {
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            if let p = Bundle.main.path(forResource: base, ofType: ext, inDirectory: "Assets/Models/Player") {
                foundPath = p
                chosenFileName = name
                resolutionStage = "Bundle:Assets/Models/Player"
                break
            }
            triedPaths.append("Bundle:Assets/Models/Player/\(name)")
        }

        // 运行目录相对路径
        if foundPath == nil {
            for name in candidateNames {
                let p = "Assets/Models/Player/\(name)"
                if FileManager.default.fileExists(atPath: p) {
                    foundPath = p; chosenFileName = name; resolutionStage = ". /Assets/Models/Player"; break
                }
                triedPaths.append(p)
            }
        }

        // 上层目录尝试
        if foundPath == nil {
            for name in candidateNames {
                let p = "../Assets/Models/Player/\(name)"
                if FileManager.default.fileExists(atPath: p) {
                    foundPath = p; chosenFileName = name; resolutionStage = "../Assets/Models/Player"; break
                }
                triedPaths.append(p)
            }
        }

        // 向上多层目录递归查找（解决未加入Xcode资源包的本地运行情况）
        if foundPath == nil {
            let fm = FileManager.default
            // 取当前可执行所在目录，逐级向上（最多6级）寻找包含 Assets/Models/Player/<name> 的路径
            let exeDir = (Bundle.main.executablePath as NSString?)?.deletingLastPathComponent ?? FileManager.default.currentDirectoryPath
            var current = URL(fileURLWithPath: exeDir)
            searchLoop: for _ in 0..<6 {
                for name in candidateNames {
                    let candidate = current.appendingPathComponent("Assets/Models/Player/\(name)").path
                    if fm.fileExists(atPath: candidate) {
                        foundPath = candidate
                        chosenFileName = name
                        print("🔍 祖先目录匹配到OBJ: \(candidate)")
                        resolutionStage = "AncestorSearch"
                        break searchLoop
                    }
                }
                current.deleteLastPathComponent()
            }
        }

        // 环境变量直接指定 (最高优先级手动覆盖)
        if foundPath == nil {
            if let overridePath = ProcessInfo.processInfo.environment["PLAYER_MODEL_PATH"], !overridePath.isEmpty {
                if FileManager.default.fileExists(atPath: overridePath) {
                    foundPath = overridePath
                    chosenFileName = (overridePath as NSString).lastPathComponent
                    print("🌐 使用环境变量 PLAYER_MODEL_PATH 指定模型: \(overridePath)")
                    resolutionStage = "Env:PLAYER_MODEL_PATH"
                } else {
                    print("⚠️ PLAYER_MODEL_PATH 指定的文件不存在: \(overridePath)")
                }
            }
        }

        // 利用源文件物理路径(#file) 反推源码根目录再查找 (适合从 DerivedData 可执行启动)
        if foundPath == nil {
            let fm = FileManager.default
            let thisFile = URL(fileURLWithPath: #file) // 源文件的真实路径(非复制资源)
            var cursor = thisFile.deletingLastPathComponent()
            // 向上最多 10 层找含有 Assets/Models/Player 的根
            for _ in 0..<10 {
                let assetsDir = cursor.appendingPathComponent("Assets/Models/Player")
                if fm.fileExists(atPath: assetsDir.path) {
                    for name in candidateNames {
                        let candidate = assetsDir.appendingPathComponent(name).path
                        if fm.fileExists(atPath: candidate) {
                            foundPath = candidate
                            chosenFileName = name
                            print("🧭 #file 源路径回溯匹配OBJ: \(candidate)")
                            resolutionStage = "#fileBacktrack"
                            break
                        }
                    }
                    if foundPath != nil { break }
                }
                cursor.deleteLastPathComponent()
            }
        }

        // 最终兜底：在 Bundle 根 (resourcePath) 递归大小写不敏感搜索（允许用户直接把 playermodel2.obj 放在 Resources 根）
        if foundPath == nil {
            if let resRoot = Bundle.main.resourcePath {
                let fm = FileManager.default
                if let enumerator = fm.enumerator(at: URL(fileURLWithPath: resRoot), includingPropertiesForKeys: nil) {
                    let targetSet = Set(candidateNames.map { $0.lowercased() })
                    for case let fileURL as URL in enumerator {
                        let name = fileURL.lastPathComponent.lowercased()
                        if targetSet.contains(name) && fileURL.pathExtension.lowercased() == "obj" {
                            foundPath = fileURL.path
                            chosenFileName = fileURL.lastPathComponent
                            print("🕵️ Bundle根递归匹配(大小写不敏感) OBJ: \(fileURL.path)")
                            resolutionStage = "BundleRecursiveRoot"
                            break
                        }
                    }
                }
            }
        }

        if foundPath == nil {
            // 额外：遍历列出实际存在的 Player 目录内容（若有）
            let candidateDirs = [
                "Assets/Models/Player",
                "../Assets/Models/Player",
                Bundle.main.resourcePath.map { "\($0)/Assets/Models/Player" } ?? ""
            ]
            for dir in candidateDirs.compactMap({ $0 }).filter({ !$0.isEmpty }) {
                if FileManager.default.fileExists(atPath: dir) {
                    if let items = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                        print("📂 列出目录 \(dir): \(items)")
                    } else {
                        print("📂 目录存在但无法列出: \(dir)")
                    }
                } else {
                    print("📁 目录不存在: \(dir)")
                }
            }
            print("⚠️ 未找到 PlayerModel2.obj，极可能未被添加到 Xcode 目标的资源复制阶段。解决: 将 Assets/Models/Player 文件夹拖入 Xcode (选择 'Create folder references' 或确保 target 勾选) 再次构建。")
        }
        
    // 记录调试信息（即使失败也记录尝试路径）
    self.lastTriedOBJPaths = triedPaths
    self.lastResolvedOBJPath = foundPath
    self.lastResolvedOBJFileName = foundPath == nil ? nil : chosenFileName
    self.lastResolvedOBJResolutionStage = resolutionStage ?? (foundPath == nil ? "NOT_FOUND" : "UNKNOWN")

    guard let objPath = foundPath else {
            print("❌ 未找到任何玩家OBJ文件，尝试路径: \(triedPaths)")
            print("⚠️ 回退到程序生成模型 (generated) 以便仍可看到玩家。请添加 PlayerModel.obj 到 Assets/Models/Player/ 目录。")
            return loadGeneratedModel()
        }

        print("📂 选定OBJ文件: \(chosenFileName) -> 路径: \(objPath)")
        let displayName = (chosenFileName as NSString).deletingPathExtension
        if let model = OBJParser.parseOBJ(atPath: objPath, modelName: displayName) {
            print("✅ 外部OBJ模型加载成功: 文件=\(chosenFileName) 顶点=\(model.totalVertices) 组件=\(model.components.count)")
            return model
        } else {
            print("❌ 解析失败: \(chosenFileName). 保留空模型以突出问题 (不回退 generated)")
            return PlayerModel(name: "FailedParse_\(displayName)", components: [])
        }
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

    /// 返回最近一次外部OBJ解析调试信息（单行）
    func debugExternalOBJResolutionInfo() -> String {
        var parts: [String] = []
        if let p = lastResolvedOBJPath {
            parts.append("path=\(p)")
        } else {
            parts.append("path=<not_found>")
        }
        if let f = lastResolvedOBJFileName { parts.append("file=\(f)") }
        if let stage = lastResolvedOBJResolutionStage { parts.append("stage=\(stage)") }
        if lastResolvedOBJPath == nil {
            parts.append("tried=\(lastTriedOBJPaths.joined(separator: ","))")
        }
        return parts.joined(separator: " | ")
    }
}
