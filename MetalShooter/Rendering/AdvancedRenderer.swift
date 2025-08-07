//
//  AdvancedRenderer.swift
//  MetalShooter
//
//  Phase 3: 高级渲染器
//  集成PBR材质、动态光照和阴影映射
//

import Metal
import MetalKit
import simd
import os

// MARK: - 高级渲染器

/// 高级渲染器 - 集成所有Phase 3渲染特性
public class AdvancedRenderer {
    
    // MARK: - 属性
    
    private let device: MTLDevice
    private let logger = Logger(subsystem: "MetalShooter", category: "AdvancedRenderer")
    
    /// 基础渲染器
    private weak var baseRenderer: MetalRenderer?
    
    /// 材质管理器
    public let materialManager: MaterialManager
    
    /// 纹理管理器
    public let textureManager: TextureManager
    
    /// 光照系统
    public let lightingSystem: LightingSystem
    
    /// 阴影映射器
    public let shadowMapper: ShadowMapper
    
    /// PBR渲染管线状态
    private var pbrRenderPipelineState: MTLRenderPipelineState?
    
    /// 深度模板状态
    private var depthStencilState: MTLDepthStencilState?
    
    /// 采样器状态
    private var textureSampler: MTLSamplerState?
    private var shadowSampler: MTLSamplerState?
    
    /// 当前帧的光照数据
    private var currentLightingData = LightingData()
    
    /// 渲染统计信息
    public private(set) var renderStats = RenderStatistics()
    
    // MARK: - 渲染统计
    
    public struct RenderStatistics {
        var drawCalls: Int = 0
        var triangles: Int = 0
        var materialSwitches: Int = 0
        var textureSwitches: Int = 0
        var shadowMapRenders: Int = 0
        var lastFrameTime: Double = 0.0
        var averageFrameTime: Double = 0.0
        
        mutating func reset() {
            drawCalls = 0
            triangles = 0
            materialSwitches = 0
            textureSwitches = 0
            shadowMapRenders = 0
        }
        
        mutating func updateFrameTime(_ time: Double) {
            lastFrameTime = time
            averageFrameTime = (averageFrameTime * 0.9) + (time * 0.1)
        }
    }
    
    // MARK: - 初始化
    
    public init(device: MTLDevice, baseRenderer: MetalRenderer) {
        self.device = device
        self.baseRenderer = baseRenderer
        
        // 初始化管理器
        self.materialManager = MaterialManager(device: device)
        self.textureManager = TextureManager.shared
        self.lightingSystem = LightingSystem.shared
        self.shadowMapper = ShadowMapper(device: device)
        
        setupAdvancedRendering()
    }
    
    deinit {
        logger.info("AdvancedRenderer deinitialized")
    }
    
    // MARK: - 设置
    
    private func setupAdvancedRendering() {
        createRenderPipelineStates()
        createDepthStencilState()
        createSamplerStates()
        setupDefaultLighting()
        
        logger.info("Advanced rendering system initialized")
    }
    
    private func createRenderPipelineStates() {
        guard let library = device.makeDefaultLibrary() else {
            logger.error("Failed to create shader library")
            return
        }
        
        // 创建顶点描述符
        let vertexDescriptor = MTLVertexDescriptor()
        
        // 位置属性 (Float3)
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // 法线属性 (Float3)
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float3>.size
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // 纹理坐标属性 (Float2)
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float3>.size * 2
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        // 颜色属性 (Float4)
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float3>.size * 2 + MemoryLayout<Float2>.size
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        // 切线属性 (Float3) - Phase 3 PBR支持
        vertexDescriptor.attributes[4].format = .float3
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float3>.size * 2 + MemoryLayout<Float2>.size + MemoryLayout<Float4>.size
        vertexDescriptor.attributes[4].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.size
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // 创建PBR渲染管线
        let pbrDescriptor = MTLRenderPipelineDescriptor()
        pbrDescriptor.label = "PBR Render Pipeline"
        pbrDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        pbrDescriptor.fragmentFunction = library.makeFunction(name: "fragment_pbr")
        pbrDescriptor.vertexDescriptor = vertexDescriptor
        
        // 设置颜色附件
        pbrDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pbrDescriptor.colorAttachments[0].isBlendingEnabled = true
        pbrDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pbrDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pbrDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pbrDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pbrDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pbrDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        // 设置深度附件
        pbrDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            pbrRenderPipelineState = try device.makeRenderPipelineState(descriptor: pbrDescriptor)
            logger.info("PBR render pipeline state created successfully")
        } catch {
            logger.error("Failed to create PBR render pipeline state: \(error)")
        }
    }
    
    private func createDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    private func createSamplerStates() {
        // 纹理采样器
        let textureDescriptor = MTLSamplerDescriptor()
        textureDescriptor.minFilter = .linear
        textureDescriptor.magFilter = .linear
        textureDescriptor.mipFilter = .linear
        textureDescriptor.sAddressMode = .repeat
        textureDescriptor.tAddressMode = .repeat
        textureDescriptor.maxAnisotropy = 16
        
        textureSampler = device.makeSamplerState(descriptor: textureDescriptor)
        
        // 阴影采样器
        let shadowDescriptor = MTLSamplerDescriptor()
        shadowDescriptor.minFilter = .linear
        shadowDescriptor.magFilter = .linear
        shadowDescriptor.compareFunction = .lessEqual
        shadowDescriptor.sAddressMode = .clampToEdge
        shadowDescriptor.tAddressMode = .clampToEdge
        
        shadowSampler = device.makeSamplerState(descriptor: shadowDescriptor)
    }
    
    private func setupDefaultLighting() {
        // 添加默认的方向光
        lightingSystem.addDirectionalLight(
            direction: SIMD3<Float>(-0.3, -0.7, -0.6),
            color: SIMD3<Float>(1.0, 0.95, 0.8),
            intensity: 3.0
        )
        
        // 设置环境光
        lightingSystem.ambientColor = SIMD3<Float>(0.1, 0.1, 0.15)
        lightingSystem.ambientIntensity = 0.3
        
        logger.info("Default lighting setup completed")
    }
    
    // MARK: - 渲染接口
    
    /// 渲染带有高级特性的场景
    public func renderAdvancedScene(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        camera: Camera,
        entities: [Entity]
    ) {
        let startTime = CACurrentMediaTime()
        renderStats.reset()
        
        // 准备光照数据
        updateLightingData(camera: camera)
        
        // 渲染阴影贴图
        renderShadowMaps(commandBuffer: commandBuffer, entities: entities, camera: camera)
        
        // 主渲染过程
        renderMainPass(
            commandBuffer: commandBuffer,
            renderPassDescriptor: renderPassDescriptor,
            camera: camera,
            entities: entities
        )
        
        // 更新统计信息
        let endTime = CACurrentMediaTime()
        renderStats.updateFrameTime(endTime - startTime)
        
        logger.debug("Frame rendered in \(String(format: "%.2f", (endTime - startTime) * 1000))ms")
    }
    
    private func renderShadowMaps(commandBuffer: MTLCommandBuffer, entities: [Entity], camera: Camera) {
        // 收集阴影投射物体
        let shadowCasters = entities.compactMap { entity -> ShadowCaster? in
            return entity as? ShadowCaster
        }
        
        // 渲染方向光阴影
        for light in lightingSystem.getDirectionalLights() {
            shadowMapper.renderDirectionalShadowMaps(
                commandBuffer: commandBuffer,
                light: light,
                scene: shadowCasters,
                camera: camera
            )
            renderStats.shadowMapRenders += 1
        }
        
        // 渲染点光源阴影
        for light in lightingSystem.getPointLights() {
            if let _ = shadowMapper.renderPointLightShadowMap(
                commandBuffer: commandBuffer,
                light: light,
                scene: shadowCasters
            ) {
                renderStats.shadowMapRenders += 1
            }
        }
    }
    
    private func renderMainPass(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        camera: Camera,
        entities: [Entity]
    ) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            logger.error("Failed to create render encoder for main pass")
            return
        }
        
        renderEncoder.label = "Advanced Main Render Pass"
        renderEncoder.setRenderPipelineState(pbrRenderPipelineState!)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // 设置采样器
        renderEncoder.setFragmentSamplerState(textureSampler, index: 0)
        renderEncoder.setFragmentSamplerState(shadowSampler, index: 1)
        
        // 设置阴影贴图
        let shadowMaps = shadowMapper.getDirectionalShadowMaps()
        for (index, shadowMap) in shadowMaps.enumerated() {
            if index < 4 {
                renderEncoder.setFragmentTexture(shadowMap, index: 5 + index)
            }
        }
        
        // 按材质分组渲染实体
        let groupedEntities = groupEntitiesByMaterial(entities)
        
        var currentMaterial: Material?
        
        for (material, entitiesWithMaterial) in groupedEntities {
            // 切换材质
            if currentMaterial?.id != material.id {
                bindMaterial(material, to: renderEncoder)
                currentMaterial = material
                renderStats.materialSwitches += 1
            }
            
            // 渲染实体
            for entity in entitiesWithMaterial {
                renderEntity(entity, with: renderEncoder, camera: camera)
            }
        }
        
        renderEncoder.endEncoding()
    }
    
    private func groupEntitiesByMaterial(_ entities: [Entity]) -> [(Material, [Entity])] {
        var groups: [String: (Material, [Entity])] = [:]
        
        for entity in entities {
            // 这里需要根据实际的Entity结构来获取材质
            // 暂时使用默认材质
            let material = materialManager.getDefaultMaterial()
            let materialId = material.id.uuidString
            
            if var group = groups[materialId] {
                group.1.append(entity)
                groups[materialId] = group
            } else {
                groups[materialId] = (material, [entity])
            }
        }
        
        return Array(groups.values)
    }
    
    private func bindMaterial(_ material: Material, to encoder: MTLRenderCommandEncoder) {
        // 绑定材质数据
        var materialData = material.getMaterialData()
        encoder.setFragmentBytes(&materialData, length: MemoryLayout<MaterialData>.size, index: 3)
        
        // 绑定纹理
        if let albedoTexture = material.textures[.albedo] {
            encoder.setFragmentTexture(albedoTexture, index: 0)
        } else {
            encoder.setFragmentTexture(textureManager.getWhiteTexture(), index: 0)
        }
        
        if let normalTexture = material.textures[.normal] {
            encoder.setFragmentTexture(normalTexture, index: 1)
        } else {
            encoder.setFragmentTexture(textureManager.getFlatNormalTexture(), index: 1)
        }
        
        if let metallicRoughnessTexture = material.textures[.metallicRoughness] {
            encoder.setFragmentTexture(metallicRoughnessTexture, index: 2)
        } else {
            encoder.setFragmentTexture(textureManager.getWhiteTexture(), index: 2)
        }
        
        if let aoTexture = material.textures[.ambientOcclusion] {
            encoder.setFragmentTexture(aoTexture, index: 3)
        } else {
            encoder.setFragmentTexture(textureManager.getWhiteTexture(), index: 3)
        }
        
        if let emissiveTexture = material.textures[.emissive] {
            encoder.setFragmentTexture(emissiveTexture, index: 4)
        } else {
            encoder.setFragmentTexture(textureManager.getBlackTexture(), index: 4)
        }
        
        renderStats.textureSwitches += 5
    }
    
    private func renderEntity(_ entity: Entity, with encoder: MTLRenderCommandEncoder, camera: Camera) {
        // 这里需要根据实际的Entity结构来渲染
        // 暂时跳过具体实现，因为需要与现有的ECS系统集成
        
        renderStats.drawCalls += 1
        renderStats.triangles += 100  // 示例值
    }
    
    private func updateLightingData(camera: Camera) {
        // 临时创建一个空的光照数据结构
        // 实际使用中可能需要从 lightingSystem 获取具体数据
        currentLightingData = LightingData()
        
        // TODO: 这里应该填充具体的光照数据
        logger.info("Light data updated for current frame")
    }
    
    // MARK: - 公共接口
    
    /// 设置阴影质量
    public func setShadowQuality(_ quality: ShadowMapper.ShadowQuality) {
        shadowMapper.shadowQuality = quality
    }
    
    /// 获取渲染统计信息
    public func getRenderStatistics() -> RenderStatistics {
        return renderStats
    }
    
    /// 添加光源
    public func addLight(_ light: Light) {
        if let directionalLight = light as? DirectionalLight {
            // 直接添加光源对象，而不是创建新的
            lightingSystem.directionalLights.append(directionalLight)
            lightingSystem.updateLightBuffer()
        } else if let pointLight = light as? PointLight {
            lightingSystem.pointLights.append(pointLight)
            lightingSystem.updateLightBuffer()
        } else if let spotLight = light as? SpotLight {
            lightingSystem.spotLights.append(spotLight)
            lightingSystem.updateLightBuffer()
        }
    }
    
    /// 移除光源
    public func removeLight(id: UUID) {
        lightingSystem.removeLight(id: id)
    }
    
    /// 创建材质
    public func createMaterial(preset: MaterialPreset = .default) -> Material {
        return materialManager.createMaterial(preset: preset)
    }
    
    /// 加载纹理
    public func loadTexture(named name: String) -> MTLTexture? {
        do {
            return try textureManager.loadTexture(name: name)
        } catch {
            logger.error("Failed to load texture \(name): \(error)")
            return nil
        }
    }
    
    // MARK: - 清理
    
    public func cleanup() {
        shadowMapper.cleanup()
        textureManager.clearCache()
        logger.info("Advanced renderer cleaned up")
    }
}

// MARK: - 材质管理器

/// 材质管理器 - 管理PBR材质的创建和缓存
public class MaterialManager {
    
    private let device: MTLDevice
    private var materials: [UUID: Material] = [:]
    private var defaultMaterial: Material?
    
    public init(device: MTLDevice) {
        self.device = device
        createDefaultMaterial()
    }
    
    private func createDefaultMaterial() {
        defaultMaterial = Material(preset: .default)
    }
    
    public func createMaterial(preset: MaterialPreset = .default) -> Material {
        let material = Material(preset: preset)
        materials[material.id] = material
        return material
    }
    
    public func getMaterial(id: UUID) -> Material? {
        return materials[id]
    }
    
    public func getDefaultMaterial() -> Material {
        return defaultMaterial ?? Material(preset: .default)
    }
    
    public func removeMaterial(id: UUID) {
        materials.removeValue(forKey: id)
    }
}

// MARK: - 常量

private let MAX_POINT_LIGHTS = 8
private let MAX_SPOT_LIGHTS = 8
