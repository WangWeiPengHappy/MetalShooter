//
//  Material.swift
//  MetalShooter
//
//  Phase 3: PBR材质系统实现
//  基于物理的渲染材质管理
//

import Metal
import simd

/// PBR材质类 - 管理物理基于渲染的材质属性
public class Material {
    
    // MARK: - 标识
    
    /// 材质唯一标识符
    public let id = UUID()
    
    // MARK: - 属性
    
    /// 反照率颜色 (Albedo Color)
    public var albedo: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    
    /// 金属度 (Metallic) - 0.0为非金属，1.0为完全金属
    public var metallic: Float = 0.0
    
    /// 粗糙度 (Roughness) - 0.0为完全光滑，1.0为完全粗糙
    public var roughness: Float = 0.5
    
    /// 环境光遮蔽 (Ambient Occlusion)
    public var ao: Float = 1.0
    
    /// 自发光强度 (Emission)
    public var emission: Float = 0.0
    
    /// 法线强度 (Normal Strength)
    public var normalStrength: Float = 1.0
    
    // MARK: - 纹理属性
    
    /// 反照率纹理
    public var albedoTexture: MTLTexture?
    
    /// 法线贴图
    public var normalTexture: MTLTexture?
    
    /// 金属度纹理
    public var metallicTexture: MTLTexture?
    
    /// 粗糙度纹理
    public var roughnessTexture: MTLTexture?
    
    /// 环境光遮蔽纹理
    public var aoTexture: MTLTexture?
    
    /// 自发光纹理
    public var emissionTexture: MTLTexture?
    
    // MARK: - 纹理管理
    
    /// 纹理槽枚举
    public enum TextureSlot {
        case albedo
        case normal
        case metallicRoughness
        case ambientOcclusion
        case emissive
    }
    
    /// 纹理字典 - 按槽位管理纹理
    public var textures: [TextureSlot: MTLTexture] = [:]
    
    // MARK: - 初始化
    
    /// 默认初始化
    public init() {
        setupDefaultMaterial()
    }
    
    /// 使用预设材质初始化
    public init(preset: MaterialPreset) {
        setupMaterialPreset(preset)
    }
    
    /// 使用自定义参数初始化
    public init(albedo: SIMD4<Float>, metallic: Float, roughness: Float, ao: Float = 1.0, emission: Float = 0.0) {
        self.albedo = albedo
        self.metallic = metallic
        self.roughness = roughness
        self.ao = ao
        self.emission = emission
    }
    
    // MARK: - 配置方法
    
    /// 设置默认材质属性
    private func setupDefaultMaterial() {
        albedo = SIMD4<Float>(0.8, 0.8, 0.8, 1.0) // 中性灰色
        metallic = 0.0  // 非金属
        roughness = 0.5 // 中等粗糙度
        ao = 1.0        // 无遮蔽
        emission = 0.0  // 无自发光
        normalStrength = 1.0
    }
    
    /// 设置材质预设
    private func setupMaterialPreset(_ preset: MaterialPreset) {
        switch preset {
        case .default:
            setupDefaultMaterial()
        case .plastic:
            setupPlasticMaterial()
        case .metal:
            setupMetalMaterial()
        case .gold:
            setupGoldMaterial()
        case .silver:
            setupSilverMaterial()
        case .copper:
            setupCopperMaterial()
        case .rubber:
            setupRubberMaterial()
        case .ceramic:
            setupCeramicMaterial()
        case .wood:
            setupWoodMaterial()
        }
    }
    
    // MARK: - 预设材质配置
    
    private func setupPlasticMaterial() {
        albedo = SIMD4<Float>(0.2, 0.6, 0.9, 1.0)
        metallic = 0.0
        roughness = 0.3
        ao = 1.0
        emission = 0.0
    }
    
    private func setupMetalMaterial() {
        albedo = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
        metallic = 1.0
        roughness = 0.1
        ao = 1.0
        emission = 0.0
    }
    
    private func setupGoldMaterial() {
        albedo = SIMD4<Float>(1.0, 0.766, 0.336, 1.0)
        metallic = 1.0
        roughness = 0.05
        ao = 1.0
        emission = 0.0
    }
    
    private func setupSilverMaterial() {
        albedo = SIMD4<Float>(0.972, 0.960, 0.915, 1.0)
        metallic = 1.0
        roughness = 0.02
        ao = 1.0
        emission = 0.0
    }
    
    private func setupCopperMaterial() {
        albedo = SIMD4<Float>(0.955, 0.637, 0.538, 1.0)
        metallic = 1.0
        roughness = 0.1
        ao = 1.0
        emission = 0.0
    }
    
    private func setupRubberMaterial() {
        albedo = SIMD4<Float>(0.1, 0.1, 0.1, 1.0)
        metallic = 0.0
        roughness = 0.9
        ao = 1.0
        emission = 0.0
    }
    
    private func setupCeramicMaterial() {
        albedo = SIMD4<Float>(0.95, 0.93, 0.88, 1.0)
        metallic = 0.0
        roughness = 0.1
        ao = 1.0
        emission = 0.0
    }
    
    private func setupWoodMaterial() {
        albedo = SIMD4<Float>(0.6, 0.4, 0.2, 1.0)
        metallic = 0.0
        roughness = 0.7
        ao = 1.0
        emission = 0.0
    }
    
    // MARK: - 纹理管理
    
    /// 设置反照率纹理
    public func setAlbedoTexture(_ texture: MTLTexture?) {
        self.albedoTexture = texture
    }
    
    /// 设置法线纹理
    public func setNormalTexture(_ texture: MTLTexture?, strength: Float = 1.0) {
        self.normalTexture = texture
        self.normalStrength = strength
    }
    
    /// 设置金属度纹理
    public func setMetallicTexture(_ texture: MTLTexture?) {
        self.metallicTexture = texture
    }
    
    /// 设置粗糙度纹理
    public func setRoughnessTexture(_ texture: MTLTexture?) {
        self.roughnessTexture = texture
    }
    
    /// 设置AO纹理
    public func setAOTexture(_ texture: MTLTexture?) {
        self.aoTexture = texture
    }
    
    /// 设置自发光纹理
    public func setEmissionTexture(_ texture: MTLTexture?) {
        self.emissionTexture = texture
    }
    
    // MARK: - Metal缓冲区支持
    
    /// 获取材质数据用于Metal缓冲区
    public func getMaterialData() -> MaterialData {
        return MaterialData(
            albedo: albedo,
            metallic: metallic,
            roughness: roughness,
            ao: ao,
            emission: emission,
            normalStrength: normalStrength,
            padding1: 0.0,
            padding2: 0.0
        )
    }
    
    /// 检查是否有任何纹理
    public var hasTextures: Bool {
        return albedoTexture != nil || normalTexture != nil || 
               metallicTexture != nil || roughnessTexture != nil || 
               aoTexture != nil || emissionTexture != nil
    }
    
    /// 获取所有非空纹理
    public func getActiveTextures() -> [String: MTLTexture] {
        var textures: [String: MTLTexture] = [:]
        
        if let albedo = albedoTexture {
            textures["albedo"] = albedo
        }
        if let normal = normalTexture {
            textures["normal"] = normal
        }
        if let metallic = metallicTexture {
            textures["metallic"] = metallic
        }
        if let roughness = roughnessTexture {
            textures["roughness"] = roughness
        }
        if let ao = aoTexture {
            textures["ao"] = ao
        }
        if let emission = emissionTexture {
            textures["emission"] = emission
        }
        
        return textures
    }
    
    // MARK: - 调试支持
    
    public func debugDescription() -> String {
        return """
        Material {
            Albedo: (\(albedo.x), \(albedo.y), \(albedo.z), \(albedo.w))
            Metallic: \(metallic)
            Roughness: \(roughness)
            AO: \(ao)
            Emission: \(emission)
            Normal Strength: \(normalStrength)
            Textures: \(hasTextures ? "Yes" : "No")
        }
        """
    }
}

// MARK: - 支持类型和枚举

/// 材质预设枚举
public enum MaterialPreset: CaseIterable {
    case `default`
    case plastic
    case metal
    case gold
    case silver
    case copper
    case rubber
    case ceramic
    case wood
    
    var displayName: String {
        switch self {
        case .default: return "默认"
        case .plastic: return "塑料"
        case .metal: return "金属"
        case .gold: return "黄金"
        case .silver: return "银"
        case .copper: return "铜"
        case .rubber: return "橡胶"
        case .ceramic: return "陶瓷"
        case .wood: return "木材"
        }
    }
}

/// Metal缓冲区材质数据结构 (与ShaderTypes.h中的Material对应)
public struct MaterialData {
    let albedo: SIMD4<Float>     // 反照率颜色
    let metallic: Float          // 金属度
    let roughness: Float         // 粗糙度
    let ao: Float                // 环境光遮蔽
    let emission: Float          // 自发光强度
    let normalStrength: Float    // 法线强度
    let padding1: Float          // 内存对齐填充
    let padding2: Float          // 内存对齐填充
}
