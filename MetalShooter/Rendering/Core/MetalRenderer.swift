//
//  MetalRenderer.swift
//  MetalShooter
//
//  Metal4 渲染器核心 - 管理整个渲染管线
//  负责Metal设备、渲染管线状态和命令缓冲区管理
//

import Foundation
import Metal
import MetalKit
import simd

/// Metal渲染器 - 游戏的核心渲染系统
/// 管理Metal设备、渲染管线、命令缓冲区和渲染循环
public class MetalRenderer: NSObject {
    
    // MARK: - Metal核心组件
    
    /// Metal设备 - GPU抽象
    private var device: MTLDevice!
    
    /// 命令队列 - 用于提交渲染命令
    private var commandQueue: MTLCommandQueue!
    
    /// 渲染管线状态 - 着色器和渲染配置
    private var renderPipelineState: MTLRenderPipelineState!
    
    /// 深度模板状态 - 深度测试配置
    private var depthStencilState: MTLDepthStencilState!
    
    // MARK: - 渲染资源
    
    /// 着色器库
    private var shaderLibrary: MTLLibrary!
    
    /// 当前视图
    private var metalView: MTKView!
    
    /// Uniform缓冲区池
    private var uniformBuffers: [MTLBuffer] = []
    private var currentUniformIndex = 0
    private let maxBuffersInFlight = 3
    
    /// 测试三角形顶点缓冲区
    private var testTriangleVertexBuffer: MTLBuffer!
    
    /// Lighting数据缓冲区
    private var lightingDataBuffer: MTLBuffer!
    
    /// 帧计数器 - 用于调试
    private var currentFrameIndex = 0
    
    // MARK: - 渲染参数
    
    /// 视口大小
    private var viewportSize: CGSize = CGSize(width: 800, height: 600)
    
    /// 清除颜色
    var clearColor: MTLClearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
    
    // MARK: - 公共访问器（用于测试）
    
    /// 获取Metal设备（用于测试）
    var currentDevice: MTLDevice? { return device }
    
    /// 获取命令队列（用于测试）
    var currentCommandQueue: MTLCommandQueue? { return commandQueue }
    
    /// 获取渲染管线状态（用于测试）
    var currentRenderPipelineState: MTLRenderPipelineState? { return renderPipelineState }
    
    /// 获取深度模板状态（用于测试）
    var currentDepthStencilState: MTLDepthStencilState? { return depthStencilState }
    
    /// 获取uniform缓冲区数组（用于测试）
    var currentUniformBuffers: [MTLBuffer] { return uniformBuffers }
    
    /// 获取最大缓冲区数量（用于测试）
    var currentMaxBuffersInFlight: Int { return maxBuffersInFlight }
    
    /// 获取视口大小（用于测试）
    var currentViewportSize: CGSize { return viewportSize }

    // MARK: - 初始化
    
    override init() {
        super.init()
        print("🎨 MetalRenderer 初始化开始...")
    }
    
    /// 初始化Metal渲染器
    /// - Parameter metalView: 用于渲染的MTKView
    func initialize(with metalView: MTKView? = nil) {
        // 1. 创建Metal设备
        setupMetalDevice()
        
        // 2. 创建命令队列
        setupCommandQueue()
        
        // 3. 设置视图
        if let view = metalView {
            setupMetalView(view)
        }
        
        // 4. 加载着色器
        loadShaders()
        
        // 5. 创建渲染管线
        createRenderPipeline()
        
        // 6. 创建深度缓冲区
        createDepthStencilState()
        
        // 7. 创建Uniform缓冲区
        createUniformBuffers()
        
        // 8. 创建测试三角形顶点缓冲区
        createTestTriangleVertexBuffer()
        
        // 9. 创建lighting数据缓冲区
        createLightingDataBuffer()
        
        print("✅ MetalRenderer 初始化完成")
        print("   设备: \(device.name)")
        print("   支持统一内存: \(device.hasUnifiedMemory)")
        print("   支持Apple Silicon优化: \(device.supportsFamily(.apple7))")
    }
    
    // MARK: - Metal设备设置
    
    /// 设置Metal设备
    private func setupMetalDevice() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("❌ Metal不支持此设备")
        }
        
        self.device = device
        print("📱 Metal设备创建成功: \(device.name)")
    }
    
    /// 设置命令队列
    private func setupCommandQueue() {
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("❌ 无法创建命令队列")
        }
        
        self.commandQueue = commandQueue
        commandQueue.label = "MetalShooter Command Queue"
        print("⚡ 命令队列创建成功")
    }
    
    /// 设置Metal视图
    /// - Parameter metalView: MTKView实例
    private func setupMetalView(_ metalView: MTKView) {
        self.metalView = metalView
        metalView.device = device
        metalView.delegate = self
        metalView.clearColor = clearColor
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.colorPixelFormat = .bgra8Unorm
        
        viewportSize = metalView.drawableSize
        print("🖥️ Metal视图设置完成: \(viewportSize)")
    }
    
    // MARK: - 着色器管理
    
    /// 加载着色器库
    private func loadShaders() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("❌ 无法加载默认着色器库")
        }
        
        self.shaderLibrary = library
        print("📜 着色器库加载成功")
    }
    
    // MARK: - 渲染管线设置
    
    /// 创建渲染管线状态
    private func createRenderPipeline() {
        guard let vertexFunction = shaderLibrary.makeFunction(name: "vertex_simple"),
              let fragmentFunction = shaderLibrary.makeFunction(name: "fragment_color_debug") else {
            fatalError("❌ 无法加载着色器函数")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MetalShooter Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // 顶点描述符 - 必须与 Swift Vertex 结构的实际内存布局匹配
        let vertexDescriptor = MTLVertexDescriptor()
        
        // 位置属性 (Float3) [[attribute(0)]]
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // 法线属性 (Float3) [[attribute(1)]] - Float3 对齐到 16 字节
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // 纹理坐标属性 (Float2) [[attribute(2)]]
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 32
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        // 颜色属性 (Float4) [[attribute(3)]] - 关键修复：使用实际的 Swift 结构偏移量
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].offset = 48  // 修正：Swift 中实际偏移量是 48，不是 40
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        // 切线属性 (Float3) [[attribute(4)]]
        vertexDescriptor.attributes[4].format = .float3
        vertexDescriptor.attributes[4].offset = 64  // 修正：correspondingly updated to 64
        vertexDescriptor.attributes[4].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.size
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("🔧 渲染管线创建成功")
        } catch {
            fatalError("❌ 无法创建渲染管线: \(error)")
        }
    }
    
    /// 创建深度模板状态
    private func createDepthStencilState() {
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        
        depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)!
        print("🛡️ 深度模板状态创建成功")
    }
    
    /// 创建Uniform缓冲区池
    private func createUniformBuffers() {
        for i in 0..<maxBuffersInFlight {
            guard let buffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: .storageModeShared) else {
                fatalError("❌ 无法创建Uniform缓冲区 \(i)")
            }
            buffer.label = "Uniform Buffer \(i)"
            uniformBuffers.append(buffer)
        }
        print("📦 Uniform缓冲区池创建成功 (\(maxBuffersInFlight)个)")
    }
    
    /// 创建测试三角形顶点缓冲区
    private func createTestTriangleVertexBuffer() {
        // 创建三角形顶点数据 - 使用更明亮的颜色
        let vertices: [Vertex] = [
            Vertex(position: Float3(0.0, 0.6, 0.0),   // 顶部
                   normal: Float3(0, 0, 1),
                   texCoords: Float2(0.5, 0),
                   color: Float4(1.0, 0.0, 0.0, 1.0)),     // 纯红色
            
            Vertex(position: Float3(-0.6, -0.6, 0.0), // 左下
                   normal: Float3(0, 0, 1),
                   texCoords: Float2(0, 1),
                   color: Float4(0.0, 1.0, 0.0, 1.0)),     // 纯绿色
            
            Vertex(position: Float3(0.6, -0.6, 0.0),  // 右下
                   normal: Float3(0, 0, 1),
                   texCoords: Float2(1, 1),
                   color: Float4(0.0, 0.0, 1.0, 1.0))      // 纯蓝色
        ]
        
        // 调试：打印顶点数据和内存布局
        print("🔍 顶点数据调试:")
        print("  Vertex结构大小: \(MemoryLayout<Vertex>.size) 字节")
        print("  Float3大小: \(MemoryLayout<Float3>.size) 字节, 对齐: \(MemoryLayout<Float3>.alignment)")
        print("  Float4大小: \(MemoryLayout<Float4>.size) 字节, 对齐: \(MemoryLayout<Float4>.alignment)")
        print("  Float2大小: \(MemoryLayout<Float2>.size) 字节, 对齐: \(MemoryLayout<Float2>.alignment)")
        
        for (index, vertex) in vertices.enumerated() {
            print("  顶点 \(index): 位置=\(vertex.position), 颜色=\(vertex.color)")
        }
        
        // 创建持久的顶点缓冲区
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                  length: vertices.count * MemoryLayout<Vertex>.size,
                                                  options: .storageModeShared) else {
            fatalError("❌ 无法创建测试三角形顶点缓冲区")
        }
        
        vertexBuffer.label = "Test Triangle Vertex Buffer"
        self.testTriangleVertexBuffer = vertexBuffer
        print("🔺 测试三角形顶点缓冲区创建成功")
        
        // 验证缓冲区数据 - 使用原始字节检查
        let bufferPointer = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: vertices.count)
        print("🔍 缓冲区数据验证:")
        for i in 0..<vertices.count {
            let vertex = bufferPointer[i]
            print("  缓冲区顶点 \(i): 位置=\(vertex.position), 颜色=\(vertex.color)")
        }
        
        // 详细的字节级检查
        let rawPointer = vertexBuffer.contents().assumingMemoryBound(to: UInt8.self)
        print("🔍 原始字节数据 (前80字节):")
        for i in 0..<min(80, vertices.count * MemoryLayout<Vertex>.size) {
            if i % 16 == 0 { print("") }
            print(String(format: "%02X ", rawPointer[i]), terminator: "")
        }
        print("")
    }
    
    /// 创建Lighting数据缓冲区
    private func createLightingDataBuffer() {
        let lightingDataSize = MemoryLayout<LightingData>.size
        
        guard let buffer = device.makeBuffer(length: lightingDataSize, options: .storageModeShared) else {
            fatalError("❌ 无法创建lighting数据缓冲区")
        }
        
        buffer.label = "Lighting Data Buffer"
        self.lightingDataBuffer = buffer
        
        // 初始化默认的lighting数据
        let bufferPointer = buffer.contents().bindMemory(to: LightingData.self, capacity: 1)
        bufferPointer.pointee = LightingData()
        
        print("💡 Lighting数据缓冲区创建成功 (大小: \(lightingDataSize) 字节)")
    }
    
    // MARK: - 渲染方法
    
    /// 开始渲染帧
    /// - Returns: 渲染命令编码器和命令缓冲区的元组
    func beginFrame() -> (encoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer)? {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = metalView?.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        commandBuffer.label = "MetalShooter Frame Command Buffer"
        renderEncoder.label = "MetalShooter Render Encoder"
        
        // 设置渲染管线
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // 设置视口
        let viewport = MTLViewport(
            originX: 0, originY: 0,
            width: Double(viewportSize.width), height: Double(viewportSize.height),
            znear: 0.0, zfar: 1.0
        )
        renderEncoder.setViewport(viewport)
        
        return (renderEncoder, commandBuffer)
    }
    
    /// 结束渲染帧
    /// - Parameters:
    ///   - renderEncoder: 渲染命令编码器
    ///   - commandBuffer: 命令缓冲区
    func endFrame(renderEncoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer) {
        renderEncoder.endEncoding()
        
        guard let drawable = metalView?.currentDrawable else {
            return
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // 更新缓冲区索引
        currentUniformIndex = (currentUniformIndex + 1) % maxBuffersInFlight
        
        // 增加帧计数器
        currentFrameIndex += 1
    }
    
    /// 获取当前Uniform缓冲区
    func getCurrentUniformBuffer() -> MTLBuffer {
        return uniformBuffers[currentUniformIndex]
    }
    
    /// 更新视口大小
    /// - Parameter size: 新的视口大小
    func updateViewportSize(_ size: CGSize) {
        viewportSize = size
        print("🖥️ 视口大小更新: \(size)")
    }
    
    /// 渲染三角形（测试方法）
    func renderTestTriangle() {
        guard let (renderEncoder, commandBuffer) = beginFrame() else { return }
        
        // 更新Uniform缓冲区
        updateUniformsWithCamera()
        
        // 使用预创建的顶点缓冲区
        renderEncoder.setVertexBuffer(testTriangleVertexBuffer, offset: 0, index: 0)
        
        // 设置uniform缓冲区
        renderEncoder.setVertexBuffer(getCurrentUniformBuffer(), offset: 0, index: 1)
        
        // 调试：添加调试组标记
        renderEncoder.pushDebugGroup("Test Triangle Rendering")
        
        // 绘制三角形
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        renderEncoder.popDebugGroup()
        
        endFrame(renderEncoder: renderEncoder, commandBuffer: commandBuffer)
    }
    
    /// 使用摄像机更新Uniforms
    private func updateUniformsWithCamera() {
        let uniformBuffer = getCurrentUniformBuffer()
        let uniformsPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        
        // 添加更详细的调试信息
        if currentFrameIndex % 60 == 0 {
            let allCameras = CameraSystem.shared.getAllCameras()
            print("🔍 摄像机调试: 注册摄像机数量=\(allCameras.count)")
        }
        
        // 获取主摄像机
        if let mainCamera = CameraSystem.shared.getMainCamera() {
            
            // 模型矩阵（单位矩阵，因为是测试三角形）
            uniformsPointer.pointee.modelMatrix = Float4x4(1.0)
            
            // 视图矩阵（从摄像机获取）
            uniformsPointer.pointee.viewMatrix = mainCamera.viewMatrix
            
            // 投影矩阵（从摄像机获取）
            uniformsPointer.pointee.projectionMatrix = mainCamera.projectionMatrix
            
            // 添加调试信息（只每60帧打印一次以避免日志过多）
            if currentFrameIndex % 60 == 0 {
                let pos = mainCamera.position
                print("📷 摄像机矩阵更新: 位置=(\(pos.x), \(pos.y), \(pos.z))")
                print("   视图矩阵[0]=[第一行: \(mainCamera.viewMatrix.columns.0)]")
            }
            
        } else {
            // 如果没有摄像机，使用默认矩阵
            uniformsPointer.pointee.modelMatrix = Float4x4(1.0)
            uniformsPointer.pointee.viewMatrix = Float4x4(1.0)
            uniformsPointer.pointee.projectionMatrix = createDefaultProjectionMatrix()
            
            if currentFrameIndex % 60 == 0 {
                print("⚠️ 警告: 没有找到主摄像机，使用默认矩阵")
            }
        }
    }
    
    /// 创建默认投影矩阵
    private func createDefaultProjectionMatrix() -> Float4x4 {
        let aspect = Float(viewportSize.width / viewportSize.height)
        let fovY = Float.pi / 3.0  // 60度
        let near: Float = 0.1
        let far: Float = 1000.0
        
        let f = 1.0 / tan(fovY / 2.0)
        return Float4x4([
            [f / aspect, 0, 0, 0],
            [0, f, 0, 0],
            [0, 0, (far + near) / (near - far), (2 * far * near) / (near - far)],
            [0, 0, -1, 0]
        ])
    }
}

// MARK: - MTKViewDelegate

extension MetalRenderer: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateViewportSize(size)
    }
    
    public func draw(in view: MTKView) {
        // 每帧更新游戏逻辑
        GameEngine.shared.update()
        
        // 渲染当前帧
        GameEngine.shared.render()
    }
}

// MARK: - 支持类型

/// Uniform数据结构
struct Uniforms {
    var modelMatrix: Float4x4
    var viewMatrix: Float4x4
    var projectionMatrix: Float4x4
}
