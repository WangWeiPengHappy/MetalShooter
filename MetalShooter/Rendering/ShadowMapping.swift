//
//  ShadowMapping.swift
//  MetalShooter
//
//  Phase 3: 阴影映射系统
//  实现实时阴影效果
//

import Metal
import MetalKit
import simd
import os

// MARK: - 阴影映射器

/// 阴影映射器 - 管理阴影贴图的生成和渲染
public class ShadowMapper {
    
    // MARK: - 类型定义
    
    public enum ShadowQuality: CustomStringConvertible {
        case low        // 512x512
        case medium     // 1024x1024
        case high       // 2048x2048
        case ultra      // 4096x4096
        
        var resolution: Int {
            switch self {
            case .low: return 512
            case .medium: return 1024
            case .high: return 2048
            case .ultra: return 4096
            }
        }
        
        public var description: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            case .ultra: return "ultra"
            }
        }
    }
    
    // MARK: - 属性
    
    private let device: MTLDevice
    private let logger = Logger(subsystem: "MetalShooter", category: "ShadowMapping")
    
    /// 阴影质量设置
    public var shadowQuality: ShadowQuality = .medium {
        didSet {
            if shadowQuality != oldValue {
                recreateShadowMaps()
            }
        }
    }
    
    /// 阴影偏移量（防止阴影痤疮）
    public var shadowBias: Float = 0.005
    
    /// 阴影软度（PCF采样范围）
    public var shadowSoftness: Float = 1.0
    
    /// PCF采样数量
    public var pcfSampleCount: Int = 16
    
    /// 是否启用级联阴影映射（CSM）
    public var cascadedShadowMapping: Bool = true
    
    /// CSM分级数量
    public var csmCascadeCount: Int = 4
    
    /// CSM分级分布参数
    public var csmLambda: Float = 0.5
    
    // MARK: - 阴影贴图资源
    
    /// 方向光阴影贴图（支持CSM）
    private var directionalShadowMaps: [MTLTexture] = []
    
    /// 点光源立方体阴影贴图
    private var pointShadowMaps: [String: MTLTexture] = [:]
    
    /// 聚光灯阴影贴图
    private var spotShadowMaps: [String: MTLTexture] = [:]
    
    /// 阴影深度状态
    private var shadowDepthStencilState: MTLDepthStencilState?
    
    /// 阴影渲染管线状态
    private var shadowRenderPipelineState: MTLRenderPipelineState?
    
    /// 点光源阴影渲染管线状态（几何着色器版本）
    private var pointShadowRenderPipelineState: MTLRenderPipelineState?
    
    // MARK: - 初始化
    
    public init(device: MTLDevice) {
        self.device = device
        setupShadowMapping()
    }
    
    deinit {
        logger.info("ShadowMapper deinitialized")
    }
    
    // MARK: - 设置
    
    private func setupShadowMapping() {
        createDepthStencilState()
        createRenderPipelineStates()
        createShadowMaps()
        
        logger.info("Shadow mapping system initialized with quality: \(self.shadowQuality) (\(self.shadowQuality.resolution)x\(self.shadowQuality.resolution))")
    }
    
    private func createDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        
        shadowDepthStencilState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    private func createRenderPipelineStates() {
        guard let library = device.makeDefaultLibrary() else {
            logger.error("Failed to create shader library for shadow mapping")
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
        
        // 切线属性 (Float3)
        vertexDescriptor.attributes[4].format = .float3
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float3>.size * 2 + MemoryLayout<Float2>.size + MemoryLayout<Float4>.size
        vertexDescriptor.attributes[4].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.size
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // 创建标准阴影渲染管线
        let shadowDescriptor = MTLRenderPipelineDescriptor()
        shadowDescriptor.vertexFunction = library.makeFunction(name: "shadow_vertex")
        shadowDescriptor.fragmentFunction = nil // 只需要深度，不需要片段着色器
        shadowDescriptor.depthAttachmentPixelFormat = .depth32Float
        shadowDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            shadowRenderPipelineState = try device.makeRenderPipelineState(descriptor: shadowDescriptor)
        } catch {
            logger.error("Failed to create shadow render pipeline state: \(error)")
        }
        
        // 创建点光源阴影渲染管线（使用几何着色器）
        let pointShadowDescriptor = MTLRenderPipelineDescriptor()
        pointShadowDescriptor.vertexFunction = library.makeFunction(name: "point_shadow_vertex")
        pointShadowDescriptor.fragmentFunction = library.makeFunction(name: "point_shadow_fragment")
        pointShadowDescriptor.colorAttachments[0].pixelFormat = .r32Float // 存储距离值
        pointShadowDescriptor.depthAttachmentPixelFormat = .depth32Float
        pointShadowDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pointShadowRenderPipelineState = try device.makeRenderPipelineState(descriptor: pointShadowDescriptor)
        } catch {
            logger.error("Failed to create point shadow render pipeline state: \(error)")
        }
    }
    
    private func createShadowMaps() {
        createDirectionalShadowMaps()
    }
    
    private func recreateShadowMaps() {
        // 清除现有阴影贴图
        directionalShadowMaps.removeAll()
        pointShadowMaps.removeAll()
        spotShadowMaps.removeAll()
        
        // 重新创建阴影贴图
        createShadowMaps()
        
        logger.info("Shadow maps recreated with resolution: \(self.shadowQuality.resolution)")
    }
    
    private func createDirectionalShadowMaps() {
        let cascadeCount = cascadedShadowMapping ? csmCascadeCount : 1
        let resolution = shadowQuality.resolution
        
        for i in 0..<cascadeCount {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.pixelFormat = .depth32Float
            descriptor.width = resolution
            descriptor.height = resolution
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            
            guard let texture = device.makeTexture(descriptor: descriptor) else {
                logger.error("Failed to create directional shadow map \(i)")
                continue
            }
            
            texture.label = "DirectionalShadowMap_Cascade_\(i)"
            directionalShadowMaps.append(texture)
        }
        
        logger.info("Created \(self.directionalShadowMaps.count) directional shadow maps")
    }
    
    // MARK: - 阴影贴图生成
    
    /// 渲染方向光阴影贴图
    public func renderDirectionalShadowMaps(
        commandBuffer: MTLCommandBuffer,
        light: DirectionalLight,
        scene: [ShadowCaster],
        camera: Camera
    ) {
        guard light.castsShadows, !directionalShadowMaps.isEmpty else { return }
        
        if cascadedShadowMapping {
            renderCascadedShadowMaps(commandBuffer: commandBuffer, light: light, scene: scene, camera: camera)
        } else {
            renderSingleShadowMap(commandBuffer: commandBuffer, light: light, scene: scene, camera: camera)
        }
    }
    
    private func renderSingleShadowMap(
        commandBuffer: MTLCommandBuffer,
        light: DirectionalLight,
        scene: [ShadowCaster],
        camera: Camera
    ) {
        guard let shadowMap = directionalShadowMaps.first else { return }
        
        let lightViewMatrix = calculateLightViewMatrix(for: light, targetPosition: SIMD3<Float>(0, 0, 0))
        let lightProjectionMatrix = calculateLightProjectionMatrix(for: light, camera: camera)
        
        renderShadowMap(
            commandBuffer: commandBuffer,
            shadowMap: shadowMap,
            viewMatrix: lightViewMatrix,
            projectionMatrix: lightProjectionMatrix,
            scene: scene,
            label: "DirectionalShadowMap"
        )
    }
    
    private func renderCascadedShadowMaps(
        commandBuffer: MTLCommandBuffer,
        light: DirectionalLight,
        scene: [ShadowCaster],
        camera: Camera
    ) {
        let cascadeDistances = calculateCascadeDistances(camera: camera)
        
        for (index, shadowMap) in directionalShadowMaps.enumerated() {
            guard index < cascadeDistances.count - 1 else { break }
            
            let nearDistance = cascadeDistances[index]
            let farDistance = cascadeDistances[index + 1]
            
            let lightViewMatrix = calculateLightViewMatrix(for: light, targetPosition: camera.position)
            let lightProjectionMatrix = calculateLightProjectionMatrix(
                for: light,
                camera: camera,
                nearDistance: nearDistance,
                farDistance: farDistance
            )
            
            renderShadowMap(
                commandBuffer: commandBuffer,
                shadowMap: shadowMap,
                viewMatrix: lightViewMatrix,
                projectionMatrix: lightProjectionMatrix,
                scene: scene,
                label: "DirectionalShadowMap_Cascade_\(index)"
            )
        }
    }
    
    /// 渲染点光源阴影贴图（立方体贴图）
    public func renderPointLightShadowMap(
        commandBuffer: MTLCommandBuffer,
        light: PointLight,
        scene: [ShadowCaster]
    ) -> String? {
        guard light.castsShadows else { return nil }
        
        let lightId = light.id.uuidString
        
        // 创建或获取点光源阴影贴图
        if pointShadowMaps[lightId] == nil {
            pointShadowMaps[lightId] = createPointLightShadowMap(for: lightId)
        }
        
        guard let shadowMap = pointShadowMaps[lightId] else { return nil }
        
        // 渲染六个面的阴影贴图
        let directions: [SIMD3<Float>] = [
            SIMD3<Float>(1, 0, 0),   // +X
            SIMD3<Float>(-1, 0, 0),  // -X
            SIMD3<Float>(0, 1, 0),   // +Y
            SIMD3<Float>(0, -1, 0),  // -Y
            SIMD3<Float>(0, 0, 1),   // +Z
            SIMD3<Float>(0, 0, -1)   // -Z
        ]
        
        let upVectors: [SIMD3<Float>] = [
            SIMD3<Float>(0, -1, 0),  // +X
            SIMD3<Float>(0, -1, 0),  // -X
            SIMD3<Float>(0, 0, 1),   // +Y
            SIMD3<Float>(0, 0, -1),  // -Y
            SIMD3<Float>(0, -1, 0),  // +Z
            SIMD3<Float>(0, -1, 0)   // -Z
        ]
        
        for face in 0..<6 {
            let viewMatrix = calculatePointLightViewMatrix(
                position: light.position,
                direction: directions[face],
                up: upVectors[face]
            )
            
            let projectionMatrix = matrix_perspective(
                fovyRadians: Float.pi / 2,  // 90度视角
                aspectRatio: 1.0,
                nearZ: 0.1,
                farZ: light.range
            )
            
            renderCubeFaceShadowMap(
                commandBuffer: commandBuffer,
                shadowMap: shadowMap,
                face: face,
                viewMatrix: viewMatrix,
                projectionMatrix: projectionMatrix,
                lightPosition: light.position,
                lightRange: light.range,
                scene: scene,
                label: "PointShadowMap_\(lightId)_Face_\(face)"
            )
        }
        
        return lightId
    }
    
    private func renderShadowMap(
        commandBuffer: MTLCommandBuffer,
        shadowMap: MTLTexture,
        viewMatrix: matrix_float4x4,
        projectionMatrix: matrix_float4x4,
        scene: [ShadowCaster],
        label: String
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.depthAttachment.texture = shadowMap
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            logger.error("Failed to create render encoder for shadow map: \(label)")
            return
        }
        
        renderEncoder.label = label
        renderEncoder.setRenderPipelineState(shadowRenderPipelineState!)
        renderEncoder.setDepthStencilState(shadowDepthStencilState)
        
        let mvpMatrix = projectionMatrix * viewMatrix
        var shadowUniforms = ShadowUniforms(
            mvpMatrix: mvpMatrix,
            bias: shadowBias
        )
        
        renderEncoder.setVertexBytes(&shadowUniforms, length: MemoryLayout<ShadowUniforms>.size, index: 1)
        
        // 渲染场景中的阴影投射物体
        for caster in scene {
            caster.renderToShadowMap(encoder: renderEncoder)
        }
        
        renderEncoder.endEncoding()
    }
    
    private func renderCubeFaceShadowMap(
        commandBuffer: MTLCommandBuffer,
        shadowMap: MTLTexture,
        face: Int,
        viewMatrix: matrix_float4x4,
        projectionMatrix: matrix_float4x4,
        lightPosition: SIMD3<Float>,
        lightRange: Float,
        scene: [ShadowCaster],
        label: String
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        // 对于立方体贴图，需要设置特定面的渲染目标
        renderPassDescriptor.colorAttachments[0].texture = shadowMap
        renderPassDescriptor.colorAttachments[0].slice = face
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            logger.error("Failed to create render encoder for cube shadow map: \(label)")
            return
        }
        
        renderEncoder.label = label
        renderEncoder.setRenderPipelineState(pointShadowRenderPipelineState!)
        
        let mvpMatrix = projectionMatrix * viewMatrix
        var pointShadowUniforms = PointShadowUniforms(
            mvpMatrix: mvpMatrix,
            lightPosition: lightPosition,
            lightRange: lightRange
        )
        
        renderEncoder.setVertexBytes(&pointShadowUniforms, length: MemoryLayout<PointShadowUniforms>.size, index: 1)
        
        // 渲染场景中的阴影投射物体
        for caster in scene {
            caster.renderToShadowMap(encoder: renderEncoder)
        }
        
        renderEncoder.endEncoding()
    }
    
    // MARK: - 辅助计算方法
    
    private func calculateCascadeDistances(camera: Camera) -> [Float] {
        let nearClip = camera.nearClip
        let farClip = camera.farClip
        
        var distances: [Float] = [nearClip]
        
        for i in 1...csmCascadeCount {
            let ratio = Float(i) / Float(csmCascadeCount)
            
            // 使用对数和线性分布的混合
            let logDistance = nearClip * pow(Float(farClip) / Float(nearClip), ratio)
            let linearDistance = nearClip + ratio * (farClip - nearClip)
            
            let distance = csmLambda * logDistance + (1.0 - csmLambda) * linearDistance
            distances.append(distance)
        }
        
        return distances
    }
    
    private func calculateLightViewMatrix(for light: DirectionalLight, targetPosition: SIMD3<Float>) -> matrix_float4x4 {
        let lightDirection = light.direction
        let lightPosition = targetPosition - lightDirection * 50.0  // 将光源放在目标后方
        
        return matrix_look_at(
            eye: lightPosition,
            target: targetPosition,
            up: SIMD3<Float>(0, 1, 0)
        )
    }
    
    private func calculateLightProjectionMatrix(
        for light: DirectionalLight,
        camera: Camera,
        nearDistance: Float? = nil,
        farDistance: Float? = nil
    ) -> matrix_float4x4 {
        // 计算视锥体的边界
        let near = nearDistance ?? camera.nearClip
        let far = farDistance ?? camera.farClip
        
        // 简化的正交投影矩阵计算
        let size: Float = 20.0  // 可以根据场景大小调整
        
        return matrix_ortho(
            left: -size, right: size,
            bottom: -size, top: size,
            nearZ: -50.0, farZ: 50.0
        )
    }
    
    private func calculatePointLightViewMatrix(position: SIMD3<Float>, direction: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
        return matrix_look_at(
            eye: position,
            target: position + direction,
            up: up
        )
    }
    
    private func createPointLightShadowMap(for lightId: String) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .typeCube
        descriptor.pixelFormat = .r32Float
        descriptor.width = shadowQuality.resolution / 2  // 点光源使用较小分辨率
        descriptor.height = shadowQuality.resolution / 2
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        
        let texture = device.makeTexture(descriptor: descriptor)
        texture?.label = "PointShadowMap_\(lightId)"
        
        return texture
    }
    
    // MARK: - 资源访问
    
    public func getDirectionalShadowMaps() -> [MTLTexture] {
        return directionalShadowMaps
    }
    
    public func getPointShadowMap(for lightId: String) -> MTLTexture? {
        return pointShadowMaps[lightId]
    }
    
    public func getSpotShadowMap(for lightId: String) -> MTLTexture? {
        return spotShadowMaps[lightId]
    }
    
    // MARK: - 清理
    
    public func cleanup() {
        directionalShadowMaps.removeAll()
        pointShadowMaps.removeAll()
        spotShadowMaps.removeAll()
        
        logger.info("Shadow mapping resources cleaned up")
    }
}

// MARK: - 阴影投射器协议

/// 能够投射阴影的物体需要实现此协议
public protocol ShadowCaster {
    func renderToShadowMap(encoder: MTLRenderCommandEncoder)
}

// MARK: - 阴影制服结构

/// 标准阴影渲染制服
public struct ShadowUniforms {
    var mvpMatrix: matrix_float4x4
    var bias: Float
}

/// 点光源阴影渲染制服
public struct PointShadowUniforms {
    var mvpMatrix: matrix_float4x4
    var lightPosition: SIMD3<Float>
    var lightRange: Float
}

// MARK: - 矩阵辅助函数

private func matrix_perspective(fovyRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tan(fovyRadians * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    
    return matrix_float4x4(columns: (
        SIMD4<Float>(xs, 0, 0, 0),
        SIMD4<Float>(0, ys, 0, 0),
        SIMD4<Float>(0, 0, zs, -1),
        SIMD4<Float>(0, 0, zs * nearZ, 0)
    ))
}

private func matrix_ortho(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    return matrix_float4x4(columns: (
        SIMD4<Float>(2 / (right - left), 0, 0, 0),
        SIMD4<Float>(0, 2 / (top - bottom), 0, 0),
        SIMD4<Float>(0, 0, 1 / (nearZ - farZ), 0),
        SIMD4<Float>((left + right) / (left - right), (top + bottom) / (bottom - top), nearZ / (nearZ - farZ), 1)
    ))
}

private func matrix_look_at(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
    let zAxis = normalize(eye - target)
    let xAxis = normalize(cross(up, zAxis))
    let yAxis = cross(zAxis, xAxis)
    
    return matrix_float4x4(columns: (
        SIMD4<Float>(xAxis.x, yAxis.x, zAxis.x, 0),
        SIMD4<Float>(xAxis.y, yAxis.y, zAxis.y, 0),
        SIMD4<Float>(xAxis.z, yAxis.z, zAxis.z, 0),
        SIMD4<Float>(-dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1)
    ))
}
