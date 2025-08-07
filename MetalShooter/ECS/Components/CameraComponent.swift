//
//  CameraComponent.swift
//  MetalShooter
//
//  摄像机组件 - 定义观察者视角和投影设置
//  支持透视投影、正交投影、视锥裁剪等功能
//

import Foundation
import simd

// MARK: - 摄像机组件

/// 摄像机组件 - 负责定义观察视角和投影变换
/// 提供透视/正交投影、视锥裁剪、屏幕射线等功能
class CameraComponent: BaseComponent {
    
    // MARK: - ComponentType 协议
    override var category: ComponentCategory {
        return .rendering
    }
    
    // MARK: - 投影设置
    
    /// 投影类型
    var projectionType: ProjectionType = .perspective {
        didSet {
            if projectionType != oldValue {
                markMatricesDirty()
            }
        }
    }
    
    /// 视野角度 (度数，仅透视投影使用)
    var fieldOfView: Float = 60.0 {
        didSet {
            if fieldOfView != oldValue {
                markMatricesDirty()
            }
        }
    }
    
    /// 正交投影大小 (仅正交投影使用)
    var orthographicSize: Float = 5.0 {
        didSet {
            if orthographicSize != oldValue {
                markMatricesDirty()
            }
        }
    }
    
    /// 宽高比
    var aspectRatio: Float = 16.0/9.0 {
        didSet {
            if aspectRatio != oldValue {
                markMatricesDirty()
            }
        }
    }
    
    /// 近裁剪平面
    var nearPlane: Float = 0.1 {
        didSet {
            if nearPlane != oldValue {
                markMatricesDirty()
            }
        }
    }
    
    /// 远裁剪平面
    var farPlane: Float = 1000.0 {
        didSet {
            if farPlane != oldValue {
                markMatricesDirty()
            }
        }
    }
    
    // MARK: - 渲染设置
    
    /// 渲染优先级 (数值越小越先渲染)
    var priority: Int = 0
    
    /// 清除颜色
    var clearColor: Float4 = Float4(0.2, 0.3, 0.4, 1.0)
    
    /// 清除标志
    var clearFlags: ClearFlags = [.color, .depth, .stencil]
    
    /// 渲染目标 (nil表示渲染到屏幕)
    var renderTarget: RenderTexture?
    
    /// 视口矩形 (归一化坐标 0-1)
    var viewport: ViewportRect = ViewportRect(x: 0, y: 0, width: 1, height: 1)
    
    /// 裁剪矩形 (像素坐标)
    var scissorRect: ScissorRect?
    
    // MARK: - 后处理设置
    
    /// 启用后处理
    var enablePostProcessing: Bool = false
    
    /// 后处理效果链
    var postProcessEffects: [PostProcessEffect] = []
    
    /// MSAA采样数
    var msaaSamples: Int = 1
    
    /// 启用HDR渲染
    var enableHDR: Bool = false
    
    // MARK: - 缓存的矩阵
    
    /// 投影矩阵 (缓存)
    private var _projectionMatrix: Float4x4?
    
    /// 视图矩阵 (缓存)
    private var _viewMatrix: Float4x4?
    
    /// 视图-投影矩阵 (缓存)
    private var _viewProjectionMatrix: Float4x4?
    
    /// 逆投影矩阵 (缓存)
    private var _inverseProjectionMatrix: Float4x4?
    
    /// 逆视图矩阵 (缓存)
    private var _inverseViewMatrix: Float4x4?
    
    /// 矩阵是否需要重新计算
    private var matricesDirty: Bool = true
    
    // MARK: - 视锥体
    
    /// 视锥体 (缓存)
    private var _frustum: CameraFrustum?
    
    /// 视锥体是否需要重新计算
    private var frustumDirty: Bool = true
    
    // MARK: - 计算属性
    
    /// 世界位置
    var position: Float3 {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return Float3.zero
        }
        return transform.worldPosition
    }
    
    /// 世界旋转
    var rotation: simd_quatf {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        return transform.worldRotation
    }
    
    /// 前方向量
    var forward: Float3 {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return Float3(0, 0, -1)
        }
        return transform.forward
    }
    
    /// 右方向量
    var right: Float3 {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return Float3(1, 0, 0)
        }
        return transform.right
    }
    
    /// 上方向量
    var up: Float3 {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return Float3(0, 1, 0)
        }
        return transform.up
    }
    
    /// 投影矩阵
    var projectionMatrix: Float4x4 {
        if matricesDirty || _projectionMatrix == nil {
            updateProjectionMatrix()
        }
        return _projectionMatrix!
    }
    
    /// 视图矩阵
    var viewMatrix: Float4x4 {
        if matricesDirty || _viewMatrix == nil {
            updateViewMatrix()
        }
        return _viewMatrix!
    }
    
    /// 视图-投影矩阵
    var viewProjectionMatrix: Float4x4 {
        if matricesDirty || _viewProjectionMatrix == nil {
            updateViewProjectionMatrix()
        }
        return _viewProjectionMatrix!
    }
    
    /// 逆投影矩阵
    var inverseProjectionMatrix: Float4x4 {
        if matricesDirty || _inverseProjectionMatrix == nil {
            updateInverseProjectionMatrix()
        }
        return _inverseProjectionMatrix!
    }
    
    /// 逆视图矩阵
    var inverseViewMatrix: Float4x4 {
        if matricesDirty || _inverseViewMatrix == nil {
            updateInverseViewMatrix()
        }
        return _inverseViewMatrix!
    }
    
    /// 视锥体
    var frustum: CameraFrustum {
        if frustumDirty || _frustum == nil {
            updateFrustum()
        }
        return _frustum!
    }
    
    // MARK: - 初始化
    
    override init() {
        super.init()
        componentTags.insert(.camera)
        markMatricesDirty()
    }
    
    /// 使用透视投影参数初始化
    /// - Parameters:
    ///   - fov: 视野角度
    ///   - aspectRatio: 宽高比
    ///   - nearPlane: 近裁剪平面
    ///   - farPlane: 远裁剪平面
    convenience init(fov: Float, aspectRatio: Float, nearPlane: Float, farPlane: Float) {
        self.init()
        self.projectionType = .perspective
        self.fieldOfView = fov
        self.aspectRatio = aspectRatio
        self.nearPlane = nearPlane
        self.farPlane = farPlane
    }
    
    /// 使用正交投影参数初始化
    /// - Parameters:
    ///   - size: 正交大小
    ///   - aspectRatio: 宽高比
    ///   - nearPlane: 近裁剪平面
    ///   - farPlane: 远裁剪平面
    convenience init(orthographicSize size: Float, aspectRatio: Float, nearPlane: Float, farPlane: Float) {
        self.init()
        self.projectionType = .orthographic
        self.orthographicSize = size
        self.aspectRatio = aspectRatio
        self.nearPlane = nearPlane
        self.farPlane = farPlane
    }
    
    // MARK: - 组件生命周期
    
    override func awake() {
        super.awake()
        markMatricesDirty()
    }
    
    override func onEnable() {
        super.onEnable()
        // 注册为激活摄像机
        CameraSystem.shared.registerCamera(self)
    }
    
    override func onDisable() {
        super.onDisable()
        // 取消注册摄像机
        CameraSystem.shared.unregisterCamera(self)
    }
    
    override func onDestroy() {
        CameraSystem.shared.unregisterCamera(self)
        postProcessEffects.removeAll()
        super.onDestroy()
    }
    
    // MARK: - 矩阵更新
    
    /// 标记矩阵为需要更新状态
    private func markMatricesDirty() {
        matricesDirty = true
        frustumDirty = true
        _projectionMatrix = nil
        _viewMatrix = nil
        _viewProjectionMatrix = nil
        _inverseProjectionMatrix = nil
        _inverseViewMatrix = nil
        _frustum = nil
    }
    
    /// 更新投影矩阵
    private func updateProjectionMatrix() {
        switch projectionType {
        case .perspective:
            _projectionMatrix = Float4x4.perspectiveProjection(
                fovy: fieldOfView * MathConstants.deg2Rad,
                aspect: aspectRatio,
                near: nearPlane,
                far: farPlane
            )
        case .orthographic:
            let width = orthographicSize * aspectRatio
            let height = orthographicSize
            _projectionMatrix = Float4x4.orthographicProjection(
                left: -width/2,
                right: width/2,
                bottom: -height/2,
                top: height/2,
                near: nearPlane,
                far: farPlane
            )
        }
    }
    
    /// 更新视图矩阵
    private func updateViewMatrix() {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            _viewMatrix = Float4x4.identity
            return
        }
        
        _viewMatrix = Float4x4.lookAt(
            eye: transform.worldPosition,
            center: transform.worldPosition + transform.forward,
            up: transform.up
        )
    }
    
    /// 更新视图-投影矩阵
    private func updateViewProjectionMatrix() {
        _viewProjectionMatrix = projectionMatrix * viewMatrix
    }
    
    /// 更新逆投影矩阵
    private func updateInverseProjectionMatrix() {
        _inverseProjectionMatrix = projectionMatrix.inverse
    }
    
    /// 更新逆视图矩阵
    private func updateInverseViewMatrix() {
        _inverseViewMatrix = viewMatrix.inverse
    }
    
    /// 更新视锥体
    private func updateFrustum() {
        _frustum = CameraFrustum(viewProjectionMatrix: viewProjectionMatrix)
        frustumDirty = false
    }
    
    // MARK: - 坐标系转换
    
    /// 将世界坐标转换为屏幕坐标
    /// - Parameters:
    ///   - worldPoint: 世界坐标点
    ///   - screenSize: 屏幕尺寸
    /// - Returns: 屏幕坐标 (像素), z为深度值
    func worldToScreenPoint(_ worldPoint: Float3, screenSize: Float2) -> Float3 {
        let clipPoint = viewProjectionMatrix * Float4(worldPoint, 1.0)
        let ndcPoint = clipPoint.xyz / clipPoint.w
        
        // 转换到屏幕坐标
        let screenX = (ndcPoint.x + 1.0) * 0.5 * screenSize.x
        let screenY = (1.0 - ndcPoint.y) * 0.5 * screenSize.y // 翻转Y轴
        
        return Float3(screenX, screenY, ndcPoint.z)
    }
    
    /// 将屏幕坐标转换为世界坐标射线
    /// - Parameters:
    ///   - screenPoint: 屏幕坐标 (像素)
    ///   - screenSize: 屏幕尺寸
    /// - Returns: 从摄像机发出的射线
    func screenPointToRay(_ screenPoint: Float2, screenSize: Float2) -> Ray {
        // 转换到归一化设备坐标 (-1 到 1)
        let ndcX = (screenPoint.x / screenSize.x) * 2.0 - 1.0
        let ndcY = 1.0 - (screenPoint.y / screenSize.y) * 2.0 // 翻转Y轴
        
        // 近平面和远平面点 (NDC空间)
        let nearPoint = Float4(ndcX, ndcY, -1.0, 1.0)
        let farPoint = Float4(ndcX, ndcY, 1.0, 1.0)
        
        // 转换到世界空间
        let invViewProj = viewProjectionMatrix.inverse
        let nearWorld = invViewProj * nearPoint
        let farWorld = invViewProj * farPoint
        
        let nearWorldPos = nearWorld.xyz / nearWorld.w
        let farWorldPos = farWorld.xyz / farWorld.w
        
        let direction = normalize(farWorldPos - nearWorldPos)
        
        return Ray(origin: nearWorldPos, direction: direction)
    }
    
    /// 将世界坐标转换为视口坐标 (0-1)
    /// - Parameter worldPoint: 世界坐标点
    /// - Returns: 视口坐标 (0-1范围)
    func worldToViewportPoint(_ worldPoint: Float3) -> Float3 {
        let clipPoint = viewProjectionMatrix * Float4(worldPoint, 1.0)
        let ndcPoint = clipPoint.xyz / clipPoint.w
        
        // 转换到视口坐标 (0-1)
        let viewportX = (ndcPoint.x + 1.0) * 0.5
        let viewportY = (1.0 - ndcPoint.y) * 0.5
        
        return Float3(viewportX, viewportY, ndcPoint.z)
    }
    
    /// 将视口坐标转换为世界坐标射线
    /// - Parameter viewportPoint: 视口坐标 (0-1范围)
    /// - Returns: 射线
    func viewportPointToRay(_ viewportPoint: Float2) -> Ray {
        let screenSize = Float2(1920, 1080) // 临时使用固定值，实际应该从渲染器获取
        let screenPoint = Float2(viewportPoint.x * screenSize.x, viewportPoint.y * screenSize.y)
        return screenPointToRay(screenPoint, screenSize: screenSize)
    }
    
    // MARK: - 视锥裁剪
    
    /// 检查点是否在视锥内
    /// - Parameter point: 世界坐标点
    /// - Returns: 是否在视锥内
    func isPointInFrustum(_ point: Float3) -> Bool {
        return frustum.containsPoint(point)
    }
    
    /// 检查球体是否与视锥相交
    /// - Parameters:
    ///   - center: 球心
    ///   - radius: 半径
    /// - Returns: 相交结果
    func frustumIntersectsSphere(_ center: Float3, radius: Float) -> FrustumIntersection {
        return frustum.intersectsSphere(center: center, radius: radius)
    }
    
    /// 检查包围盒是否与视锥相交
    /// - Parameter bounds: 包围盒
    /// - Returns: 相交结果
    func frustumIntersectsBounds(_ bounds: AABB) -> FrustumIntersection {
        return frustum.intersectsBounds(bounds)
    }
    
    // MARK: - 摄像机控制
    
    /// 看向目标
    /// - Parameters:
    ///   - target: 目标位置
    ///   - worldUp: 世界上方向
    func lookAt(_ target: Float3, worldUp: Float3 = Float3(0, 1, 0)) {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return
        }
        
        transform.lookAt(target, up: worldUp)
        markMatricesDirty()
    }
    
    /// 绕目标点旋转
    /// - Parameters:
    ///   - target: 目标点
    ///   - deltaYaw: 水平旋转角度
    ///   - deltaPitch: 垂直旋转角度
    func orbitAround(_ target: Float3, deltaYaw: Float, deltaPitch: Float) {
        guard let transform = EntityManager.shared.getComponent(TransformComponent.self, for: entityId) else {
            return
        }
        
        let currentPosition = transform.worldPosition
        let offset = currentPosition - target
        let distance = length(offset)
        
        // 计算新的角度
        let currentYaw = atan2(offset.x, offset.z)
        let currentPitch = asin(offset.y / distance)
        
        let newYaw = currentYaw + deltaYaw
        let newPitch = currentPitch + deltaPitch
        
        // 限制俯仰角
        let clampedPitch = max(-Float.pi/2 + 0.1, min(Float.pi/2 - 0.1, newPitch))
        
        // 计算新位置
        let newOffset = Float3(
            sin(newYaw) * cos(clampedPitch),
            sin(clampedPitch),
            cos(newYaw) * cos(clampedPitch)
        ) * distance
        
        transform.localPosition = target + newOffset
        transform.lookAt(target)
        markMatricesDirty()
    }
    
    // MARK: - 后处理
    
    /// 添加后处理效果
    /// - Parameter effect: 后处理效果
    func addPostProcessEffect(_ effect: PostProcessEffect) {
        postProcessEffects.append(effect)
        enablePostProcessing = true
    }
    
    /// 移除后处理效果
    /// - Parameter effect: 要移除的后处理效果
    func removePostProcessEffect(_ effect: PostProcessEffect) {
        postProcessEffects.removeAll { $0 === effect }
        enablePostProcessing = !postProcessEffects.isEmpty
    }
    
    /// 清除所有后处理效果
    func clearPostProcessEffects() {
        postProcessEffects.removeAll()
        enablePostProcessing = false
    }
    
    // MARK: - 工具方法
    
    /// 计算视锥体角点 (世界空间)
    /// - Returns: 8个角点的数组
    func getFrustumCorners() -> [Float3] {
        return frustum.getCorners()
    }
    
    /// 获取摄像机参数信息
    /// - Returns: 参数字典
    func getCameraInfo() -> [String: Any] {
        return [
            "position": position,
            "rotation": rotation,
            "projectionType": projectionType,
            "fieldOfView": fieldOfView,
            "aspectRatio": aspectRatio,
            "nearPlane": nearPlane,
            "farPlane": farPlane,
            "priority": priority,
            "clearColor": clearColor
        ]
    }
}

// MARK: - 支持类型定义

/// 投影类型
enum ProjectionType {
    case perspective   // 透视投影
    case orthographic  // 正交投影
}

/// 清除标志
struct ClearFlags: OptionSet {
    let rawValue: Int
    
    static let color = ClearFlags(rawValue: 1 << 0)
    static let depth = ClearFlags(rawValue: 1 << 1)
    static let stencil = ClearFlags(rawValue: 1 << 2)
}

/// 视口矩形
struct ViewportRect {
    var x: Float
    var y: Float
    var width: Float
    var height: Float
    
    init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 裁剪矩形
struct ScissorRect {
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    
    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 渲染纹理协议
protocol RenderTexture: AnyObject {
    var width: Int { get }
    var height: Int { get }
}

/// 后处理效果协议
protocol PostProcessEffect: AnyObject {
    func apply(input: RenderTexture, output: RenderTexture)
}

/// 摄像机系统 (单例，管理所有摄像机)
class CameraSystem {
    static let shared = CameraSystem()
    
    private var cameras: [CameraComponent] = []
    private let lock = NSLock()
    
    private init() {}
    
    func registerCamera(_ camera: CameraComponent) {
        lock.lock()
        defer { lock.unlock() }
        
        if !cameras.contains(where: { $0 === camera }) {
            cameras.append(camera)
            cameras.sort { $0.priority < $1.priority }
        }
    }
    
    func unregisterCamera(_ camera: CameraComponent) {
        lock.lock()
        defer { lock.unlock() }
        
        cameras.removeAll { $0 === camera }
    }
    
    func getMainCamera() -> CameraComponent? {
        lock.lock()
        defer { lock.unlock() }
        
        return cameras.first(where: { $0.isEnabled })
    }
    
    func getAllCameras() -> [CameraComponent] {
        lock.lock()
        defer { lock.unlock() }
        
        return cameras.filter { $0.isEnabled }
    }
}

/// 摄像机视锥体
struct CameraFrustum {
    private let planes: [Plane]
    private let corners: [Float3]
    
    init(viewProjectionMatrix: Float4x4) {
        // 从视图-投影矩阵提取视锥平面
        let m = viewProjectionMatrix
        
        // 提取6个平面 (左、右、下、上、近、远)
        var frustumPlanes: [Plane] = []
        
        // 左平面: m[3] + m[0]
        frustumPlanes.append(Plane(
            normal: normalize(Float3(m[0][3] + m[0][0], m[1][3] + m[1][0], m[2][3] + m[2][0])),
            distance: -(m[3][3] + m[3][0])
        ))
        
        // 右平面: m[3] - m[0]
        frustumPlanes.append(Plane(
            normal: normalize(Float3(m[0][3] - m[0][0], m[1][3] - m[1][0], m[2][3] - m[2][0])),
            distance: -(m[3][3] - m[3][0])
        ))
        
        // 下平面: m[3] + m[1]
        frustumPlanes.append(Plane(
            normal: normalize(Float3(m[0][3] + m[0][1], m[1][3] + m[1][1], m[2][3] + m[2][1])),
            distance: -(m[3][3] + m[3][1])
        ))
        
        // 上平面: m[3] - m[1]
        frustumPlanes.append(Plane(
            normal: normalize(Float3(m[0][3] - m[0][1], m[1][3] - m[1][1], m[2][3] - m[2][1])),
            distance: -(m[3][3] - m[3][1])
        ))
        
        // 近平面: m[3] + m[2]
        frustumPlanes.append(Plane(
            normal: normalize(Float3(m[0][3] + m[0][2], m[1][3] + m[1][2], m[2][3] + m[2][2])),
            distance: -(m[3][3] + m[3][2])
        ))
        
        // 远平面: m[3] - m[2]
        frustumPlanes.append(Plane(
            normal: normalize(Float3(m[0][3] - m[0][2], m[1][3] - m[1][2], m[2][3] - m[2][2])),
            distance: -(m[3][3] - m[3][2])
        ))
        
        self.planes = frustumPlanes
        
        // 计算8个角点
        var frustumCorners: [Float3] = []
        let invViewProj = viewProjectionMatrix.inverse
        
        // NDC空间的8个角点
        let ndcCorners: [Float3] = [
            Float3(-1, -1, -1), Float3(1, -1, -1), Float3(1, 1, -1), Float3(-1, 1, -1), // 近平面
            Float3(-1, -1, 1),  Float3(1, -1, 1),  Float3(1, 1, 1),  Float3(-1, 1, 1)   // 远平面
        ]
        
        for ndcCorner in ndcCorners {
            let worldCorner = invViewProj * Float4(ndcCorner, 1.0)
            frustumCorners.append(worldCorner.xyz / worldCorner.w)
        }
        
        self.corners = frustumCorners
    }
    
    func containsPoint(_ point: Float3) -> Bool {
        for plane in planes {
            if plane.distanceToPoint(point) < 0 {
                return false
            }
        }
        return true
    }
    
    func intersectsSphere(center: Float3, radius: Float) -> FrustumIntersection {
        var inside = true
        
        for plane in planes {
            let distance = plane.distanceToPoint(center)
            if distance < -radius {
                return .outside
            } else if distance < radius {
                inside = false
            }
        }
        
        return inside ? .inside : .intersecting
    }
    
    func intersectsBounds(_ bounds: AABB) -> FrustumIntersection {
        var inside = true
        
        for plane in planes {
            let result = bounds.classifyAgainstPlane(plane)
            switch result {
            case .behind:
                return .outside
            case .intersecting:
                inside = false
            case .inFront:
                break
            case .inside:
                break
            }
        }
        
        return inside ? .inside : .intersecting
    }
    
    func getCorners() -> [Float3] {
        return corners
    }
}

/// 视锥相交结果
enum FrustumIntersection {
    case outside      // 完全在外部
    case intersecting // 相交
    case inside       // 完全在内部
}
