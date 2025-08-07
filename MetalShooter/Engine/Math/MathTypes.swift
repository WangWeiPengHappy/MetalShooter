//
//  MathTypes.swift
//  MetalShooter
//
//  核心数学类型定义
//  为整个游戏引擎提供基础的数学类型和结构体
//

import simd
import Metal

// MARK: - 基础数学类型别名

/// 2D 浮点向量
public typealias Float2 = simd_float2

/// 3D 浮点向量 (位置、方向、颜色等)
public typealias Float3 = simd_float3

/// 4D 浮点向量 (颜色、齐次坐标等)
public typealias Float4 = simd_float4

/// 4x4 浮点矩阵 (变换矩阵)
public typealias Float4x4 = simd_float4x4

/// 四元数 (旋转表示)
public typealias Quaternion = simd_quatf

// MARK: - 顶点数据结构

/// 顶点数据结构，包含渲染所需的所有顶点属性
/// 与 Metal 着色器中的顶点结构体对应
/// 必须与 ShaderTypes.h 中的 VertexIn 结构完全一致
struct Vertex {
    /// 顶点位置 (世界空间) [[attribute(0)]]
    var position: Float3
    
    /// 顶点法线 (用于光照计算) [[attribute(1)]]
    var normal: Float3
    
    /// 纹理坐标 (UV 映射) [[attribute(2)]]
    var texCoords: Float2
    
    /// 顶点颜色 (RGBA) [[attribute(3)]]
    var color: Float4
    
    /// 切线 (用于法线贴图) [[attribute(4)]]
    var tangent: Float3
    
    /// 创建一个新的顶点
    /// - Parameters:
    ///   - position: 3D 位置
    ///   - normal: 法线向量
    ///   - texCoords: 纹理坐标
    ///   - color: 颜色值，默认为白色
    ///   - tangent: 切线向量，默认为X轴正方向
    init(position: Float3, 
         normal: Float3 = Float3(0, 1, 0), 
         texCoords: Float2 = Float2(0, 0), 
         color: Float4 = Float4(1, 1, 1, 1),
         tangent: Float3 = Float3(1, 0, 0)) {
        self.position = position
        self.normal = normalize(normal) // 确保法线单位化
        self.texCoords = texCoords
        self.color = color
        self.tangent = normalize(tangent) // 确保切线单位化
    }
}

// MARK: - 变换结构体

/// 3D 变换结构体，包含位置、旋转和缩放信息
/// 提供便捷的变换矩阵计算功能
struct Transform {
    /// 世界位置
    var position: Float3
    
    /// 旋转 (使用四元数表示)
    var rotation: Quaternion
    
    /// 缩放比例
    var scale: Float3
    
    /// 创建一个新的变换
    /// - Parameters:
    ///   - position: 位置，默认为原点
    ///   - rotation: 旋转，默认为无旋转
    ///   - scale: 缩放，默认为单位缩放
    init(position: Float3 = Float3(0, 0, 0),
         rotation: Quaternion = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
         scale: Float3 = Float3(1, 1, 1)) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
    
    /// 计算变换矩阵 (TRS: Translation * Rotation * Scale)
    var matrix: Float4x4 {
        let translationMatrix = Float4x4.translation(position)
        let rotationMatrix = Float4x4(rotation)
        let scaleMatrix = Float4x4.scaling(scale)
        
        return translationMatrix * rotationMatrix * scaleMatrix
    }
    
    /// 获取前进方向向量
    var forward: Float3 {
        return normalize(rotation.act(Float3(0, 0, -1)))
    }
    
    /// 获取右方向向量
    var right: Float3 {
        return normalize(rotation.act(Float3(1, 0, 0)))
    }
    
    /// 获取上方向向量
    var up: Float3 {
        return normalize(rotation.act(Float3(0, 1, 0)))
    }
}

// MARK: - 轴对齐包围盒

/// 轴对齐包围盒 (Axis-Aligned Bounding Box)
/// 用于碰撞检测和视锥体剔除
struct AABB {
    /// 包围盒最小点
    var min: Float3
    
    /// 包围盒最大点
    var max: Float3
    
    /// 创建一个新的 AABB
    /// - Parameters:
    ///   - min: 最小点
    ///   - max: 最大点
    init(min: Float3, max: Float3) {
        self.min = min
        self.max = max
    }
    
    /// 从中心点和尺寸创建 AABB
    /// - Parameters:
    ///   - center: 中心点
    ///   - size: 尺寸 (宽度、高度、深度)
    init(center: Float3, size: Float3) {
        let halfSize = size * 0.5
        self.min = center - halfSize
        self.max = center + halfSize
    }
    
    /// 包围盒中心点
    var center: Float3 {
        return (min + max) * 0.5
    }
    
    /// 包围盒尺寸
    var size: Float3 {
        return max - min
    }
    
    /// 检查点是否在包围盒内
    /// - Parameter point: 要检查的点
    /// - Returns: 如果点在包围盒内返回 true
    func contains(_ point: Float3) -> Bool {
        return point.x >= min.x && point.x <= max.x &&
               point.y >= min.y && point.y <= max.y &&
               point.z >= min.z && point.z <= max.z
    }
    
    /// 检查是否完全包含另一个包围盒
    /// - Parameter other: 另一个包围盒
    /// - Returns: 如果完全包含返回 true
    func contains(_ other: AABB) -> Bool {
        return min.x <= other.min.x && max.x >= other.max.x &&
               min.y <= other.min.y && max.y >= other.max.y &&
               min.z <= other.min.z && max.z >= other.max.z
    }
    
    /// 检查两个包围盒是否相交
    /// - Parameter other: 另一个包围盒
    /// - Returns: 如果相交返回 true
    func intersects(_ other: AABB) -> Bool {
        return !(max.x < other.min.x || min.x > other.max.x ||
                 max.y < other.min.y || min.y > other.max.y ||
                 max.z < other.min.z || min.z > other.max.z)
    }
}

// MARK: - 射线结构体

/// 射线结构体，用于射线检测和光线追踪
struct Ray {
    /// 射线起点
    var origin: Float3
    
    /// 射线方向 (单位向量)
    var direction: Float3
    
    /// 创建一个新的射线
    /// - Parameters:
    ///   - origin: 起点
    ///   - direction: 方向向量 (将被自动单位化)
    init(origin: Float3, direction: Float3) {
        self.origin = origin
        self.direction = normalize(direction)
    }
    
    /// 计算射线上指定距离的点
    /// - Parameter distance: 距离
    /// - Returns: 射线上的点
    func point(at distance: Float) -> Float3 {
        return origin + direction * distance
    }
}

// MARK: - 平面结构体

/// 平面结构体，用于平面方程和几何计算
struct Plane {
    /// 平面法线 (单位向量)
    var normal: Float3
    
    /// 平面距离原点的距离
    var distance: Float
    
    /// 创建一个新的平面
    /// - Parameters:
    ///   - normal: 法线向量 (将被自动单位化)
    ///   - distance: 距离
    init(normal: Float3, distance: Float) {
        self.normal = normalize(normal)
        self.distance = distance
    }
    
    /// 从三个点创建平面
    /// - Parameters:
    ///   - p1: 第一个点
    ///   - p2: 第二个点
    ///   - p3: 第三个点
    init(point1 p1: Float3, point2 p2: Float3, point3 p3: Float3) {
        let v1 = p2 - p1
        let v2 = p3 - p1
        self.normal = normalize(cross(v1, v2))
        self.distance = dot(self.normal, p1)
    }
    
    /// 计算点到平面的距离
    /// - Parameter point: 要计算的点
    /// - Returns: 带符号的距离 (正值表示在法线方向一侧)
    func distanceToPoint(_ point: Float3) -> Float {
        return dot(normal, point) - distance
    }
    
    /// 检查点是否在平面前方 (法线方向)
    /// - Parameter point: 要检查的点
    /// - Returns: 如果在前方返回 true
    func isPointInFront(_ point: Float3) -> Bool {
        return distanceToPoint(point) > 0
    }
}

// MARK: - 常用数学常量

/// 数学常量集合
enum MathConstants {
    /// π 值
    static let pi: Float = Float.pi
    
    /// π/2 值
    static let halfPi: Float = Float.pi * 0.5
    
    /// 2π 值
    static let twoPi: Float = Float.pi * 2.0
    
    /// 角度转弧度的转换系数
    static let deg2Rad: Float = Float.pi / 180.0
    
    /// 弧度转角度的转换系数
    static let rad2Deg: Float = 180.0 / Float.pi
    
    /// 浮点数比较的容忍值
    static let epsilon: Float = Float.ulpOfOne
}

// MARK: - Float4x4 扩展

extension Float4x4 {
    /// 创建单位矩阵
    static var identity: Float4x4 {
        return matrix_identity_float4x4
    }
    
    /// 创建平移矩阵
    /// - Parameter translation: 平移向量
    /// - Returns: 平移矩阵
    static func translation(_ translation: Float3) -> Float4x4 {
        var matrix = Float4x4.identity
        matrix.columns.3.x = translation.x
        matrix.columns.3.y = translation.y
        matrix.columns.3.z = translation.z
        return matrix
    }
    
    /// 创建缩放矩阵
    /// - Parameter scale: 缩放向量
    /// - Returns: 缩放矩阵
    static func scaling(_ scale: Float3) -> Float4x4 {
        var matrix = Float4x4.identity
        matrix.columns.0.x = scale.x
        matrix.columns.1.y = scale.y
        matrix.columns.2.z = scale.z
        return matrix
    }
    
    /// 创建围绕 X 轴的旋转矩阵
    /// - Parameter angle: 旋转角度 (弧度)
    /// - Returns: 旋转矩阵
    static func rotationX(_ angle: Float) -> Float4x4 {
        let cos = cosf(angle)
        let sin = sinf(angle)
        
        var matrix = Float4x4.identity
        matrix.columns.1.y = cos
        matrix.columns.1.z = sin
        matrix.columns.2.y = -sin
        matrix.columns.2.z = cos
        return matrix
    }
    
    /// 创建围绕 Y 轴的旋转矩阵
    /// - Parameter angle: 旋转角度 (弧度)
    /// - Returns: 旋转矩阵
    static func rotationY(_ angle: Float) -> Float4x4 {
        let cos = cosf(angle)
        let sin = sinf(angle)
        
        var matrix = Float4x4.identity
        matrix.columns.0.x = cos
        matrix.columns.0.z = -sin
        matrix.columns.2.x = sin
        matrix.columns.2.z = cos
        return matrix
    }
    
    /// 创建围绕 Z 轴的旋转矩阵
    /// - Parameter angle: 旋转角度 (弧度)
    /// - Returns: 旋转矩阵
    static func rotationZ(_ angle: Float) -> Float4x4 {
        let cos = cosf(angle)
        let sin = sinf(angle)
        
        var matrix = Float4x4.identity
        matrix.columns.0.x = cos
        matrix.columns.0.y = sin
        matrix.columns.1.x = -sin
        matrix.columns.1.y = cos
        return matrix
    }
    
    /// 从四元数创建旋转矩阵
    /// - Parameter quaternion: 四元数
    /// - Returns: 旋转矩阵
    static func rotation(from quaternion: simd_quatf) -> Float4x4 {
        return Float4x4(quaternion)
    }
    
    /// 创建透视投影矩阵
    /// - Parameters:
    ///   - fovy: 垂直视野角度 (弧度)
    ///   - aspect: 宽高比
    ///   - near: 近平面距离
    ///   - far: 远平面距离
    /// - Returns: 透视投影矩阵
    static func perspectiveProjection(fovy: Float, aspect: Float, near: Float, far: Float) -> Float4x4 {
        let yScale = 1.0 / tanf(fovy * 0.5)
        let xScale = yScale / aspect
        let zRange = near - far
        let zScale = (far + near) / zRange
        let wzScale = 2.0 * far * near / zRange
        
        var matrix = Float4x4()
        matrix.columns.0 = Float4(xScale, 0, 0, 0)
        matrix.columns.1 = Float4(0, yScale, 0, 0)
        matrix.columns.2 = Float4(0, 0, zScale, -1)
        matrix.columns.3 = Float4(0, 0, wzScale, 0)
        
        return matrix
    }
    
    /// 创建正交投影矩阵
    /// - Parameters:
    ///   - left: 左边界
    ///   - right: 右边界
    ///   - bottom: 下边界
    ///   - top: 上边界
    ///   - near: 近平面
    ///   - far: 远平面
    /// - Returns: 正交投影矩阵
    static func orthographicProjection(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Float4x4 {
        let width = right - left
        let height = top - bottom
        let depth = far - near
        
        var matrix = Float4x4.identity
        matrix.columns.0.x = 2.0 / width
        matrix.columns.1.y = 2.0 / height
        matrix.columns.2.z = -2.0 / depth
        matrix.columns.3.x = -(right + left) / width
        matrix.columns.3.y = -(top + bottom) / height
        matrix.columns.3.z = -(far + near) / depth
        
        return matrix
    }
    
    /// 创建观察矩阵 (Look-At)
    /// - Parameters:
    ///   - eye: 相机位置
    ///   - center: 观察目标点
    ///   - up: 上方向向量
    /// - Returns: 观察矩阵
    static func lookAt(eye: Float3, center: Float3, up: Float3) -> Float4x4 {
        let forward = normalize(center - eye)
        let right = normalize(cross(forward, up))
        let newUp = cross(right, forward)
        
        var matrix = Float4x4.identity
        matrix.columns.0 = Float4(right.x, newUp.x, -forward.x, 0)
        matrix.columns.1 = Float4(right.y, newUp.y, -forward.y, 0)
        matrix.columns.2 = Float4(right.z, newUp.z, -forward.z, 0)
        matrix.columns.3 = Float4(-dot(right, eye), -dot(newUp, eye), dot(forward, eye), 1)
        
        return matrix
    }
}

// MARK: - Float3 扩展

extension Float3 {
    /// 零向量
    static let zero = Float3(0, 0, 0)
    
    /// 单位向量 (1, 1, 1)
    static let one = Float3(1, 1, 1)
    
    /// 前向量 (0, 0, -1) - OpenGL/Metal 约定
    static let forward = Float3(0, 0, -1)
    
    /// 后向量 (0, 0, 1)
    static let back = Float3(0, 0, 1)
    
    /// 右向量 (1, 0, 0)
    static let right = Float3(1, 0, 0)
    
    /// 左向量 (-1, 0, 0)
    static let left = Float3(-1, 0, 0)
    
    /// 上向量 (0, 1, 0)
    static let up = Float3(0, 1, 0)
    
    /// 下向量 (0, -1, 0)
    static let down = Float3(0, -1, 0)
    
    /// 向量长度
    var length: Float {
        return simd.length(self)
    }
    
    /// 向量长度的平方 (避免开方运算)
    var lengthSquared: Float {
        return simd.length_squared(self)
    }
    
    /// 单位化向量
    var normalized: Float3 {
        return simd.normalize(self)
    }
    
    /// 就地单位化
    mutating func normalize() {
        self = normalized
    }
    
    /// 计算与另一个向量的距离
    /// - Parameter other: 另一个向量
    /// - Returns: 距离值
    func distance(to other: Float3) -> Float {
        return (self - other).length
    }
    
    /// 线性插值到另一个向量
    /// - Parameters:
    ///   - other: 目标向量
    ///   - t: 插值参数 [0, 1]
    /// - Returns: 插值结果
    func lerp(to other: Float3, t: Float) -> Float3 {
        return simd.mix(self, other, t: t)
    }
}

// MARK: - Float4 扩展

extension Float4 {
    /// 获取xyz分量作为Float3
    var xyz: Float3 {
        return Float3(x, y, z)
    }
}

// MARK: - Quaternion 扩展

extension Quaternion {
    /// 单位四元数 (无旋转)
    static let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    
    /// 从欧拉角创建四元数
    /// - Parameters:
    ///   - x: X轴旋转 (俯仰, Pitch)
    ///   - y: Y轴旋转 (偏航, Yaw)
    ///   - z: Z轴旋转 (翻滚, Roll)
    /// - Returns: 四元数
    static func fromEuler(x: Float, y: Float, z: Float) -> Quaternion {
        let qx = simd_quatf(angle: x, axis: Float3(1, 0, 0))
        let qy = simd_quatf(angle: y, axis: Float3(0, 1, 0))
        let qz = simd_quatf(angle: z, axis: Float3(0, 0, 1))
        return qy * qx * qz
    }
    
    /// 从轴角创建四元数
    /// - Parameters:
    ///   - axis: 旋转轴 (单位向量)
    ///   - angle: 旋转角度 (弧度)
    /// - Returns: 四元数
    static func fromAxisAngle(axis: Float3, angle: Float) -> Quaternion {
        return simd_quatf(angle: angle, axis: normalize(axis))
    }
    
    /// 球面线性插值到另一个四元数
    /// - Parameters:
    ///   - other: 目标四元数
    ///   - t: 插值参数 [0, 1]
    /// - Returns: 插值结果
    func slerp(to other: Quaternion, t: Float) -> Quaternion {
        return simd_slerp(self, other, t)
    }
}

// MARK: - AABB 扩展

extension AABB {
    /// 零大小的包围盒 (在原点)
    static var zero: AABB {
        return AABB(min: Float3.zero, max: Float3.zero)
    }
    
    /// 使 AABB 支持相等比较
    static func == (lhs: AABB, rhs: AABB) -> Bool {
        return lhs.min == rhs.min && lhs.max == rhs.max
    }
    
    /// 使 AABB 支持不等比较
    static func != (lhs: AABB, rhs: AABB) -> Bool {
        return !(lhs == rhs)
    }
    
    /// 通过变换矩阵变换包围盒
    /// - Parameter matrix: 变换矩阵
    /// - Returns: 变换后的包围盒
    func transformed(by matrix: Float4x4) -> AABB {
        // 变换8个顶点并找到新的边界
        let corners = [
            Float3(min.x, min.y, min.z),
            Float3(min.x, min.y, max.z),
            Float3(min.x, max.y, min.z),
            Float3(min.x, max.y, max.z),
            Float3(max.x, min.y, min.z),
            Float3(max.x, min.y, max.z),
            Float3(max.x, max.y, min.z),
            Float3(max.x, max.y, max.z)
        ]
        
        var newMin = Float3(repeating: Float.greatestFiniteMagnitude)
        var newMax = Float3(repeating: -Float.greatestFiniteMagnitude)
        
        for corner in corners {
            let transformedCorner = matrix * Float4(corner.x, corner.y, corner.z, 1.0)
            let point = Float3(transformedCorner.x, transformedCorner.y, transformedCorner.z)
            newMin = simd.min(newMin, point)
            newMax = simd.max(newMax, point)
        }
        
        return AABB(min: newMin, max: newMax)
    }
    
    /// 检查与射线是否相交
    /// - Parameter ray: 射线
    /// - Returns: 相交距离，如果不相交返回 nil
    func intersects(_ ray: Ray) -> Float? {
        let invDir = Float3(1.0 / ray.direction.x, 1.0 / ray.direction.y, 1.0 / ray.direction.z)
        
        let t1 = (min - ray.origin) * invDir
        let t2 = (max - ray.origin) * invDir
        
        let tMin = simd.min(t1, t2)
        let tMax = simd.max(t1, t2)
        
        let tNear = Swift.max(Swift.max(tMin.x, tMin.y), tMin.z)
        let tFar = Swift.min(Swift.min(tMax.x, tMax.y), tMax.z)
        
        if tNear > tFar || tFar < 0 {
            return nil
        }
        
        return tNear > 0 ? tNear : tFar
    }
    
    /// 与平面的分类结果
    enum PlaneClassification {
        case inFront      // 完全在平面前方
        case behind       // 完全在平面后方
        case intersecting // 与平面相交
        case inside       // 内部（用于其他情况）
    }
    
    /// 判断包围盒与平面的关系
    /// - Parameter plane: 平面
    /// - Returns: 分类结果
    func classifyAgainstPlane(_ plane: Plane) -> PlaneClassification {
        // 计算包围盒的8个顶点
        let corners = [
            Float3(min.x, min.y, min.z),
            Float3(min.x, min.y, max.z),
            Float3(min.x, max.y, min.z),
            Float3(min.x, max.y, max.z),
            Float3(max.x, min.y, min.z),
            Float3(max.x, min.y, max.z),
            Float3(max.x, max.y, min.z),
            Float3(max.x, max.y, max.z)
        ]
        
        var frontCount = 0
        var backCount = 0
        
        for corner in corners {
            let distance = plane.distanceToPoint(corner)
            if distance > 0 {
                frontCount += 1
            } else {
                backCount += 1
            }
        }
        
        if frontCount == 8 {
            return .inFront
        } else if backCount == 8 {
            return .behind
        } else {
            return .intersecting
        }
    }
}

// MARK: - Ray 扩展

extension Ray {
    /// 通过变换矩阵变换射线
    /// - Parameter matrix: 变换矩阵
    /// - Returns: 变换后的射线
    func transformed(by matrix: Float4x4) -> Ray {
        let transformedOrigin = matrix * Float4(origin.x, origin.y, origin.z, 1.0)
        let transformedDirection = matrix * Float4(direction.x, direction.y, direction.z, 0.0)
        
        return Ray(
            origin: Float3(transformedOrigin.x, transformedOrigin.y, transformedOrigin.z),
            direction: normalize(Float3(transformedDirection.x, transformedDirection.y, transformedDirection.z))
        )
    }
}
