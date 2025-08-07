//
//  RenderComponent.swift
//  MetalShooter
//
//  渲染组件 - 处理实体的可视化渲染
//  包含网格、材质、渲染状态等信息
//

import Foundation
import Metal
import simd

// MARK: - 渲染组件

/// 渲染组件 - 负责实体的可视化渲染
/// 包含网格数据、材质属性、渲染状态等
class RenderComponent: BaseComponent {
    
    // MARK: - ComponentType 协议
    override var category: ComponentCategory {
        return .rendering
    }
    
    // MARK: - 渲染资源
    
    /// 网格资源 (顶点、索引数据)
    var mesh: Mesh? {
        didSet {
            if mesh !== oldValue {
                needsUpdate = true
            }
        }
    }
    
    /// 材质资源 (着色器、纹理、参数)
    var material: MaterialProtocol? {
        didSet {
            if material !== oldValue {
                needsUpdate = true
            }
        }
    }
    
    // MARK: - 渲染状态
    
    /// 是否可见
    var isVisible: Bool = true {
        didSet {
            if isVisible != oldValue {
                needsUpdate = true
            }
        }
    }
    
    /// 渲染层级 (用于排序)
    var renderLayer: Int = 0 {
        didSet {
            if renderLayer != oldValue {
                needsUpdate = true
            }
        }
    }
    
    /// 渲染优先级 (同层级内的排序)
    var renderPriority: Int = 0 {
        didSet {
            if renderPriority != oldValue {
                needsUpdate = true
            }
        }
    }
    
    /// 是否投射阴影
    var castShadow: Bool = true
    
    /// 是否接收阴影
    var receiveShadow: Bool = true
    
    /// 是否启用背面剔除
    var cullBackFaces: Bool = true
    
    /// 深度测试模式
    var depthTestMode: DepthTestMode = .lessEqual
    
    /// 混合模式
    var blendMode: BlendMode = .opaque
    
    // MARK: - 包围盒和裁剪
    
    /// 本地空间包围盒 (由网格计算得出)
    var localBounds: AABB = AABB.zero {
        didSet {
            if localBounds != oldValue {
                boundsNeedUpdate = true
            }
        }
    }
    
    /// 世界空间包围盒 (缓存)
    private var _worldBounds: AABB = AABB.zero
    
    /// 包围盒是否需要更新
    private var boundsNeedUpdate: Bool = true
    
    /// 世界空间包围盒
    var worldBounds: AABB {
        if boundsNeedUpdate {
            updateWorldBounds()
        }
        return _worldBounds
    }
    
    /// 视锥裁剪结果 (缓存)
    var frustumCullingResult: FrustumCullingResult = .unknown
    
    /// 遮挡裁剪结果 (缓存)
    var occlusionCullingResult: OcclusionCullingResult = .unknown
    
    // MARK: - 实例化渲染支持
    
    /// 是否启用实例化渲染
    var useInstancing: Bool = false
    
    /// 实例化数据 (变换矩阵、颜色等)
    var instanceData: [InstanceData] = []
    
    /// 最大实例数量
    var maxInstances: Int = 1000
    
    // MARK: - LOD (细节层次) 支持
    
    /// LOD网格列表 (按距离排序，距离近的在前)
    var lodMeshes: [LODLevel] = []
    
    /// 当前使用的LOD级别
    private var currentLODLevel: Int = 0
    
    /// LOD距离阈值
    var lodDistances: [Float] = [10, 50, 100, 200]
    
    // MARK: - 动态属性
    
    /// 颜色调制 (与材质颜色相乘)
    var color: Float4 = Float4(1, 1, 1, 1)
    
    /// 透明度 (0-1)
    var alpha: Float = 1.0 {
        didSet {
            color.w = alpha
        }
    }
    
    /// UV偏移
    var uvOffset: Float2 = Float2.zero
    
    /// UV缩放
    var uvScale: Float2 = Float2(1, 1)
    
    /// 自定义着色器参数
    var shaderParameters: [String: Any] = [:]
    
    // MARK: - 缓存和优化
    
    /// 是否需要更新渲染状态
    var needsUpdate: Bool = true
    
    /// 上一帧的变换矩阵 (用于运动模糊)
    var previousTransformMatrix: Float4x4 = Float4x4.identity
    
    /// 渲染统计信息
    var renderStats: RenderStats = RenderStats()
    
    // MARK: - 初始化
    
    override init() {
        super.init()
        componentTags.insert(.renderable)
        updateLocalBounds()
    }
    
    /// 使用网格和材质初始化
    /// - Parameters:
    ///   - mesh: 网格资源
    ///   - material: 材质资源
    convenience init(mesh: Mesh?, material: MaterialProtocol?) {
        self.init()
        self.mesh = mesh
        self.material = material
        updateLocalBounds()
    }
    
    // MARK: - 组件生命周期
    
    override func awake() {
        super.awake()
        updateLocalBounds()
        needsUpdate = true
    }
    
    override func onEnable() {
        super.onEnable()
        needsUpdate = true
    }
    
    override func onDisable() {
        super.onDisable()
    }
    
    override func onDestroy() {
        // 清理渲染资源
        mesh = nil
        material = nil
        instanceData.removeAll()
        lodMeshes.removeAll()
        super.onDestroy()
    }
    
    // MARK: - 渲染方法
    
    /// 准备渲染 (在渲染前调用)
    /// - Parameter renderer: 渲染器引用
    func prepareForRender(with renderer: Renderer) {
        // 更新LOD
        if !lodMeshes.isEmpty {
            updateLOD(renderer: renderer)
        }
        
        // 更新包围盒
        if boundsNeedUpdate {
            updateWorldBounds()
        }
        
        // 更新渲染统计
        renderStats.frameCount += 1
        
        needsUpdate = false
    }
    
    /// 执行渲染
    /// - Parameters:
    ///   - encoder: Metal渲染编码器
    ///   - renderer: 渲染器引用
    func render(with encoder: MTLRenderCommandEncoder, renderer: Renderer) {
        guard isVisible && isEnabled else { return }
        guard let mesh = getCurrentMesh() else { return }
        guard let material = self.material else { return }
        
        // 设置材质
        material.bind(to: encoder)
        
        // 设置着色器参数
        setShaderUniforms(encoder: encoder, renderer: renderer)
        
        // 绘制网格
        if useInstancing && !instanceData.isEmpty {
            mesh.drawInstanced(with: encoder, instanceCount: instanceData.count)
        } else {
            mesh.draw(with: encoder)
        }
        
        // 更新统计
        renderStats.triangleCount += mesh.triangleCount
        renderStats.drawCallCount += 1
    }
    
    /// 获取当前应该使用的网格 (考虑LOD)
    /// - Returns: 当前网格
    private func getCurrentMesh() -> Mesh? {
        if !lodMeshes.isEmpty && currentLODLevel < lodMeshes.count {
            return lodMeshes[currentLODLevel].mesh
        }
        return mesh
    }
    
    /// 设置着色器全局参数
    /// - Parameters:
    ///   - encoder: 渲染编码器
    ///   - renderer: 渲染器引用
    private func setShaderUniforms(encoder: MTLRenderCommandEncoder, renderer: Renderer) {
        // 获取变换组件
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return
        }
        
        // 设置变换矩阵
        var modelMatrix = transform.worldMatrix
        encoder.setVertexBytes(&modelMatrix, length: MemoryLayout<Float4x4>.size, index: 0)
        
        // 设置颜色和UV参数
        var colorParam = color
        encoder.setFragmentBytes(&colorParam, length: MemoryLayout<Float4>.size, index: 0)
        
        var uvParams = Float4(uvOffset.x, uvOffset.y, uvScale.x, uvScale.y)
        encoder.setFragmentBytes(&uvParams, length: MemoryLayout<Float4>.size, index: 1)
        
        // 设置自定义参数
        setCustomShaderParameters(encoder: encoder)
    }
    
    /// 设置自定义着色器参数
    /// - Parameter encoder: 渲染编码器
    private func setCustomShaderParameters(encoder: MTLRenderCommandEncoder) {
        // TODO: 根据材质的着色器参数定义来设置
        // 这里可以根据 shaderParameters 字典来动态设置参数
    }
    
    // MARK: - LOD 管理
    
    /// 更新LOD级别
    /// - Parameter renderer: 渲染器
    private func updateLOD(renderer: Renderer) {
        guard !lodMeshes.isEmpty else { return }
        
        // 获取变换组件
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return
        }
        
        // 计算到摄像机的距离
        let cameraPosition = renderer.camera?.position ?? Float3.zero
        let distance = length(transform.worldPosition - cameraPosition)
        
        // 选择适当的LOD级别
        var newLODLevel = 0
        for (index, threshold) in lodDistances.enumerated() {
            if distance > threshold {
                newLODLevel = min(index + 1, lodMeshes.count - 1)
            } else {
                break
            }
        }
        
        if newLODLevel != currentLODLevel {
            currentLODLevel = newLODLevel
            needsUpdate = true
        }
    }
    
    /// 添加LOD级别
    /// - Parameters:
    ///   - mesh: LOD网格
    ///   - distance: 切换距离
    func addLODLevel(mesh: Mesh, distance: Float) {
        let lodLevel = LODLevel(mesh: mesh, distance: distance)
        lodMeshes.append(lodLevel)
        // 按距离排序
        lodMeshes.sort { $0.distance < $1.distance }
        updateLODDistances()
    }
    
    /// 更新LOD距离阈值
    private func updateLODDistances() {
        lodDistances = lodMeshes.map { $0.distance }
    }
    
    // MARK: - 包围盒管理
    
    /// 更新本地包围盒 (根据网格计算)
    private func updateLocalBounds() {
        guard let mesh = self.mesh else {
            localBounds = AABB.zero
            return
        }
        
        // 从网格计算包围盒
        localBounds = mesh.bounds
        boundsNeedUpdate = true
    }
    
    /// 更新世界空间包围盒
    private func updateWorldBounds() {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            _worldBounds = localBounds
            boundsNeedUpdate = false
            return
        }
        
        // 将本地包围盒变换到世界空间
        _worldBounds = localBounds.transformed(by: transform.worldMatrix)
        boundsNeedUpdate = false
    }
    
    // MARK: - 裁剪检测
    
    /// 执行视锥裁剪测试
    /// - Parameter frustum: 视锥体
    /// - Returns: 裁剪结果
    func performFrustumCulling(against frustum: Frustum) -> FrustumCullingResult {
        let result = frustum.intersects(worldBounds)
        frustumCullingResult = result
        return result
    }
    
    /// 执行遮挡裁剪测试 (简化版本)
    /// - Parameter occluders: 遮挡物列表
    /// - Returns: 裁剪结果
    func performOcclusionCulling(against occluders: [AABB]) -> OcclusionCullingResult {
        // 简化的遮挡检测：检查是否被任何遮挡物完全覆盖
        for occluder in occluders {
            if occluder.contains(worldBounds) {
                occlusionCullingResult = .culled
                return .culled
            }
        }
        
        occlusionCullingResult = .visible
        return .visible
    }
    
    // MARK: - 实例化渲染
    
    /// 添加实例数据
    /// - Parameter instance: 实例数据
    func addInstance(_ instance: InstanceData) {
        guard instanceData.count < maxInstances else {
            print("警告: 已达到最大实例数量 \(maxInstances)")
            return
        }
        instanceData.append(instance)
        useInstancing = true
        needsUpdate = true
    }
    
    /// 清除所有实例数据
    func clearInstances() {
        instanceData.removeAll()
        useInstancing = false
        needsUpdate = true
    }
    
    /// 更新实例数据
    /// - Parameters:
    ///   - index: 实例索引
    ///   - instance: 新的实例数据
    func updateInstance(at index: Int, with instance: InstanceData) {
        guard index >= 0 && index < instanceData.count else { return }
        instanceData[index] = instance
        needsUpdate = true
    }
    
    // MARK: - 工具方法
    
    /// 计算到点的距离 (使用包围盒中心)
    /// - Parameter point: 目标点
    /// - Returns: 距离
    func distanceTo(_ point: Float3) -> Float {
        return length(worldBounds.center - point)
    }
    
    /// 检查射线相交
    /// - Parameter ray: 射线
    /// - Returns: 相交信息，如果不相交返回 nil
    func rayIntersection(_ ray: Ray) -> RayHit? {
        // 首先与包围盒测试
        guard worldBounds.intersects(ray) != nil else { return nil }
        
        // 如果有网格，进行精确的三角形相交测试
        guard let mesh = getCurrentMesh() else { return nil }
        
        // 将射线变换到本地空间
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return nil
        }
        
        let localRay = ray.transformed(by: transform.worldMatrix.inverse)
        return mesh.rayIntersection(localRay)
    }
}

// MARK: - 支持类型定义

/// 深度测试模式
enum DepthTestMode {
    case never
    case less
    case equal
    case lessEqual
    case greater
    case notEqual
    case greaterEqual
    case always
}

/// 混合模式
enum BlendMode {
    case opaque        // 不透明
    case alphaBlend    // Alpha混合
    case additive      // 加法混合
    case multiply      // 乘法混合
    case screen        // 屏幕混合
}

/// 视锥裁剪结果
enum FrustumCullingResult {
    case unknown   // 未测试
    case inside    // 完全在视锥内
    case intersect // 与视锥相交
    case outside   // 完全在视锥外
}

/// 遮挡裁剪结果
enum OcclusionCullingResult {
    case unknown // 未测试
    case visible // 可见
    case culled  // 被遮挡
}

/// LOD级别
struct LODLevel {
    let mesh: Mesh
    let distance: Float
}

/// 实例数据
struct InstanceData {
    var transform: Float4x4
    var color: Float4
    var uvOffset: Float2
    var uvScale: Float2
    
    init(transform: Float4x4 = Float4x4.identity,
         color: Float4 = Float4(1, 1, 1, 1),
         uvOffset: Float2 = Float2.zero,
         uvScale: Float2 = Float2(1, 1)) {
        self.transform = transform
        self.color = color
        self.uvOffset = uvOffset
        self.uvScale = uvScale
    }
}

/// 渲染统计信息
struct RenderStats {
    var frameCount: Int = 0
    var drawCallCount: Int = 0
    var triangleCount: Int = 0
    var instanceCount: Int = 0
    
    mutating func reset() {
        drawCallCount = 0
        triangleCount = 0
        instanceCount = 0
    }
}

// MARK: - Mesh 协议 (临时定义，实际应该在单独的文件中)

/// 网格协议 - 定义网格的基本接口
protocol Mesh: AnyObject {
    var bounds: AABB { get }
    var triangleCount: Int { get }
    
    func draw(with encoder: MTLRenderCommandEncoder)
    func drawInstanced(with encoder: MTLRenderCommandEncoder, instanceCount: Int)
    func rayIntersection(_ ray: Ray) -> RayHit?
}

/// 材质协议 - 定义材质的基本接口
protocol MaterialProtocol: AnyObject {
    func bind(to encoder: MTLRenderCommandEncoder)
}

/// 渲染器协议 - 定义渲染器的基本接口
protocol Renderer: AnyObject {
    var camera: Camera? { get }
}

/// 摄像机协议 - 定义摄像机的基本接口
public protocol Camera: AnyObject {
    var position: Float3 { get set }
    var forward: Float3 { get }
    var up: Float3 { get }
    var right: Float3 { get }
    var nearClip: Float { get set }
    var farClip: Float { get set }
    var viewMatrix: simd_float4x4 { get }
    var projectionMatrix: simd_float4x4 { get }
}

/// 基础相机实现
public class BasicCamera: Camera {
    public var position: Float3
    public var forward: Float3
    public var up: Float3
    public var right: Float3
    public var nearClip: Float = 0.1
    public var farClip: Float = 100.0
    
    public var viewMatrix: simd_float4x4 {
        return lookAt(eye: position, target: position + forward, up: up)
    }
    
    public var projectionMatrix: simd_float4x4 {
        return perspective(fovY: .pi/4, aspect: 16.0/9.0, near: nearClip, far: farClip)
    }
    
    public init(position: Float3 = Float3(0, 0, 0)) {
        self.position = position
        self.forward = Float3(0, 0, -1)
        self.up = Float3(0, 1, 0)
        self.right = Float3(1, 0, 0)
    }
}

// MARK: - 矩阵辅助函数

private func lookAt(eye: Float3, target: Float3, up: Float3) -> simd_float4x4 {
    let z = normalize(eye - target)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    
    return simd_float4x4(
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    )
}

private func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let yScale = 1 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = far - near
    let zScale = -(far + near) / zRange
    let wzScale = -2 * far * near / zRange
    
    return simd_float4x4(
        SIMD4<Float>(xScale, 0, 0, 0),
        SIMD4<Float>(0, yScale, 0, 0),
        SIMD4<Float>(0, 0, zScale, -1),
        SIMD4<Float>(0, 0, wzScale, 0)
    )
}

/// 视锥体结构 - 用于视锥裁剪
struct Frustum {
    // TODO: 实现视锥体定义和相交测试
    func intersects(_ bounds: AABB) -> FrustumCullingResult {
        // 临时实现，总是返回内部
        return .inside
    }
}

/// 射线命中信息
struct RayHit {
    let point: Float3      // 命中点
    let normal: Float3     // 法线
    let distance: Float    // 距离
    let triangleIndex: Int // 三角形索引
}
