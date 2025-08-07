//
//  TextureManager.swift
//  MetalShooter
//
//  Phase 3: 纹理管理系统
//  高效的纹理加载、缓存和管理
//

import Metal
import MetalKit
import Foundation

/// 纹理管理器 - 负责纹理的加载、缓存和管理
public class TextureManager {
    
    // MARK: - 单例
    
    public static let shared = TextureManager()
    
    // MARK: - 属性
    
    private var device: MTLDevice?
    private var textureLoader: MTKTextureLoader?
    private var textureCache: [String: MTLTexture] = [:]
    private var loadingQueue = DispatchQueue(label: "com.metalshooter.texture.loading", qos: .userInitiated)
    
    // MARK: - 纹理加载选项
    
    private let defaultTextureOptions: [MTKTextureLoader.Option: Any] = [
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
        .generateMipmaps: true,
        .SRGB: false
    ]
    
    private let sRGBTextureOptions: [MTKTextureLoader.Option: Any] = [
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
        .generateMipmaps: true,
        .SRGB: true
    ]
    
    // MARK: - 初始化
    
    private init() {}
    
    /// 初始化纹理管理器
    public func initialize(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
        
        print("✅ TextureManager initialized")
    }
    
    // MARK: - 纹理加载 (同步)
    
    /// 同步加载纹理
    public func loadTexture(name: String, bundle: Bundle? = nil, options: TextureLoadOptions = .default) throws -> MTLTexture {
        // 检查缓存
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        guard let textureLoader = textureLoader else {
            throw TextureManagerError.notInitialized
        }
        
        // 准备加载选项
        let loadOptions = getTextureOptions(for: options)
        
        // 加载纹理
        let texture: MTLTexture
        do {
            texture = try textureLoader.newTexture(name: name, scaleFactor: 1.0, bundle: bundle, options: loadOptions)
        } catch {
            throw TextureManagerError.loadFailed(name, error)
        }
        
        // 缓存纹理
        textureCache[name] = texture
        
        print("🎨 Loaded texture: \(name) (\(texture.width)x\(texture.height))")
        return texture
    }
    
    /// 从文件路径加载纹理
    public func loadTexture(path: String, options: TextureLoadOptions = .default) throws -> MTLTexture {
        // 检查缓存
        let cacheKey = path
        if let cachedTexture = textureCache[cacheKey] {
            return cachedTexture
        }
        
        guard let textureLoader = textureLoader else {
            throw TextureManagerError.notInitialized
        }
        
        // 创建URL
        let url = URL(fileURLWithPath: path)
        let loadOptions = getTextureOptions(for: options)
        
        // 加载纹理
        let texture: MTLTexture
        do {
            texture = try textureLoader.newTexture(URL: url, options: loadOptions)
        } catch {
            throw TextureManagerError.loadFailed(path, error)
        }
        
        // 缓存纹理
        textureCache[cacheKey] = texture
        
        print("🎨 Loaded texture from path: \(path) (\(texture.width)x\(texture.height))")
        return texture
    }
    
    /// 从数据加载纹理
    public func loadTexture(data: Data, name: String, options: TextureLoadOptions = .default) throws -> MTLTexture {
        // 检查缓存
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        guard let textureLoader = textureLoader else {
            throw TextureManagerError.notInitialized
        }
        
        let loadOptions = getTextureOptions(for: options)
        
        // 加载纹理
        let texture: MTLTexture
        do {
            texture = try textureLoader.newTexture(data: data, options: loadOptions)
        } catch {
            throw TextureManagerError.loadFailed(name, error)
        }
        
        // 缓存纹理
        textureCache[name] = texture
        
        print("🎨 Loaded texture from data: \(name) (\(texture.width)x\(texture.height))")
        return texture
    }
    
    // MARK: - 纹理加载 (异步)
    
    /// 异步加载纹理
    public func loadTextureAsync(name: String, bundle: Bundle? = nil, options: TextureLoadOptions = .default, completion: @escaping (Result<MTLTexture, Error>) -> Void) {
        loadingQueue.async { [weak self] in
            do {
                let texture = try self?.loadTexture(name: name, bundle: bundle, options: options)
                DispatchQueue.main.async {
                    if let texture = texture {
                        completion(.success(texture))
                    } else {
                        completion(.failure(TextureManagerError.notInitialized))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 异步批量加载纹理
    public func loadTexturesAsync(names: [String], bundle: Bundle? = nil, options: TextureLoadOptions = .default, completion: @escaping (Result<[String: MTLTexture], Error>) -> Void) {
        loadingQueue.async { [weak self] in
            var loadedTextures: [String: MTLTexture] = [:]
            
            do {
                for name in names {
                    let texture = try self?.loadTexture(name: name, bundle: bundle, options: options)
                    if let texture = texture {
                        loadedTextures[name] = texture
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(loadedTextures))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 程序化纹理生成
    
    /// 创建单色纹理
    public func createSolidColorTexture(color: SIMD4<Float>, size: Int = 256, name: String) throws -> MTLTexture {
        // 检查缓存
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        guard let device = device else {
            throw TextureManagerError.notInitialized
        }
        
        // 创建纹理描述符
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw TextureManagerError.creationFailed
        }
        
        // 创建像素数据
        let pixelCount = size * size
        var pixels = Array(repeating: SIMD4<UInt8>(
            UInt8(color.x * 255),
            UInt8(color.y * 255),
            UInt8(color.z * 255),
            UInt8(color.w * 255)
        ), count: pixelCount)
        
        // 上传数据到纹理
        let region = MTLRegionMake2D(0, 0, size, size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: &pixels, bytesPerRow: size * 4)
        
        // 缓存纹理
        textureCache[name] = texture
        texture.label = name
        
        print("🎨 Created solid color texture: \(name) (\(size)x\(size))")
        return texture
    }
    
    /// 创建棋盘纹理
    public func createCheckerboardTexture(color1: SIMD4<Float>, color2: SIMD4<Float>, size: Int = 256, squares: Int = 8, name: String) throws -> MTLTexture {
        // 检查缓存
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        guard let device = device else {
            throw TextureManagerError.notInitialized
        }
        
        // 创建纹理描述符
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw TextureManagerError.creationFailed
        }
        
        // 创建棋盘数据
        var pixels: [SIMD4<UInt8>] = []
        let squareSize = size / squares
        
        let color1_u8 = SIMD4<UInt8>(
            UInt8(color1.x * 255),
            UInt8(color1.y * 255),
            UInt8(color1.z * 255),
            UInt8(color1.w * 255)
        )
        
        let color2_u8 = SIMD4<UInt8>(
            UInt8(color2.x * 255),
            UInt8(color2.y * 255),
            UInt8(color2.z * 255),
            UInt8(color2.w * 255)
        )
        
        for y in 0..<size {
            for x in 0..<size {
                let squareX = x / squareSize
                let squareY = y / squareSize
                let isOdd = (squareX + squareY) % 2 == 1
                pixels.append(isOdd ? color1_u8 : color2_u8)
            }
        }
        
        // 上传数据到纹理
        let region = MTLRegionMake2D(0, 0, size, size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixels, bytesPerRow: size * 4)
        
        // 生成mipmaps
        if let commandQueue = device.makeCommandQueue(),
           let commandBuffer = commandQueue.makeCommandBuffer(),
           let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.generateMipmaps(for: texture)
            blitEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        // 缓存纹理
        textureCache[name] = texture
        texture.label = name
        
        print("🎨 Created checkerboard texture: \(name) (\(size)x\(size))")
        return texture
    }
    
    /// 创建法线贴图 (平面法线)
    public func createFlatNormalTexture(name: String = "flat_normal", size: Int = 256) throws -> MTLTexture {
        // 检查缓存
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        guard let device = device else {
            throw TextureManagerError.notInitialized
        }
        
        // 创建纹理描述符
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw TextureManagerError.creationFailed
        }
        
        // 法线(0,0,1)对应RGB(128,128,255) - 向上的法线
        let normalPixel = SIMD4<UInt8>(128, 128, 255, 255)
        let pixelCount = size * size
        var pixels = Array(repeating: normalPixel, count: pixelCount)
        
        // 上传数据到纹理
        let region = MTLRegionMake2D(0, 0, size, size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: &pixels, bytesPerRow: size * 4)
        
        // 缓存纹理
        textureCache[name] = texture
        texture.label = name
        
        print("🎨 Created flat normal texture: \(name) (\(size)x\(size))")
        return texture
    }
    
    // MARK: - 缓存管理
    
    /// 获取缓存的纹理
    public func getCachedTexture(name: String) -> MTLTexture? {
        return textureCache[name]
    }
    
    /// 获取白色纹理（用于缺失的反照率纹理等）
    public func getWhiteTexture() -> MTLTexture {
        if let cached = textureCache["_white_texture"] {
            return cached
        }
        
        guard let device = device else {
            fatalError("TextureManager未初始化")
        }
        
        // 创建1x1白色纹理
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("无法创建白色纹理")
        }
        
        let whitePixel: [UInt8] = [255, 255, 255, 255]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1),
                       mipmapLevel: 0,
                       withBytes: whitePixel,
                       bytesPerRow: 4)
        
        textureCache["_white_texture"] = texture
        return texture
    }
    
    /// 获取黑色纹理（用于缺失的自发光纹理等）
    public func getBlackTexture() -> MTLTexture {
        if let cached = textureCache["_black_texture"] {
            return cached
        }
        
        guard let device = device else {
            fatalError("TextureManager未初始化")
        }
        
        // 创建1x1黑色纹理
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("无法创建黑色纹理")
        }
        
        let blackPixel: [UInt8] = [0, 0, 0, 255]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1),
                       mipmapLevel: 0,
                       withBytes: blackPixel,
                       bytesPerRow: 4)
        
        textureCache["_black_texture"] = texture
        return texture
    }
    
    /// 获取平面法线纹理（用于缺失的法线贴图）
    public func getFlatNormalTexture() -> MTLTexture {
        if let cached = textureCache["_flat_normal_texture"] {
            return cached
        }
        
        guard let device = device else {
            fatalError("TextureManager未初始化")
        }
        
        // 创建1x1平面法线纹理 (128, 128, 255, 255) = (0, 0, 1) 在法线空间
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("无法创建平面法线纹理")
        }
        
        let normalPixel: [UInt8] = [128, 128, 255, 255]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1),
                       mipmapLevel: 0,
                       withBytes: normalPixel,
                       bytesPerRow: 4)
        
        textureCache["_flat_normal_texture"] = texture
        return texture
    }
    
    /// 移除缓存的纹理
    public func removeCachedTexture(name: String) {
        textureCache.removeValue(forKey: name)
    }
    
    /// 清空所有缓存
    public func clearCache() {
        textureCache.removeAll()
        print("🗑️ TextureManager cache cleared")
    }
    
    /// 获取缓存统计信息
    public func getCacheStats() -> TextureCacheStats {
        let textureCount = textureCache.count
        var totalMemory: Int = 0
        
        for texture in textureCache.values {
            // 估算纹理内存使用 (简化计算)
            let bpp = getBytesPerPixel(for: texture.pixelFormat)
            totalMemory += texture.width * texture.height * bpp
        }
        
        return TextureCacheStats(textureCount: textureCount, totalMemoryMB: Float(totalMemory) / (1024.0 * 1024.0))
    }
    
    // MARK: - 辅助方法
    
    private func getTextureOptions(for options: TextureLoadOptions) -> [MTKTextureLoader.Option: Any] {
        switch options {
        case .default:
            return defaultTextureOptions
        case .sRGB:
            return sRGBTextureOptions
        case .noMipmaps:
            var opts = defaultTextureOptions
            opts[.generateMipmaps] = false
            return opts
        case .custom(let customOptions):
            return customOptions
        }
    }
    
    private func getBytesPerPixel(for pixelFormat: MTLPixelFormat) -> Int {
        switch pixelFormat {
        case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb:
            return 4
        case .bgra8Unorm, .bgra8Unorm_srgb:
            return 3
        case .rg8Unorm:
            return 2
        case .r8Unorm:
            return 1
        case .rgba16Float:
            return 8
        case .rgba32Float:
            return 16
        default:
            return 4 // 默认值
        }
    }
}

// MARK: - 支持类型和枚举

/// 纹理加载选项
public enum TextureLoadOptions {
    case `default`
    case sRGB
    case noMipmaps
    case custom([MTKTextureLoader.Option: Any])
}

/// 纹理管理器错误
public enum TextureManagerError: Error {
    case notInitialized
    case loadFailed(String, Error)
    case creationFailed
    
    var localizedDescription: String {
        switch self {
        case .notInitialized:
            return "TextureManager未初始化"
        case .loadFailed(let name, let error):
            return "纹理加载失败: \(name) - \(error.localizedDescription)"
        case .creationFailed:
            return "纹理创建失败"
        }
    }
}

/// 纹理缓存统计信息
public struct TextureCacheStats {
    let textureCount: Int
    let totalMemoryMB: Float
    
    func debugDescription() -> String {
        return "TextureCache: \(textureCount) textures, \(String(format: "%.2f", totalMemoryMB)) MB"
    }
}
