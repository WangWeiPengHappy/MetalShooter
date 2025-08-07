//
//  Lights.swift
//  MetalShooter
//
//  Phase 3: 光源类实现
//  具体的光源类型：方向光、点光源、聚光灯
//

import simd
import Foundation

// MARK: - 基础光源协议

/// 基础光源协议
public protocol Light {
    var id: UUID { get }
    var color: SIMD3<Float> { get set }
    var intensity: Float { get set }
    var isEnabled: Bool { get set }
    
    func calculateLighting(at position: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float>
}

// MARK: - 方向光

/// 方向光 - 模拟太阳光等远距离光源
public class DirectionalLight: Light {
    
    // MARK: - 属性
    
    public let id = UUID()
    
    /// 光照方向 (单位向量)
    public var direction: SIMD3<Float> {
        didSet {
            direction = normalize(direction)
        }
    }
    
    /// 光照颜色
    public var color: SIMD3<Float>
    
    /// 光照强度
    public var intensity: Float
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    /// 是否投射阴影
    public var castsShadows: Bool = true
    
    /// 阴影偏移距离
    public var shadowBias: Float = 0.005
    
    // MARK: - 初始化
    
    public init(direction: SIMD3<Float>, color: SIMD3<Float>, intensity: Float = 1.0) {
        // 检查方向向量是否为零向量，如果是则使用默认方向
        let directionLength = length(direction)
        if directionLength > 0.001 {
            self.direction = normalize(direction)
        } else {
            // 使用默认向下方向
            self.direction = SIMD3<Float>(0, -1, 0)
        }
        self.color = color
        self.intensity = intensity
    }
    
    // MARK: - 光照计算
    
    public func calculateLighting(at position: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float> {
        guard isEnabled else { return SIMD3<Float>(0, 0, 0) }
        
        // 计算光照方向到表面的角度
        let lightDirection = -direction  // 光照方向的反方向
        let dotProduct = max(dot(normal, lightDirection), 0.0)
        
        // 计算漫反射光照
        return color * intensity * dotProduct
    }
    
    // MARK: - 数据转换
    
    public func getLightData() -> DirectionalLightData {
        return DirectionalLightData(
            direction: direction,
            intensity: isEnabled ? intensity : 0.0,
            color: color,
            padding: 0.0
        )
    }
    
    // MARK: - 调试
    
    public func debugDescription() -> String {
        return """
        DirectionalLight {
            ID: \(id)
            Direction: (\(direction.x), \(direction.y), \(direction.z))
            Color: (\(color.x), \(color.y), \(color.z))
            Intensity: \(intensity)
            Enabled: \(isEnabled)
            Casts Shadows: \(castsShadows)
        }
        """
    }
}

// MARK: - 点光源

/// 点光源 - 从一点向四周发射光线
public class PointLight: Light {
    
    // MARK: - 属性
    
    public let id = UUID()
    
    /// 光源位置
    public var position: SIMD3<Float>
    
    /// 光照颜色
    public var color: SIMD3<Float>
    
    /// 光照强度
    public var intensity: Float
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    /// 光照范围
    public var range: Float {
        didSet {
            range = max(range, 0.01) // 确保范围为正数
        }
    }
    
    /// 光照衰减参数
    public var attenuation: LightAttenuation = LightAttenuation()
    
    /// 是否投射阴影
    public var castsShadows: Bool = false
    
    // MARK: - 初始化
    
    public init(position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float = 1.0, range: Float = 10.0) {
        self.position = position
        self.color = color
        self.intensity = intensity
        self.range = max(range, 0.01)
    }
    
    // MARK: - 光照计算
    
    public func calculateLighting(at position: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float> {
        guard isEnabled else { return SIMD3<Float>(0, 0, 0) }
        
        // 计算从光源到表面点的向量
        let lightVector = self.position - position
        let distance = length(lightVector)
        
        // 超出范围则无光照
        guard distance <= range && distance > 0.001 else { return SIMD3<Float>(0, 0, 0) }
        
        let lightDirection = lightVector / distance  // 标准化光照方向
        let dotProduct = max(dot(normal, lightDirection), 0.0)
        
        // 计算距离衰减
        let distanceAttenuation = calculateAttenuation(distance: distance)
        
        // 计算最终光照
        return color * intensity * dotProduct * distanceAttenuation
    }
    
    private func calculateAttenuation(distance: Float) -> Float {
        // 使用物理上更准确的平方反比定律，加上线性和常量项
        let denominator = attenuation.constant + 
                         attenuation.linear * distance + 
                         attenuation.quadratic * distance * distance
        
        return min(1.0 / denominator, 1.0)
    }
    
    // MARK: - 数据转换
    
    public func getLightData() -> PointLightData {
        return PointLightData(
            position: position,
            intensity: isEnabled ? intensity : 0.0,
            color: color,
            range: range
        )
    }
    
    // MARK: - 调试
    
    public func debugDescription() -> String {
        return """
        PointLight {
            ID: \(id)
            Position: (\(position.x), \(position.y), \(position.z))
            Color: (\(color.x), \(color.y), \(color.z))
            Intensity: \(intensity)
            Range: \(range)
            Enabled: \(isEnabled)
            Casts Shadows: \(castsShadows)
        }
        """
    }
}

// MARK: - 聚光灯

/// 聚光灯 - 锥形光束
public class SpotLight: Light {
    
    // MARK: - 属性
    
    public let id = UUID()
    
    /// 光源位置
    public var position: SIMD3<Float>
    
    /// 光照方向 (单位向量)
    public var direction: SIMD3<Float> {
        didSet {
            direction = normalize(direction)
        }
    }
    
    /// 光照颜色
    public var color: SIMD3<Float>
    
    /// 光照强度
    public var intensity: Float
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    /// 光照范围
    public var range: Float {
        didSet {
            range = max(range, 0.01)
        }
    }
    
    /// 内锥角 (完全照亮区域的角度)
    public var innerConeAngle: Float {
        didSet {
            innerConeAngle = clamp(innerConeAngle, 0.0, Float.pi)
            // 确保内锥角不大于外锥角
            if innerConeAngle > outerConeAngle {
                outerConeAngle = innerConeAngle
            }
        }
    }
    
    /// 外锥角 (光照边界角度)
    public var outerConeAngle: Float {
        didSet {
            outerConeAngle = clamp(outerConeAngle, 0.0, Float.pi)
            // 确保外锥角不小于内锥角
            if outerConeAngle < innerConeAngle {
                innerConeAngle = outerConeAngle
            }
        }
    }
    
    /// 光照衰减参数
    public var attenuation: LightAttenuation = LightAttenuation()
    
    /// 是否投射阴影
    public var castsShadows: Bool = false
    
    // MARK: - 初始化
    
    public init(position: SIMD3<Float>, direction: SIMD3<Float>, color: SIMD3<Float>, 
                intensity: Float = 1.0, range: Float = 10.0, 
                innerConeAngle: Float = 0.5, outerConeAngle: Float = 0.7) {
        self.position = position
        self.direction = normalize(direction)
        self.color = color
        self.intensity = intensity
        self.range = max(range, 0.01)
        self.innerConeAngle = clamp(innerConeAngle, 0.0, Float.pi)
        self.outerConeAngle = clamp(max(outerConeAngle, innerConeAngle), 0.0, Float.pi)
    }
    
    // MARK: - 光照计算
    
    public func calculateLighting(at position: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float> {
        guard isEnabled else { return SIMD3<Float>(0, 0, 0) }
        
        // 计算从光源到表面点的向量
        let lightVector = self.position - position
        let distance = length(lightVector)
        
        // 超出范围则无光照
        guard distance <= range && distance > 0.001 else { return SIMD3<Float>(0, 0, 0) }
        
        let lightDirection = lightVector / distance
        let dotProduct = max(dot(normal, lightDirection), 0.0)
        
        // 计算聚光灯锥形衰减
        let spotDirection = -direction  // 聚光灯方向的反方向
        let spotAngle = acos(clamp(dot(lightDirection, spotDirection), -1.0, 1.0))
        
        // 计算锥形衰减
        let coneAttenuation = calculateConeAttenuation(angle: spotAngle)
        guard coneAttenuation > 0.0 else { return SIMD3<Float>(0, 0, 0) }
        
        // 计算距离衰减
        let distanceAttenuation = calculateAttenuation(distance: distance)
        
        // 计算最终光照
        return color * intensity * dotProduct * distanceAttenuation * coneAttenuation
    }
    
    private func calculateAttenuation(distance: Float) -> Float {
        let denominator = attenuation.constant + 
                         attenuation.linear * distance + 
                         attenuation.quadratic * distance * distance
        
        return min(1.0 / denominator, 1.0)
    }
    
    private func calculateConeAttenuation(angle: Float) -> Float {
        // 超出外锥角则无光照
        guard angle <= outerConeAngle else { return 0.0 }
        
        // 在内锥角内则完全照亮
        guard angle > innerConeAngle else { return 1.0 }
        
        // 在内外锥角之间进行平滑插值
        let factor = (outerConeAngle - angle) / (outerConeAngle - innerConeAngle)
        return smoothstep(0.0, 1.0, factor)
    }
    
    // MARK: - 数据转换
    
    public func getLightData() -> SpotLightData {
        return SpotLightData(
            position: position,
            intensity: isEnabled ? intensity : 0.0,
            direction: direction,
            range: range,
            color: color,
            innerConeAngle: cos(innerConeAngle), // 存储余弦值以提高着色器性能
            outerConeAngle: cos(outerConeAngle),
            padding1: 0.0,
            padding2: SIMD2<Float>(0, 0)
        )
    }
    
    // MARK: - 调试
    
    public func debugDescription() -> String {
        return """
        SpotLight {
            ID: \(id)
            Position: (\(position.x), \(position.y), \(position.z))
            Direction: (\(direction.x), \(direction.y), \(direction.z))
            Color: (\(color.x), \(color.y), \(color.z))
            Intensity: \(intensity)
            Range: \(range)
            Inner Cone: \(innerConeAngle * 180.0 / Float.pi)°
            Outer Cone: \(outerConeAngle * 180.0 / Float.pi)°
            Enabled: \(isEnabled)
            Casts Shadows: \(castsShadows)
        }
        """
    }
}

// MARK: - 支持结构和函数

/// 光照衰减参数
public struct LightAttenuation {
    var constant: Float = 1.0      // 常量衰减
    var linear: Float = 0.09       // 线性衰减
    var quadratic: Float = 0.032   // 二次衰减
    
    /// 根据光照范围计算合适的衰减参数
    static func forRange(_ range: Float) -> LightAttenuation {
        // 基于经验值的衰减参数
        if range <= 3.0 {
            return LightAttenuation(constant: 1.0, linear: 0.7, quadratic: 1.8)
        } else if range <= 8.0 {
            return LightAttenuation(constant: 1.0, linear: 0.35, quadratic: 0.44)
        } else if range <= 13.0 {
            return LightAttenuation(constant: 1.0, linear: 0.22, quadratic: 0.20)
        } else if range <= 20.0 {
            return LightAttenuation(constant: 1.0, linear: 0.14, quadratic: 0.07)
        } else if range <= 32.0 {
            return LightAttenuation(constant: 1.0, linear: 0.09, quadratic: 0.032)
        } else if range <= 50.0 {
            return LightAttenuation(constant: 1.0, linear: 0.07, quadratic: 0.017)
        } else if range <= 65.0 {
            return LightAttenuation(constant: 1.0, linear: 0.045, quadratic: 0.0075)
        } else if range <= 100.0 {
            return LightAttenuation(constant: 1.0, linear: 0.027, quadratic: 0.0028)
        } else if range <= 160.0 {
            return LightAttenuation(constant: 1.0, linear: 0.022, quadratic: 0.0019)
        } else if range <= 200.0 {
            return LightAttenuation(constant: 1.0, linear: 0.014, quadratic: 0.0007)
        } else if range <= 325.0 {
            return LightAttenuation(constant: 1.0, linear: 0.007, quadratic: 0.0002)
        } else {
            return LightAttenuation(constant: 1.0, linear: 0.0014, quadratic: 0.000007)
        }
    }
}

// MARK: - 数学辅助函数

private func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    return max(minValue, min(maxValue, value))
}

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
}
