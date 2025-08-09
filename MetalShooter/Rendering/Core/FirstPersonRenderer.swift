//
//  FirstPersonRenderer.swift
//  MetalShooter
//
//  Stage 4 - 第一人称视角渲染器
//  专门处理FPS视角的武器、手臂等模型渲染
//

import Foundation
import Metal
import MetalKit
import simd

/// 第一人称渲染器 - 专门处理FPS视角渲染
class FirstPersonRenderer {
    
    // MARK: - 属性
    
    private var device: MTLDevice
    private var renderPipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?
    
    /// 第一人称相机位置和方向
    private var fpsCameraPosition: Float3 = Float3(0, 0, 0)
    private var fpsCameraRotation: Float3 = Float3(0, 0, 0)
    
    /// 武器位置偏移 (相对于相机)
    private var weaponOffset: Float3 = Float3(0.3, -0.2, -0.5)
    private var weaponRotation: Float3 = Float3(0, 0, 0)
    
    /// 武器摆动参数 (走路时的武器摆动)
    private var weaponSway: Float3 = Float3(0, 0, 0)
    private var walkingTime: Float = 0.0
    
    /// 渲染控制
    private var showWeapon: Bool = true
    private var showArms: Bool = true
    
    // MARK: - 初始化
    
    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        setupRenderPipeline(library: library)
        setupDepthStencil()
        print("🔫 FirstPersonRenderer 初始化完成")
    }
    
    /// 设置渲染管线
    private func setupRenderPipeline(library: MTLLibrary) {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // 设置着色器函数
        if let vertexFunc = library.makeFunction(name: "firstPersonVertexShader"),
           let fragmentFunc = library.makeFunction(name: "firstPersonFragmentShader") {
            pipelineDescriptor.vertexFunction = vertexFunc
            pipelineDescriptor.fragmentFunction = fragmentFunc
        } else {
            // 使用默认着色器作为后备
            print("⚠️ 使用默认着色器")
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_color_debug")
        }
        
        // 颜色附件
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // 顶点描述符 - 匹配FirstPersonVertexIn结构
        let vertexDescriptor = MTLVertexDescriptor()
        
        // 位置属性 [attribute(0)]
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // 法线属性 [attribute(1)]
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // 纹理坐标属性 [attribute(2)]
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        // 切线属性 [attribute(3)]
        vertexDescriptor.attributes[3].format = .float3
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 8
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        // 副切线属性 [attribute(4)]
        vertexDescriptor.attributes[4].format = .float3
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float>.stride * 11
        vertexDescriptor.attributes[4].bufferIndex = 0
        
        // 缓冲区布局 - 14个float (position:3 + normal:3 + texCoord:2 + tangent:3 + bitangent:3)
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 14
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // 创建管线状态
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ 创建FirstPersonRenderer管线状态失败: \(error)")
        }
    }
    
    /// 设置深度模板状态
    private func setupDepthStencil() {
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        self.depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }
    
    // MARK: - 渲染方法
    
    /// 渲染第一人称视角
    func render(encoder: MTLRenderCommandEncoder, viewMatrix: Float4x4, projectionMatrix: Float4x4) {
        print("🎯 FirstPersonRenderer.render() 被调用")
        print("   showWeapon: \(showWeapon), showArms: \(showArms)")
        
        guard let pipelineState = renderPipelineState,
              let depthState = depthStencilState else {
            print("❌ FirstPersonRenderer 渲染管线未初始化")
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)

        // 更新武器摆动
        updateWeaponSway()

        // 渲染武器
        if showWeapon {
            print("🔫 准备渲染武器...")
            renderWeapon(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        } else {
            print("❌ 武器被隐藏，不渲染")
        }

        // 渲染手臂
        if showArms {
            print("🖐 准备渲染手臂...")
            renderArms(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        } else {
            print("❌ 手臂被隐藏，不渲染")
        }
    }    /// 渲染武器
    private func renderWeapon(encoder: MTLRenderCommandEncoder, viewMatrix: Float4x4, projectionMatrix: Float4x4) {
        print("🔫 尝试渲染武器...")
        
        // 直接渲染简单的几何体，不依赖ModelManager
        print("🎯 直接渲染简单武器几何体")
        renderFallbackWeapon(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        
        // 计算武器的模型矩阵
        let weaponMatrix = calculateWeaponMatrix()
        
        // 设置Uniform数据
        var uniforms = FirstPersonUniforms(
            modelMatrix: weaponMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            normalMatrix: weaponMatrix.upperLeft3x3().inverse.transpose
        )
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        
        // 使用回退渲染而不是模型系统
        renderFallbackWeapon(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        return
    }
    
    /// 渲染手臂
    private func renderArms(encoder: MTLRenderCommandEncoder, viewMatrix: Float4x4, projectionMatrix: Float4x4) {
        print("🖐 尝试渲染手臂...")
        
        // 直接渲染简单的几何体作为手臂
        print("🎯 直接渲染简单手臂几何体")
        renderFallbackArms(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        
        // 计算手臂的模型矩阵
        let armsMatrix = calculateArmsMatrix()
        
        // 设置Uniform数据
        var uniforms = FirstPersonUniforms(
            modelMatrix: armsMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            normalMatrix: armsMatrix.upperLeft3x3().inverse.transpose
        )
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        
        // 使用回退渲染而不是模型系统
        renderFallbackArms(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        return
    }
    
    /// 渲染备用武器（简单几何体）
    private func renderFallbackWeapon(encoder: MTLRenderCommandEncoder, viewMatrix: Float4x4, projectionMatrix: Float4x4) {
        // 确保设置了渲染管线状态
        guard let pipelineState = renderPipelineState,
              let depthState = depthStencilState else {
            print("❌ 管线状态未初始化，无法渲染备用武器")
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        
        // 创建简单立方体作为武器的替代
        // 顶点格式: position(3) + normal(3) + texCoord(2) + tangent(3) + bitangent(3) = 14 floats per vertex
        let vertices: [Float] = [
            // 前面 - 武器主体 (蓝色)
            // position      normal        texCoord   tangent       bitangent
             0.1, -0.1, -0.4,  0.0, 0.0, 1.0,  0.0, 0.0,  1.0, 0.0, 0.0,  0.0, 1.0, 0.0,
             0.3, -0.1, -0.4,  0.0, 0.0, 1.0,  1.0, 0.0,  1.0, 0.0, 0.0,  0.0, 1.0, 0.0,
             0.3,  0.1, -0.4,  0.0, 0.0, 1.0,  1.0, 1.0,  1.0, 0.0, 0.0,  0.0, 1.0, 0.0,
             0.1,  0.1, -0.4,  0.0, 0.0, 1.0,  0.0, 1.0,  1.0, 0.0, 0.0,  0.0, 1.0, 0.0,
        ]
        
        let indices: [UInt16] = [
            0, 1, 2,  0, 2, 3  // 前面两个三角形
        ]
        
        // 创建顶点缓冲区
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, 
                                                   length: vertices.count * MemoryLayout<Float>.stride, 
                                                   options: [.storageModeShared]) else { return }
        
        guard let indexBuffer = device.makeBuffer(bytes: indices, 
                                                  length: indices.count * MemoryLayout<UInt16>.stride, 
                                                  options: [.storageModeShared]) else { return }
        
        // 计算武器的模型矩阵
        let weaponMatrix = calculateWeaponMatrix()
        
        // 设置Uniform数据
        var uniforms = FirstPersonUniforms(
            modelMatrix: weaponMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            normalMatrix: weaponMatrix.upperLeft3x3().inverse.transpose
        )
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        
        // 绘制
        encoder.drawIndexedPrimitives(type: .triangle, 
                                     indexCount: indices.count, 
                                     indexType: .uint16, 
                                     indexBuffer: indexBuffer, 
                                     indexBufferOffset: 0)
        
        print("🎯 渲染了备用武器几何体")
    }
    
    /// 渲染备用手臂（简单几何体）
    private func renderFallbackArms(encoder: MTLRenderCommandEncoder, viewMatrix: Float4x4, projectionMatrix: Float4x4) {
        // 确保设置了渲染管线状态
        guard let pipelineState = renderPipelineState,
              let depthState = depthStencilState else {
            print("❌ 管线状态未初始化，无法渲染备用手臂")
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        
        // 创建简单立方体作为手臂的替代 - 两个手臂
        // 顶点格式: position(3) + normal(3) + texCoord(2) + tangent(3) + bitangent(3) = 14 floats per vertex
        let vertices: [Float] = [
            // 左手臂 (红色)
            // position      normal        texCoord   tangent       bitangent
            -0.4, -0.3, -0.2,  1.0, 0.0, 0.0,  0.0, 0.0,  0.0, 0.0, 1.0,  0.0, 1.0, 0.0,
            -0.2, -0.3, -0.2,  1.0, 0.0, 0.0,  1.0, 0.0,  0.0, 0.0, 1.0,  0.0, 1.0, 0.0,
            -0.2, -0.1, -0.2,  1.0, 0.0, 0.0,  1.0, 1.0,  0.0, 0.0, 1.0,  0.0, 1.0, 0.0,
            -0.4, -0.1, -0.2,  1.0, 0.0, 0.0,  0.0, 1.0,  0.0, 0.0, 1.0,  0.0, 1.0, 0.0,
            
            // 右手臂 (绿色)
             0.2, -0.3, -0.2,  0.0, 1.0, 0.0,  0.0, 0.0,  0.0, 0.0, 1.0,  1.0, 0.0, 0.0,
             0.4, -0.3, -0.2,  0.0, 1.0, 0.0,  1.0, 0.0,  0.0, 0.0, 1.0,  1.0, 0.0, 0.0,
             0.4, -0.1, -0.2,  0.0, 1.0, 0.0,  1.0, 1.0,  0.0, 0.0, 1.0,  1.0, 0.0, 0.0,
             0.2, -0.1, -0.2,  0.0, 1.0, 0.0,  0.0, 1.0,  0.0, 0.0, 1.0,  1.0, 0.0, 0.0,
        ]
        
        let indices: [UInt16] = [
            // 左手臂
            0, 1, 2,  0, 2, 3,
            // 右手臂  
            4, 5, 6,  4, 6, 7
        ]
        
        // 创建顶点缓冲区
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, 
                                                   length: vertices.count * MemoryLayout<Float>.stride, 
                                                   options: [.storageModeShared]) else { return }
        
        guard let indexBuffer = device.makeBuffer(bytes: indices, 
                                                  length: indices.count * MemoryLayout<UInt16>.stride, 
                                                  options: [.storageModeShared]) else { return }
        
        // 计算手臂的模型矩阵
        let armsMatrix = calculateArmsMatrix()
        
        // 设置Uniform数据
        var uniforms = FirstPersonUniforms(
            modelMatrix: armsMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            normalMatrix: armsMatrix.upperLeft3x3().inverse.transpose
        )
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FirstPersonUniforms>.stride, index: 1)
        
        // 绘制
        encoder.drawIndexedPrimitives(type: .triangle, 
                                     indexCount: indices.count, 
                                     indexType: .uint16, 
                                     indexBuffer: indexBuffer, 
                                     indexBufferOffset: 0)
        
        print("🎯 渲染了备用手臂几何体")
    }
    
    // MARK: - 变换计算
    
    /// 计算武器的模型矩阵
    private func calculateWeaponMatrix() -> Float4x4 {
        // 基础位置 (相对于相机)
        let basePosition = weaponOffset + weaponSway
        
        // 创建变换矩阵
        let translation = Float4x4.translation(basePosition)
        let rotation = createYXZRotation(weaponRotation + Float3(0, 0, weaponSway.x * 0.1))
        
        return translation * rotation
    }
    
    /// 计算手臂的模型矩阵
    private func calculateArmsMatrix() -> Float4x4 {
        // 手臂位置 (稍微向后一点)
        let armsPosition = Float3(-0.1, -0.1, -0.3) + weaponSway * 0.5
        
        let translation = Float4x4.translation(armsPosition)
        let rotation = createYXZRotation(Float3(0, 0, weaponSway.x * 0.05))
        
        return translation * rotation
    }
    
    /// 创建YXZ旋转矩阵
    private func createYXZRotation(_ rotation: Float3) -> Float4x4 {
        let rotY = Float4x4.rotationY(rotation.y)
        let rotX = Float4x4.rotationX(rotation.x)
        let rotZ = Float4x4.rotationZ(rotation.z)
        
        return rotY * rotX * rotZ
    }
    
    /// 更新武器摆动效果
    private func updateWeaponSway() {
        walkingTime += 0.016 // 假设60FPS
        
        // 模拟走路时的武器摆动
        let swayIntensity: Float = 0.02
        weaponSway.x = sin(walkingTime * 2.0) * swayIntensity
        weaponSway.y = cos(walkingTime * 4.0) * swayIntensity * 0.5
        weaponSway.z = sin(walkingTime * 1.5) * swayIntensity * 0.3
    }
    
    // MARK: - 配置方法
    
    /// 设置武器可见性
    func setWeaponVisible(_ visible: Bool) {
        print("🔫 DEBUG: setWeaponVisible called with \(visible)")
        print("🔫 DEBUG: 调用堆栈:")
        for symbol in Thread.callStackSymbols.prefix(5) {
            print("  \(symbol)")
        }
        showWeapon = visible
        print("🔫 武器可见性: \(visible ? "显示" : "隐藏")")
    }
    
    /// 设置手臂可见性
    func setArmsVisible(_ visible: Bool) {
        showArms = visible
        print("🖐 手臂可见性: \(visible ? "显示" : "隐藏")")
    }
    
    /// 设置武器位置偏移
    func setWeaponOffset(_ offset: Float3) {
        weaponOffset = offset
    }
    
    /// 设置武器旋转
    func setWeaponRotation(_ rotation: Float3) {
        weaponRotation = rotation
    }
    
    /// 播放武器动画 (射击、装弹等)
    func playWeaponAnimation(_ animation: WeaponAnimation) {
        switch animation {
        case .shoot:
            // 后坐力效果
            weaponOffset.z += 0.05
            weaponRotation.x -= 0.1
            
        case .reload:
            // 装弹动画
            weaponOffset.y -= 0.1
            
        case .idle:
            // 回到默认状态
            weaponOffset = Float3(0.3, -0.2, -0.5)
            weaponRotation = Float3(0, 0, 0)
        }
    }
    
    // MARK: - 清理
    
    func cleanup() {
        renderPipelineState = nil
        depthStencilState = nil
        print("🧹 FirstPersonRenderer 清理完成")
    }
}

// MARK: - 数据结构

/// 第一人称渲染Uniform数据
struct FirstPersonUniforms {
    var modelMatrix: Float4x4
    var viewMatrix: Float4x4
    var projectionMatrix: Float4x4
    var normalMatrix: Float3x3
}

/// 武器动画类型
enum WeaponAnimation {
    case idle       // 空闲状态
    case shoot      // 射击
    case reload     // 装弹
}
