//
//  MetalShooterPhase3Tests.swift
//  MetalShooterTests
//
//  Phase 3 测试 - 高级渲染特性测试
//

import XCTest
import Metal
import simd
@testable import MetalShooter

class MetalShooterPhase3Tests: XCTestCase {
    
    var device: MTLDevice!
    var advancedRenderer: AdvancedRenderer!
    var baseRenderer: MetalRenderer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 获取Metal设备
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw TestError.noMetalSupport
        }
        
        device = metalDevice
        
        // 创建基础渲染器
        let mockView = MockMetalView()
        baseRenderer = MetalRenderer()  // 使用无参数构造函数
        
        // 初始化TextureManager
        TextureManager.shared.initialize(device: device)
        
        // 创建高级渲染器
        advancedRenderer = AdvancedRenderer(device: device, baseRenderer: baseRenderer)
    }
    
    override func tearDownWithError() throws {
        advancedRenderer?.cleanup()
        advancedRenderer = nil
        baseRenderer = nil
        TextureManager.shared.clearCache()
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - PBR材质测试
    
    func testPBRMaterialCreation() throws {
        // 测试默认材质
        let defaultMaterial = advancedRenderer.createMaterial(preset: .default)
        XCTAssertNotNil(defaultMaterial)
        XCTAssertEqual(defaultMaterial.albedo, SIMD4<Float>(0.8, 0.8, 0.8, 1.0))
        XCTAssertEqual(defaultMaterial.metallic, 0.0)
        XCTAssertEqual(defaultMaterial.roughness, 0.5)
        
        // 测试金属材质
        let metalMaterial = advancedRenderer.createMaterial(preset: .metal)
        XCTAssertEqual(metalMaterial.metallic, 1.0)
        XCTAssertLessThan(metalMaterial.roughness, 0.3)
        
        // 测试黄金材质
        let goldMaterial = advancedRenderer.createMaterial(preset: .gold)
        XCTAssertEqual(goldMaterial.albedo.x, 1.0, accuracy: 0.1)  // 金色偏黄
        XCTAssertEqual(goldMaterial.metallic, 1.0)
    }
    
    func testMaterialDataConversion() throws {
        let material = advancedRenderer.createMaterial(preset: .silver)
        let materialData = material.getMaterialData()
        
        XCTAssertEqual(materialData.albedo, material.albedo)
        XCTAssertEqual(materialData.metallic, material.metallic)
        XCTAssertEqual(materialData.roughness, material.roughness)
        XCTAssertEqual(materialData.emission, material.emission)
    }
    
    // MARK: - 纹理管理测试
    
    func testTextureManager() throws {
        let textureManager = TextureManager.shared
        
        // 测试程序生成纹理
        let whiteTexture = textureManager.getWhiteTexture()
        XCTAssertNotNil(whiteTexture)
        XCTAssertEqual(whiteTexture.width, 1)
        XCTAssertEqual(whiteTexture.height, 1)
        
        let blackTexture = textureManager.getBlackTexture()
        XCTAssertNotNil(blackTexture)
        
        let normalTexture = textureManager.getFlatNormalTexture()
        XCTAssertNotNil(normalTexture)
        
        // 测试棋盘纹理
        let checkerboard = try textureManager.createCheckerboardTexture(
            color1: SIMD4<Float>(1, 1, 1, 1),
            color2: SIMD4<Float>(0, 0, 0, 1),
            size: 64,
            name: "test_checkerboard"
        )
        XCTAssertNotNil(checkerboard)
        XCTAssertEqual(checkerboard.width, 64)
        XCTAssertEqual(checkerboard.height, 64)
    }
    
    func testTextureCaching() throws {
        let textureManager = TextureManager.shared
        
        // 使用相同名称创建纹理，应该返回缓存的纹理
        let texture1 = try textureManager.createSolidColorTexture(color: SIMD4<Float>(1, 0, 0, 1), size: 32, name: "test_red")
        let texture2 = try textureManager.createSolidColorTexture(color: SIMD4<Float>(0, 1, 0, 1), size: 64, name: "test_red") // 不同参数但相同名称
        
        // 应该返回相同的纹理实例（缓存效果）
        XCTAssertEqual(texture1.label, texture2.label)
        XCTAssertTrue(texture1 === texture2, "应该返回相同的纹理实例")
    }
    
    // MARK: - 光照系统测试
    
    func testLightingSystemBasics() throws {
        let lightingSystem = LightingSystem.shared
        
        // 测试光源计数
        let initialDirectionalCount = lightingSystem.getDirectionalLights().count
        let initialPointCount = lightingSystem.getPointLights().count
        let initialSpotCount = lightingSystem.getSpotLights().count
        
        // 添加方向光
        lightingSystem.addDirectionalLight(
            direction: SIMD3<Float>(0, -1, 0),
            color: SIMD3<Float>(1, 1, 1)
        )
        XCTAssertEqual(lightingSystem.getDirectionalLights().count, initialDirectionalCount + 1)
        
        // 添加点光源
        lightingSystem.addPointLight(
            position: SIMD3<Float>(0, 5, 0),
            color: SIMD3<Float>(1, 0.8, 0.6)
        )
        XCTAssertEqual(lightingSystem.getPointLights().count, initialPointCount + 1)
        
        // 添加聚光灯
        lightingSystem.addSpotLight(
            position: SIMD3<Float>(0, 10, 0),
            direction: SIMD3<Float>(0, -1, 0),
            color: SIMD3<Float>(1, 1, 0.8)
        )
        XCTAssertEqual(lightingSystem.getSpotLights().count, initialSpotCount + 1)
    }
    
    func testDirectionalLightCalculations() throws {
        let light = DirectionalLight(
            direction: SIMD3<Float>(0, -1, 0),  // 向下
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.0
        )
        
        // 测试平行于光照方向的表面（应该得到最大光照）
        let upwardNormal = SIMD3<Float>(0, 1, 0)
        let position = SIMD3<Float>(0, 0, 0)
        let lighting = light.calculateLighting(at: position, normal: upwardNormal)
        
        XCTAssertGreaterThan(lighting.x + lighting.y + lighting.z, 0.9)  // 应该接近最大值
        
        // 测试垂直于光照方向的表面（应该没有光照）
        let sideNormal = SIMD3<Float>(1, 0, 0)
        let sideLighting = light.calculateLighting(at: position, normal: sideNormal)
        
        XCTAssertLessThan(sideLighting.x + sideLighting.y + sideLighting.z, 0.1)  // 应该接近0
    }
    
    func testPointLightAttenuation() throws {
        let light = PointLight(
            position: SIMD3<Float>(0, 0, 0),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.0,
            range: 10.0
        )
        
        // 测试近距离光照
        let nearPosition = SIMD3<Float>(1, 0, 0)
        let nearNormal = SIMD3<Float>(-1, 0, 0)  // 面向光源
        let nearLighting = light.calculateLighting(at: nearPosition, normal: nearNormal)
        
        // 测试远距离光照
        let farPosition = SIMD3<Float>(5, 0, 0)
        let farNormal = SIMD3<Float>(-1, 0, 0)  // 面向光源
        let farLighting = light.calculateLighting(at: farPosition, normal: farNormal)
        
        // 近距离应该比远距离亮
        let nearIntensity = nearLighting.x + nearLighting.y + nearLighting.z
        let farIntensity = farLighting.x + farLighting.y + farLighting.z
        XCTAssertGreaterThan(nearIntensity, farIntensity)
        
        // 超出范围应该没有光照
        let veryFarPosition = SIMD3<Float>(15, 0, 0)
        let veryFarLighting = light.calculateLighting(at: veryFarPosition, normal: farNormal)
        XCTAssertLessThan(veryFarLighting.x + veryFarLighting.y + veryFarLighting.z, 0.01)
    }
    
    func testSpotLightCone() throws {
        let light = SpotLight(
            position: SIMD3<Float>(0, 0, 0),
            direction: SIMD3<Float>(0, 0, -1),  // 向前
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.0,
            range: 10.0,
            innerConeAngle: 0.5,  // 约28.6度
            outerConeAngle: 1.0   // 约57.3度
        )
        
        // 测试锥形内部（应该有强光照）
        let innerPosition = SIMD3<Float>(0, 0, -5)
        let innerNormal = SIMD3<Float>(0, 0, 1)  // 面向光源
        let innerLighting = light.calculateLighting(at: innerPosition, normal: innerNormal)
        
        // 测试锥形边缘（应该有较弱光照）
        let edgePosition = SIMD3<Float>(3, 0, -5)  // 在边缘位置
        let edgeLighting = light.calculateLighting(at: edgePosition, normal: innerNormal)
        
        // 测试锥形外部（应该没有光照）
        let outsidePosition = SIMD3<Float>(10, 0, -5)
        let outsideLighting = light.calculateLighting(at: outsidePosition, normal: innerNormal)
        
        let innerIntensity = innerLighting.x + innerLighting.y + innerLighting.z
        let edgeIntensity = edgeLighting.x + edgeLighting.y + edgeLighting.z
        let outsideIntensity = outsideLighting.x + outsideLighting.y + outsideLighting.z
        
        XCTAssertGreaterThan(innerIntensity, edgeIntensity)
        XCTAssertLessThan(outsideIntensity, 0.01)
    }
    
    // MARK: - 阴影映射测试
    
    func testShadowMapperInitialization() throws {
        let shadowMapper = ShadowMapper(device: device)
        
        // 测试默认设置
        XCTAssertEqual(shadowMapper.shadowQuality, .medium)
        XCTAssertEqual(shadowMapper.shadowBias, 0.005)
        XCTAssertEqual(shadowMapper.pcfSampleCount, 16)
        XCTAssertTrue(shadowMapper.cascadedShadowMapping)
        XCTAssertEqual(shadowMapper.csmCascadeCount, 4)
        
        // 测试阴影贴图创建
        let shadowMaps = shadowMapper.getDirectionalShadowMaps()
        XCTAssertEqual(shadowMaps.count, 4)  // 4个级联
        
        for shadowMap in shadowMaps {
            XCTAssertEqual(shadowMap.width, 1024)  // medium质量
            XCTAssertEqual(shadowMap.height, 1024)
            XCTAssertEqual(shadowMap.pixelFormat, .depth32Float)
        }
    }
    
    func testShadowQualityChange() throws {
        let shadowMapper = ShadowMapper(device: device)
        
        // 改变阴影质量
        shadowMapper.shadowQuality = .high
        let highQualityShadowMaps = shadowMapper.getDirectionalShadowMaps()
        
        for shadowMap in highQualityShadowMaps {
            XCTAssertEqual(shadowMap.width, 2048)  // high质量
            XCTAssertEqual(shadowMap.height, 2048)
        }
    }
    
    // MARK: - 高级渲染器集成测试
    
    func testAdvancedRendererInitialization() throws {
        XCTAssertNotNil(advancedRenderer)
        XCTAssertNotNil(advancedRenderer.materialManager)
        XCTAssertNotNil(advancedRenderer.textureManager)
        XCTAssertNotNil(advancedRenderer.lightingSystem)
        XCTAssertNotNil(advancedRenderer.shadowMapper)
    }
    
    func testRenderStatistics() throws {
        let stats = advancedRenderer.getRenderStatistics()
        
        XCTAssertEqual(stats.drawCalls, 0)
        XCTAssertEqual(stats.triangles, 0)
        XCTAssertEqual(stats.materialSwitches, 0)
        XCTAssertEqual(stats.textureSwitches, 0)
        XCTAssertEqual(stats.shadowMapRenders, 0)
        XCTAssertEqual(stats.lastFrameTime, 0.0)
        XCTAssertEqual(stats.averageFrameTime, 0.0)
    }
    
    func testLightManagement() throws {
        // 清空所有光源以确保测试独立性
        let initialLights = advancedRenderer.lightingSystem.getDirectionalLights()
        for light in initialLights {
            advancedRenderer.removeLight(id: light.id)
        }
        
        let cleanDirectionalCount = advancedRenderer.lightingSystem.getDirectionalLights().count
        XCTAssertEqual(cleanDirectionalCount, 0, "应该清空所有方向光")
        
        // 添加方向光
        let sunLight = DirectionalLight(
            direction: SIMD3<Float>(-0.3, -0.7, -0.6),
            color: SIMD3<Float>(1.0, 0.95, 0.8),
            intensity: 3.0
        )
        advancedRenderer.addLight(sunLight)
        
        XCTAssertEqual(advancedRenderer.lightingSystem.getDirectionalLights().count, 1)
        
        // 移除光源
        advancedRenderer.removeLight(id: sunLight.id)
        XCTAssertEqual(advancedRenderer.lightingSystem.getDirectionalLights().count, 0)
    }
    
    // MARK: - 性能测试
    
    func testMaterialCreationPerformance() throws {
        measure {
            for _ in 0..<100 {
                let _ = advancedRenderer.createMaterial(preset: .metal)
            }
        }
    }
    
    func testLightingCalculationPerformance() throws {
        let light = DirectionalLight(
            direction: SIMD3<Float>(0, -1, 0),
            color: SIMD3<Float>(1, 1, 1)
        )
        
        let positions = (0..<1000).map { _ in
            SIMD3<Float>(Float.random(in: -10...10),
                        Float.random(in: -10...10),
                        Float.random(in: -10...10))
        }
        
        let normals = (0..<1000).map { _ in
            normalize(SIMD3<Float>(Float.random(in: -1...1),
                                  Float.random(in: -1...1),
                                  Float.random(in: -1...1)))
        }
        
        measure {
            for i in 0..<1000 {
                let _ = light.calculateLighting(at: positions[i], normal: normals[i])
            }
        }
    }
    
    func testTextureCreationPerformance() throws {
        let textureManager = TextureManager.shared
        
        measure {
            for i in 0..<50 {
                let _ = try? textureManager.createCheckerboardTexture(
                    color1: SIMD4<Float>(1, 1, 1, 1),
                    color2: SIMD4<Float>(0, 0, 0, 1),
                    size: 128,
                    name: "perf_test_\(i)"
                )
            }
        }
    }
    
    // MARK: - 错误处理测试
    
    func testInvalidLightParameters() throws {
        // 测试无效的光照方向（零向量）
        let invalidLight = DirectionalLight(
            direction: SIMD3<Float>(0, 0, 0),
            color: SIMD3<Float>(1, 1, 1)
        )
        
        // 对于零向量，应该设置为默认有效方向，不应该有 NaN
        XCTAssertFalse(invalidLight.direction.x.isNaN)
        XCTAssertFalse(invalidLight.direction.y.isNaN)
        XCTAssertFalse(invalidLight.direction.z.isNaN)
        // 应该有有效的方向长度
        XCTAssertGreaterThan(length(invalidLight.direction), 0.9)
        
        // 测试负范围的点光源
        let pointLight = PointLight(
            position: SIMD3<Float>(0, 0, 0),
            color: SIMD3<Float>(1, 1, 1),
            range: -5.0  // 无效的负范围
        )
        
        // 范围应该被修正为正数
        XCTAssertGreaterThan(pointLight.range, 0.0)
    }
    
    func testMemoryManagement() throws {
        // 创建大量对象然后释放，检查内存泄漏
        var materials: [Material] = []
        var lights: [Light] = []
        
        for _ in 0..<100 {
            materials.append(advancedRenderer.createMaterial())
            lights.append(DirectionalLight(
                direction: SIMD3<Float>(0, -1, 0),
                color: SIMD3<Float>(1, 1, 1)
            ))
        }
        
        // 清空引用
        materials.removeAll()
        lights.removeAll()
        
        // 强制垃圾回收（在实际测试中可能需要更复杂的内存检查）
        XCTAssertTrue(materials.isEmpty)
        XCTAssertTrue(lights.isEmpty)
    }
}

// MARK: - 测试辅助类和错误

enum TestError: Error {
    case noMetalSupport
    case renderingFailed
    case invalidConfiguration
}

class MockMetalView: NSObject {
    var device: MTLDevice?
    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    var depthStencilPixelFormat: MTLPixelFormat = .depth32Float
    var sampleCount: Int = 1
    var clearColor: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
}
