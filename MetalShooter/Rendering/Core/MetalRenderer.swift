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
    private var lightingDataBuffer: MTLBuffer! // 用于基础光照(BasicLightingData)
    private var printedLightingDebugFrames = 0
    private var autoRotateAngle: Float = 0
    var enableAutoRotate: Bool = true
    
    /// 帧计数器 - 用于调试
    private var currentFrameIndex = 0
    
    /// 三角形首次显示状态跟踪
    private var isTriangleFirstAppearance = true  // 标记三角形是否为首次出现
    private var triangleCenterFrameCount = 0      // 中心位置帧数计数
    private let triangleCenterDuration = 60       // 中心位置持续帧数（约1秒@60fps）
    
    // MARK: - 渲染参数
    
    /// 视口大小
    private var viewportSize: CGSize = CGSize(width: 800, height: 600)
    
    /// 清除颜色
    var clearColor: MTLClearColor = MTLClearColor(red: 0.25, green: 0.28, blue: 0.35, alpha: 1.0) // 稍微亮一些的背景营造体积感
    
    /// 测试三角形可见性控制
    var isTestTriangleVisible: Bool = true
    
    // MARK: - 玩家模型渲染
    
    /// 玩家模型数据
    private var playerModelData: MetalModelData?
    /// 玩家模型包围盒 (用于自适应缩放与定位)
    private var playerModelBoundingBox: BoundingBox?
    
    /// 玩家模型可见性控制
    var isPlayerModelVisible: Bool = false {
        didSet {
            if isPlayerModelVisible && playerModelData == nil {
                loadPlayerModel()
            }
        }
    }

    /// 确保玩家模型数据已加载（外部在状态同步后可显式调用）
    func ensurePlayerModelLoaded() {
        if playerModelData == nil {
            loadPlayerModel()
        }
    }
    
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
    
    /// MetalRenderer访问器 - 提供对内部组件的访问
    var metalRenderer: (device: MTLDevice?, library: MTLLibrary?) {
        return (device: device, library: shaderLibrary)
    }

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
        
        // 10. 预加载玩家模型（可选）
        // loadPlayerModel()
        
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
    let useNormalVis = ProcessInfo.processInfo.environment["MSHOW_NORMALS"] == "1"
    guard let vertexFunction = shaderLibrary.makeFunction(name: "vertex_simple"),
        let fragmentFunction = shaderLibrary.makeFunction(name: useNormalVis ? "fragment_normals" : "fragment_basic_lighting") else {
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
            print("🔧 渲染管线创建成功 (fragment=\(useNormalVis ? "fragment_normals" : "fragment_basic_lighting"))")
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
        // 创建三角形顶点数据 - 确保始终显示在窗口中心
        // NDC坐标系：(0,0)为屏幕中心，x范围[-1,1], y范围[-1,1]
        let triangleSize: Float = 0.3  // 三角形大小（可调整）
        
        let vertices: [Vertex] = [
            Vertex(position: Float3(0.0, triangleSize, 0.0),           // 顶部中心
                   normal: Float3(0, 0, 1),
                   texCoords: Float2(0.5, 0),
                   color: Float4(1.0, 0.0, 0.0, 1.0)),                 // 纯红色
            
            Vertex(position: Float3(-triangleSize, -triangleSize, 0.0), // 左下
                   normal: Float3(0, 0, 1),
                   texCoords: Float2(0, 1),
                   color: Float4(0.0, 1.0, 0.0, 1.0)),                 // 纯绿色
            
            Vertex(position: Float3(triangleSize, -triangleSize, 0.0),  // 右下
                   normal: Float3(0, 0, 1),
                   texCoords: Float2(1, 1),
                   color: Float4(0.0, 0.0, 1.0, 1.0))                  // 纯蓝色
        ]
        
        // 调试：打印顶点数据和内存布局
        print("🔍 窗口中心三角形顶点数据调试:")
        print("  三角形大小: \(triangleSize)")
        print("  Vertex结构大小: \(MemoryLayout<Vertex>.size) 字节")
        print("  Float3大小: \(MemoryLayout<Float3>.size) 字节, 对齐: \(MemoryLayout<Float3>.alignment)")
        print("  Float4大小: \(MemoryLayout<Float4>.size) 字节, 对齐: \(MemoryLayout<Float4>.alignment)")
        print("  Float2大小: \(MemoryLayout<Float2>.size) 字节, 对齐: \(MemoryLayout<Float2>.alignment)")
        
        for (index, vertex) in vertices.enumerated() {
            print("  顶点 \(index): 位置=\(vertex.position), 颜色=\(vertex.color)")
        }
        print("  📍 三角形将始终显示在窗口中心位置")
        
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
    var stride = MemoryLayout<BasicLightingData>.stride
    if stride != 64 {
        print("⚠️ BasicLightingData stride=\(stride) != 64 (期望Metal对齐到4个float4). 强制使用64字节缓冲避免片段读取错位。")
        stride = 64
    }
        
        guard let buffer = device.makeBuffer(length: stride, options: .storageModeShared) else {
            fatalError("❌ 无法创建lighting数据缓冲区")
        }
        
        buffer.label = "Lighting Data Buffer"
        self.lightingDataBuffer = buffer
        
        // 初始化默认的lighting数据
    var initial = BasicLightingData()
    memcpy(buffer.contents(), &initial, MemoryLayout<BasicLightingData>.stride)
        
    print("💡 Lighting数据缓冲区创建成功 (CPU stride=\(MemoryLayout<BasicLightingData>.stride) 实际分配=\(stride) 字节)")
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
    
    /// 渲染场景（包括第一人称视角）
    func renderScene(firstPersonRenderer: FirstPersonRenderer?) {
        print("🎬 MetalRenderer.renderScene() 开始")
        guard let (renderEncoder, commandBuffer) = beginFrame() else { 
            print("❌ beginFrame() 失败")
            return 
        }

        // 更新Uniform缓冲区
        updateUniformsWithCamera()

        // 调试：显示当前状态
        print("🔍 渲染状态调试: 三角形可见=\(isTestTriangleVisible), 玩家模型可见=\(isPlayerModelVisible)")
        
        // 渲染测试三角形（如果可见）
        if isTestTriangleVisible {
            print("🔺 渲染测试三角形")
            renderTestTriangleContent(encoder: renderEncoder)
        }
        
        // 渲染玩家模型（如果可见）
        if isPlayerModelVisible {
            print("🎭 渲染玩家模型")
            renderPlayerModel(encoder: renderEncoder)
        }

        // 渲染第一人称视角（武器和手臂）
        if let fpRenderer = firstPersonRenderer {
            print("✅ 找到FirstPersonRenderer，开始渲染第一人称视角")
            renderFirstPersonView(encoder: renderEncoder, firstPersonRenderer: fpRenderer)
        } else {
            print("❌ FirstPersonRenderer 为 nil")
        }

        endFrame(renderEncoder: renderEncoder, commandBuffer: commandBuffer)
        print("🎬 MetalRenderer.renderScene() 完成")
    }    /// 渲染测试三角形内容
    private func renderTestTriangleContent(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("Test Triangle")
        
        // 检查是否为首次出现或仍在中心显示阶段
        if isTriangleFirstAppearance || triangleCenterFrameCount < triangleCenterDuration {
            print("🔺 渲染三角形在窗口中心 - 帧数: \(triangleCenterFrameCount)/\(triangleCenterDuration)")
            renderTriangleAtCenter(encoder: encoder)
            
            if isTriangleFirstAppearance {
                isTriangleFirstAppearance = false
                triangleCenterFrameCount = 0
            }
            triangleCenterFrameCount += 1
        } else {
            print("🔺 渲染三角形 - 跟随相机/鼠标移动")
            renderTriangleWithCamera(encoder: encoder)
        }
        
        encoder.popDebugGroup()
    }
    
    /// 在窗口中心渲染三角形（首次出现时使用）
    private func renderTriangleAtCenter(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("Triangle - Center Position")
        
        // 创建固定的矩阵变换 - 保证三角形显示在屏幕中心
        let identityMatrix = Float4x4.identity
        let centerViewMatrix = Float4x4.identity
        let orthographicProjection = Float4x4.orthographicProjection(
            left: -1.0, right: 1.0, 
            bottom: -1.0, top: 1.0, 
            near: -1.0, far: 1.0
        )
        
        // 设置固定的 uniform 数据以确保三角形居中显示
        var uniforms = Uniforms(
            modelMatrix: identityMatrix,
            viewMatrix: centerViewMatrix,
            projectionMatrix: orthographicProjection
        )
        
        // 使用临时缓冲区传递固定的uniform数据
        encoder.setVertexBuffer(testTriangleVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
    // 绑定光照缓冲 (保证片段阶段也能取到默认光照, 即便只是三角形调试)
    encoder.setFragmentBuffer(lightingDataBuffer, offset: 0, index: 2)
    // 绘制三角形
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        encoder.popDebugGroup()
        print("📍 三角形已渲染在窗口中心位置")
    }
    
    /// 使用相机变换渲染三角形（正常移动功能）
    private func renderTriangleWithCamera(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("Triangle - Camera Following")
        
        // 使用正常的uniform缓冲区（包含相机变换）
        encoder.setVertexBuffer(testTriangleVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[currentUniformIndex], offset: 0, index: 1)
        
    encoder.setFragmentBuffer(lightingDataBuffer, offset: 0, index: 2)
    // 绘制三角形
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        encoder.popDebugGroup()
        print("📍 三角形跟随相机移动渲染完成")
    }
    
    /// 渲染第一人称视角
    private func renderFirstPersonView(encoder: MTLRenderCommandEncoder, firstPersonRenderer: FirstPersonRenderer) {
        print("👁️ 开始渲染第一人称视角")
        encoder.pushDebugGroup("First Person View")

        // 获取摄像机矩阵
        if let mainCamera = CameraSystem.shared.getMainCamera() {
            let viewMatrix = mainCamera.viewMatrix
            let projMatrix = mainCamera.projectionMatrix
            print("📷 获取到主相机矩阵")

            // 使用第一人称渲染器渲染
            firstPersonRenderer.render(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projMatrix)
        } else {
            print("❌ 无法获取主相机")
        }

        encoder.popDebugGroup()
        print("👁️ 第一人称视角渲染完成")
    }
    
    // MARK: - 玩家模型渲染
    
    /// 加载玩家模型
    private func loadPlayerModel() {
        print("🏗️ 开始加载玩家模型...")
        
        do {
            // 使用当前版本（可能是Blender/程序生成/未来的专业版）
            playerModelData = try PlayerModelLoader.shared.loadCurrentPlayerModelForMetal(device: device)
            print("✅ 玩家模型加载成功 (当前版本)")
            // 同步缓存逻辑模型以取得包围盒数据
            let logicalModel = PlayerModelLoader.shared.loadCurrentPlayerModel()
            playerModelBoundingBox = logicalModel.boundingBox
            let bb = logicalModel.boundingBox
            print("📦 玩家模型包围盒: min=\(bb.min) max=\(bb.max) size=\(bb.size)")
            if logicalModel.totalVertices == 0 || playerModelData?.indexCount == 0 {
                print("⚠️ 警告: 玩家模型为空 (顶点或索引为0)。请检查 OBJ 资源与解析。")
            }
            
            // 打印模型统计信息
            if let data = playerModelData {
                let materialCount = data.materials.count
                let renderCommandCount = data.renderCommands.count
                print("📊 模型统计:")
                print("   材质数量: \(materialCount)")
                print("   渲染命令数量: \(renderCommandCount)")
                print("   索引数量: \(data.indexCount)")
            }
        } catch {
            print("❌ 玩家模型加载失败: \(error)")
            playerModelData = nil
        }
    }
    
    /// 渲染玩家模型
    private func renderPlayerModel(encoder: MTLRenderCommandEncoder) {
        if playerModelData == nil {
            print("🛠️ 玩家模型数据缺失，尝试即时加载...")
            loadPlayerModel()
        }
        guard let modelData = playerModelData else {
            print("❌ 玩家模型数据仍为空，跳过渲染")
            return
        }
        if modelData.indexCount == 0 {
            print("⚠️ 玩家模型索引数量为0，跳过渲染")
            return
        }
        
        encoder.pushDebugGroup("Player Model")
        print("🎭 开始渲染玩家模型")
        
        // 设置顶点缓冲区
        encoder.setVertexBuffer(modelData.vertexBuffer, offset: 0, index: 0)
        
        // 设置Uniform缓冲区
        let uniformBuffer = getCurrentUniformBuffer()
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
    // 设置 lighting 数据缓冲区 (顶点 + 片段, 片段用于光照计算)
    encoder.setVertexBuffer(lightingDataBuffer, offset: 0, index: 2)
    encoder.setFragmentBuffer(lightingDataBuffer, offset: 0, index: 2)
        
        // 按渲染命令渲染
        for renderCommand in modelData.renderCommands {
            guard let material = modelData.materials[renderCommand.materialId] else {
                print("❌ 找不到材质: \(renderCommand.materialId)")
                continue
            }
            
            print("🎨 渲染材质: \(renderCommand.materialId)")
            
            // 这里可以设置材质相关的uniform数据
            // 暂时使用默认的uniform设置
            
            // 渲染这个组件
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: renderCommand.indexCount,
                indexType: .uint32,
                indexBuffer: modelData.indexBuffer,
                indexBufferOffset: renderCommand.startIndex * MemoryLayout<UInt32>.size
            )
        }
        
        encoder.popDebugGroup()
        print("🎭 玩家模型渲染完成")
    }
    
    /// 公共方法：切换玩家模型可见性（与三角形互斥显示）
    func togglePlayerModelVisibility() {
        isPlayerModelVisible.toggle()
        // 互斥逻辑：玩家模型和三角形不能同时显示
        isTestTriangleVisible = !isPlayerModelVisible
        
        if isPlayerModelVisible {
            print("🔄 切换到玩家模型显示，隐藏三角形和第一人称武器/手臂")
            // 当显示3D玩家模型时，隐藏第一人称武器和手臂
            GameEngine.shared.setWeaponVisible(false)
            GameEngine.shared.setArmsVisible(false)
        } else {
            print("🔄 切换到三角形显示，隐藏玩家模型，显示第一人称武器/手臂")
            // 当显示三角形时，显示第一人称武器和手臂
            GameEngine.shared.setWeaponVisible(true)
            GameEngine.shared.setArmsVisible(true)
        }
    }

    /// 渲染三角形（测试方法）
    func renderTestTriangle() {
        // 检查三角形是否应该可见
        guard isTestTriangleVisible else { 
            print("🔍 三角形不可见,跳过渲染")
            return 
        }
        
        guard let (renderEncoder, commandBuffer) = beginFrame() else { return }
        
        // 更新Uniform缓冲区
        updateUniformsWithCamera()
        
        // 渲染测试三角形内容
        renderTestTriangleContent(encoder: renderEncoder)
        
        endFrame(renderEncoder: renderEncoder, commandBuffer: commandBuffer)
    }
    
    /// 重置三角形为首次出现状态（当Triangle菜单被选中时调用）
    func resetTriangleToFirstAppearance() {
        isTriangleFirstAppearance = true
        triangleCenterFrameCount = 0
        print("🔄 三角形状态重置为首次出现，将在中心位置显示 \(triangleCenterDuration) 帧")
    }
    
    /// 使用摄像机更新Uniforms
    private func updateUniformsWithCamera() {
        let uniformBuffer = getCurrentUniformBuffer()
        let uniformsPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
    // 同步基础光照数据（简单方向光 + 环境光），保证 fragment_basic_lighting 获得最新摄像机位置
    updateBasicLightingData()
        
        // 添加更详细的调试信息
        if currentFrameIndex % 60 == 0 {
            let allCameras = CameraSystem.shared.getAllCameras()
            print("🔍 摄像机调试: 注册摄像机数量=\(allCameras.count)")
        }
        
        // 获取主摄像机
        if let mainCamera = CameraSystem.shared.getMainCamera() {
            
            // 根据渲染内容设置模型矩阵
            if isPlayerModelVisible {
                // 基于包围盒自适应缩放与居中
                if let bb = playerModelBoundingBox {
                    let size = bb.size
                    let height = max(size.y, 0.0001)
                    let desiredHeight: Float = 2.0  // 目标高度（世界单位）
                    let scaleFactor = desiredHeight / height
                    // 包围盒中心（缩放后）
                    let centerX = (bb.min.x + bb.max.x) * 0.5 * scaleFactor
                    let centerY = (bb.min.y + bb.max.y) * 0.5 * scaleFactor
                    let centerZ = (bb.min.z + bb.max.z) * 0.5 * scaleFactor
                    // 让模型中心位于窗口中心 (0,0) ，并固定到 -5 的深度（不再额外偏移 centerZ，避免深度漂移）
                    let distance: Float = 5.0
                    let translation = Float4x4.translation(SIMD3<Float>(-centerX, -centerY, -distance))
                    let scale = Float4x4.scaling(SIMD3<Float>(repeating: scaleFactor))
                    var modelM = translation * scale
                    if enableAutoRotate {
                        autoRotateAngle += 0.01
                        modelM = modelM * Float4x4.rotationY(autoRotateAngle)
                    }
                    uniformsPointer.pointee.modelMatrix = modelM
                    if currentFrameIndex % 60 == 0 {
                        print("🎯 玩家模型居中: height=\(String(format: "%.3f", height)) scale=\(String(format: "%.3f", scaleFactor)) center=(\(centerX), \(centerY), \(centerZ)) dist=\(distance)")
                    }
                } else {
                    // 若无包围盒则使用后备矩阵
                    let translation = Float4x4.translation(SIMD3<Float>(0.0, 1.0, -5.0))
                    let scale = Float4x4.scaling(SIMD3<Float>(2.0, 2.0, 2.0))
                    uniformsPointer.pointee.modelMatrix = translation * scale
                }
            } else {
                uniformsPointer.pointee.modelMatrix = Float4x4(1.0)
            }
            
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

// MARK: - 基础光照数据填充
extension MetalRenderer {
    /// 填充一个基础的方向光和环境光，提升玩家模型立体感
    private func updateBasicLightingData() {
        guard let rawPtr = lightingDataBuffer?.contents() else { return }
        var data = BasicLightingData(
            ambientColor: SIMD3<Float>(0.18,0.19,0.21),
            cameraPosition: CameraSystem.shared.getMainCamera()?.position ?? SIMD3<Float>(0,0,5),
            lightDirection: normalize(SIMD3<Float>(0.4,-1.0,0.35)),
            lightIntensity: 2.6,
            lightColor: SIMD3<Float>(1.0,0.94,0.85)
        )
        memcpy(rawPtr, &data, MemoryLayout<BasicLightingData>.stride)
        if printedLightingDebugFrames < 3 {
            printedLightingDebugFrames += 1
            print("💡 BasicLightingData 写入: ambient=\(data.ambientColor) dir=\(data.lightDirection) intensity=\(data.lightIntensity) color=\(data.lightColor)")
        }
    }
}

// 与着色器 BasicLightingData 对应的CPU端结构
fileprivate struct BasicLightingData {
    var ambientColor: SIMD3<Float> = .zero; var padding0: Float = 0
    var cameraPosition: SIMD3<Float> = .zero; var padding1: Float = 0
    var lightDirection: SIMD3<Float> = SIMD3<Float>(0,-1,0); var lightIntensity: Float = 1
    var lightColor: SIMD3<Float> = SIMD3<Float>(1,1,1); var padding2: Float = 0
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
