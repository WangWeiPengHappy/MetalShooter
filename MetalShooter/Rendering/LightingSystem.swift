//
//  LightingSystem.swift
//  MetalShooter
//
//  Phase 3: 动态光照系统
//  支持方向光、点光源、聚光灯的高级光照系统
//

import Metal
import simd

/// 光照系统 - 管理场景中的所有光源
public class LightingSystem {
    
    // MARK: - 单例
    
    public static let shared = LightingSystem()
    
    // MARK: - 属性
    
    /// 最大光源数量
    public static let maxLightCount = 16
    
    /// 方向光列表
    internal var directionalLights: [DirectionalLight] = []
    
    /// 点光源列表
    internal var pointLights: [PointLight] = []
    
    /// 聚光灯列表
    internal var spotLights: [SpotLight] = []
    
    /// 环境光颜色
    public var ambientColor: SIMD3<Float> = SIMD3<Float>(0.05, 0.05, 0.05)
    
    /// 环境光强度
    public var ambientIntensity: Float = 0.1
    
    // MARK: - Metal缓冲区
    
    private var lightBuffer: MTLBuffer?
    private var device: MTLDevice?
    
    // MARK: - 初始化
    
    private init() {}
    
    /// 初始化光照系统
    public func initialize(device: MTLDevice) {
        self.device = device
        createLightBuffer()
        setupDefaultLighting()
        
        print("✅ LightingSystem initialized")
    }
    
    // MARK: - 光源管理
    
    /// 添加方向光
    @discardableResult
    public func addDirectionalLight(direction: SIMD3<Float>, color: SIMD3<Float>, intensity: Float = 1.0) -> DirectionalLight {
        let light = DirectionalLight(direction: normalize(direction), color: color, intensity: intensity)
        directionalLights.append(light)
        updateLightBuffer()
        
        print("💡 Added directional light")
        return light
    }
    
    /// 添加点光源
    @discardableResult
    public func addPointLight(position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float = 1.0, range: Float = 10.0) -> PointLight {
        let light = PointLight(position: position, color: color, intensity: intensity, range: range)
        pointLights.append(light)
        updateLightBuffer()
        
        print("💡 Added point light")
        return light
    }
    
    /// 添加聚光灯
    @discardableResult
    public func addSpotLight(position: SIMD3<Float>, direction: SIMD3<Float>, color: SIMD3<Float>, 
                           intensity: Float = 1.0, range: Float = 10.0, innerCone: Float = 0.5, outerCone: Float = 0.7) -> SpotLight {
        let light = SpotLight(
            position: position,
            direction: normalize(direction),
            color: color,
            intensity: intensity,
            range: range,
            innerConeAngle: innerCone,
            outerConeAngle: outerCone
        )
        spotLights.append(light)
        updateLightBuffer()
        
        print("💡 Added spot light")
        return light
    }
    
    /// 移除方向光
    public func removeDirectionalLight(_ light: DirectionalLight) {
        if let index = directionalLights.firstIndex(where: { $0.id == light.id }) {
            directionalLights.remove(at: index)
            updateLightBuffer()
            print("🗑️ Removed directional light")
        }
    }
    
    /// 移除点光源
    public func removePointLight(_ light: PointLight) {
        if let index = pointLights.firstIndex(where: { $0.id == light.id }) {
            pointLights.remove(at: index)
            updateLightBuffer()
            print("🗑️ Removed point light")
        }
    }
    
    /// 移除聚光灯
    public func removeSpotLight(_ light: SpotLight) {
        if let index = spotLights.firstIndex(where: { $0.id == light.id }) {
            spotLights.remove(at: index)
            updateLightBuffer()
            print("🗑️ Removed spot light")
        }
    }
    
    /// 根据ID移除光源（通用方法）
    public func removeLight(id: UUID) {
        // 尝试从方向光中移除
        if let index = directionalLights.firstIndex(where: { $0.id == id }) {
            directionalLights.remove(at: index)
            updateLightBuffer()
            print("🗑️ Removed directional light by ID: \(id)")
            return
        }
        
        // 尝试从点光源中移除
        if let index = pointLights.firstIndex(where: { $0.id == id }) {
            pointLights.remove(at: index)
            updateLightBuffer()
            print("🗑️ Removed point light by ID: \(id)")
            return
        }
        
        // 尝试从聚光灯中移除
        if let index = spotLights.firstIndex(where: { $0.id == id }) {
            spotLights.remove(at: index)
            updateLightBuffer()
            print("🗑️ Removed spot light by ID: \(id)")
            return
        }
        
        print("⚠️ Light with ID \(id) not found")
    }
    
    /// 清除所有光源
    public func clearAllLights() {
        directionalLights.removeAll()
        pointLights.removeAll()
        spotLights.removeAll()
        updateLightBuffer()
        
        print("🗑️ Cleared all lights")
    }
    
    // MARK: - 光源访问
    
    /// 获取所有方向光
    public func getDirectionalLights() -> [DirectionalLight] {
        return directionalLights
    }
    
    /// 获取所有点光源
    public func getPointLights() -> [PointLight] {
        return pointLights
    }
    
    /// 获取所有聚光灯
    public func getSpotLights() -> [SpotLight] {
        return spotLights
    }
    
    /// 获取光源总数
    public func getTotalLightCount() -> Int {
        return directionalLights.count + pointLights.count + spotLights.count
    }
    
    // MARK: - Metal缓冲区管理
    
    private func createLightBuffer() {
        guard let device = device else { return }
        
        let bufferSize = MemoryLayout<LightingData>.size
        lightBuffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared])
        lightBuffer?.label = "LightingBuffer"
    }
    
    internal func updateLightBuffer() {
        guard let buffer = lightBuffer else { return }
        
        let lightingData = createLightingData()
        let bufferPointer = buffer.contents().bindMemory(to: LightingData.self, capacity: 1)
        bufferPointer.pointee = lightingData
    }
    
    private func createLightingData() -> LightingData {
        var data = LightingData()
        
        // 设置环境光
        data.ambientColor = SIMD4<Float>(ambientColor.x, ambientColor.y, ambientColor.z, ambientIntensity)
        
        // 设置光源数量
        data.directionalLightCount = min(Int32(directionalLights.count), Int32(LightingSystem.maxLightCount))
        data.pointLightCount = min(Int32(pointLights.count), Int32(LightingSystem.maxLightCount))
        data.spotLightCount = min(Int32(spotLights.count), Int32(LightingSystem.maxLightCount))
        
        // 填充方向光数据
        for (index, light) in directionalLights.enumerated() {
            if index >= LightingSystem.maxLightCount { break }
            data.directionalLights[index] = light.getLightData()
        }
        
        // 填充点光源数据
        for (index, light) in pointLights.enumerated() {
            if index >= LightingSystem.maxLightCount { break }
            data.pointLights[index] = light.getLightData()
        }
        
        // 填充聚光灯数据
        for (index, light) in spotLights.enumerated() {
            if index >= LightingSystem.maxLightCount { break }
            data.spotLights[index] = light.getLightData()
        }
        
        return data
    }
    
    /// 获取光照缓冲区
    public func getLightBuffer() -> MTLBuffer? {
        return lightBuffer
    }
    
    // MARK: - 默认光照设置
    
    private func setupDefaultLighting() {
        // 添加默认的主方向光（太阳光）
        addDirectionalLight(
            direction: SIMD3<Float>(-0.3, -0.8, -0.5),
            color: SIMD3<Float>(1.0, 0.95, 0.8),
            intensity: 3.0
        )
        
        // 添加补光（天空光）
        addDirectionalLight(
            direction: SIMD3<Float>(0.2, 0.5, 0.3),
            color: SIMD3<Float>(0.5, 0.7, 1.0),
            intensity: 0.5
        )
        
        print("🌟 Default lighting setup complete")
    }
    
    // MARK: - 光照计算辅助
    
    /// 计算点在所有光源下的光照强度
    public func calculateLightingAtPoint(_ position: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float> {
        var totalLight = ambientColor * ambientIntensity
        
        // 计算方向光贡献
        for light in directionalLights {
            let lightContribution = light.calculateLighting(at: position, normal: normal)
            totalLight += lightContribution
        }
        
        // 计算点光源贡献
        for light in pointLights {
            let lightContribution = light.calculateLighting(at: position, normal: normal)
            totalLight += lightContribution
        }
        
        // 计算聚光灯贡献
        for light in spotLights {
            let lightContribution = light.calculateLighting(at: position, normal: normal)
            totalLight += lightContribution
        }
        
        return totalLight
    }
    
    // MARK: - 调试和统计
    
    public func getDebugInfo() -> String {
        return """
        LightingSystem Debug Info:
        - Directional Lights: \(directionalLights.count)
        - Point Lights: \(pointLights.count)
        - Spot Lights: \(spotLights.count)
        - Total Lights: \(getTotalLightCount())
        - Ambient Color: (\(ambientColor.x), \(ambientColor.y), \(ambientColor.z))
        - Ambient Intensity: \(ambientIntensity)
        """
    }
    
    /// 获取最亮的光源
    public func getBrightestLight() -> (type: String, intensity: Float)? {
        var brightest: (type: String, intensity: Float)? = nil
        
        for light in directionalLights {
            let intensity = light.intensity * length(light.color)
            if brightest == nil || intensity > brightest!.intensity {
                brightest = ("Directional", intensity)
            }
        }
        
        for light in pointLights {
            let intensity = light.intensity * length(light.color)
            if brightest == nil || intensity > brightest!.intensity {
                brightest = ("Point", intensity)
            }
        }
        
        for light in spotLights {
            let intensity = light.intensity * length(light.color)
            if brightest == nil || intensity > brightest!.intensity {
                brightest = ("Spot", intensity)
            }
        }
        
        return brightest
    }
}

// MARK: - 光照数据结构 (与ShaderTypes.h对应)

/// 光照系统数据结构
public struct LightingData {
    var ambientColor: SIMD4<Float> = SIMD4<Float>(0.05, 0.05, 0.05, 0.1)
    
    var directionalLightCount: Int32 = 0
    var pointLightCount: Int32 = 0
    var spotLightCount: Int32 = 0
    var padding: Int32 = 0
    
    var directionalLights: [DirectionalLightData] = Array(repeating: DirectionalLightData(), count: LightingSystem.maxLightCount)
    var pointLights: [PointLightData] = Array(repeating: PointLightData(), count: LightingSystem.maxLightCount)
    var spotLights: [SpotLightData] = Array(repeating: SpotLightData(), count: LightingSystem.maxLightCount)
}

/// 方向光数据
public struct DirectionalLightData {
    var direction: SIMD3<Float> = SIMD3<Float>(0, -1, 0)
    var intensity: Float = 1.0
    var color: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    var padding: Float = 0.0
}

/// 点光源数据
public struct PointLightData {
    var position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var intensity: Float = 1.0
    var color: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    var range: Float = 10.0
}

/// 聚光灯数据
public struct SpotLightData {
    var position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var intensity: Float = 1.0
    var direction: SIMD3<Float> = SIMD3<Float>(0, -1, 0)
    var range: Float = 10.0
    var color: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    var innerConeAngle: Float = 0.5
    var outerConeAngle: Float = 0.7
    var padding1: Float = 0.0
    var padding2: SIMD2<Float> = SIMD2<Float>(0, 0)
}
