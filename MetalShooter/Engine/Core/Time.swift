//
//  Time.swift
//  MetalShooter
//
//  时间管理系统
//  提供游戏循环时间控制、帧率计算和时间相关功能
//

import Foundation
import QuartzCore

/// 时间管理器 - 负责游戏中的时间计算和管理
/// 使用单例模式确保全局统一的时间状态
class Time {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = Time()
    
    /// 私有初始化器，确保单例模式
    private init() {
        reset()
    }
    
    // MARK: - 私有属性
    
    /// 上一帧的时间戳
    private var lastFrameTime: CFTimeInterval = 0
    
    /// 游戏开始时间
    private var startTime: CFTimeInterval = 0
    
    /// 当前帧的增量时间
    private var _deltaTime: Float = 0
    
    /// 从游戏开始的总时间
    private var _totalTime: Float = 0
    
    /// 当前帧数
    private var _frameCount: UInt64 = 0
    
    /// FPS 计算相关
    private var fpsUpdateTimer: Float = 0
    private var fpsFrameCount: Int = 0
    private var _fps: Float = 0
    
    /// 时间缩放因子
    private var _timeScale: Float = 1.0
    
    /// 是否暂停
    private var _isPaused: Bool = false
    
    /// 最大允许的 deltaTime (防止时间跳跃)
    private let maxDeltaTime: Float = 0.1 // 100ms
    
    // MARK: - 公共只读属性
    
    /// 当前帧与上一帧之间的时间差 (秒)
    /// 已经应用了时间缩放和暂停状态
    var deltaTime: Float {
        return _isPaused ? 0 : _deltaTime * _timeScale
    }
    
    /// 原始的增量时间 (未应用时间缩放)
    var unscaledDeltaTime: Float {
        return _isPaused ? 0 : _deltaTime
    }
    
    /// 从游戏开始经过的总时间 (秒)
    /// 已经应用了时间缩放，但不受暂停影响
    var totalTime: Float {
        return _totalTime * _timeScale
    }
    
    /// 原始总时间 (未应用时间缩放)
    var unscaledTotalTime: Float {
        return _totalTime
    }
    
    /// 当前帧数
    var frameCount: UInt64 {
        return _frameCount
    }
    
    /// 当前 FPS (每秒更新一次)
    var fps: Float {
        return _fps
    }
    
    /// 时间缩放因子 (1.0 = 正常速度, 0.5 = 慢动作, 2.0 = 加速)
    var timeScale: Float {
        get { return _timeScale }
        set { 
            _timeScale = max(0, newValue) // 确保不为负数
        }
    }
    
    /// 游戏是否暂停
    var isPaused: Bool {
        get { return _isPaused }
        set { _isPaused = newValue }
    }
    
    // MARK: - 公共方法
    
    /// 更新时间 - 应该在每帧开始时调用
    /// 通常由 GameLoop 调用
    func update() {
        let currentTime = CACurrentMediaTime()
        
        // 如果是第一帧，初始化时间
        if lastFrameTime == 0 {
            lastFrameTime = currentTime
            startTime = currentTime
            return
        }
        
        // 计算增量时间
        let rawDeltaTime = Float(currentTime - lastFrameTime)
        
        // 限制最大 deltaTime，防止时间跳跃 (如调试断点、系统休眠等)
        _deltaTime = min(rawDeltaTime, maxDeltaTime)
        
        // 更新总时间 (只有在非暂停状态下才累加)
        if !_isPaused {
            _totalTime += _deltaTime
        }
        
        // 更新帧数
        _frameCount += 1
        
        // 更新 FPS
        updateFPS()
        
        // 记录当前时间作为下一帧的上一帧时间
        lastFrameTime = currentTime
    }
    
    /// 重置时间系统
    /// 将所有时间相关的数值重置为初始状态
    func reset() {
        lastFrameTime = 0
        startTime = 0
        _deltaTime = 0
        _totalTime = 0
        _frameCount = 0
        fpsUpdateTimer = 0
        fpsFrameCount = 0
        _fps = 0
        _timeScale = 1.0
        _isPaused = false
    }
    
    /// 启动时间系统
    /// 初始化时间系统并开始计时
    func start() {
        let currentTime = CACurrentMediaTime()
        startTime = currentTime
        lastFrameTime = currentTime
        _isPaused = false
    }
    
    /// 暂停游戏时间
    func pause() {
        _isPaused = true
    }
    
    /// 恢复游戏时间
    func resume() {
        _isPaused = false
        // 重置上一帧时间，防止暂停期间的时间跳跃
        lastFrameTime = CACurrentMediaTime()
    }
    
    /// 切换暂停状态
    func togglePause() {
        if _isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    // MARK: - 私有方法
    
    /// 更新 FPS 计算
    private func updateFPS() {
        fpsUpdateTimer += _deltaTime
        fpsFrameCount += 1
        
        // 每秒更新一次 FPS
        if fpsUpdateTimer >= 1.0 {
            _fps = Float(fpsFrameCount) / fpsUpdateTimer
            fpsUpdateTimer = 0
            fpsFrameCount = 0
        }
    }
}

// MARK: - 时间工具函数扩展

extension Time {
    /// 获取当前系统时间戳 (毫秒)
    /// 用于性能测量和日志记录
    static var systemTimeMilliseconds: UInt64 {
        return UInt64(CACurrentMediaTime() * 1000)
    }
    
    /// 获取当前系统时间戳 (微秒)
    /// 用于高精度性能测量
    static var systemTimeMicroseconds: UInt64 {
        return UInt64(CACurrentMediaTime() * 1_000_000)
    }
    
    /// 获取 UTC 时间戳
    /// 用于网络同步和数据记录
    static var utcTimestamp: TimeInterval {
        return Date().timeIntervalSince1970
    }
}

// MARK: - 时间相关的数学函数

extension Time {
    /// 平滑步进函数 - 创建平滑的过渡效果
    /// - Parameters:
    ///   - edge0: 起始边界
    ///   - edge1: 结束边界
    ///   - x: 输入值
    /// - Returns: 平滑插值结果 [0, 1]
    static func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
        let t = simd_clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    }
    
    /// 弹性函数 - 创建弹性动画效果
    /// - Parameter t: 时间参数 [0, 1]
    /// - Returns: 弹性值
    static func elastic(_ t: Float) -> Float {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        
        let p: Float = 0.3
        let a: Float = 1.0
        let s = p / 4.0
        
        return pow(2.0, -10.0 * t) * sin((t - s) * (2.0 * Float.pi) / p) + 1.0
    }
    
    /// 反弹函数 - 创建反弹动画效果
    /// - Parameter t: 时间参数 [0, 1]
    /// - Returns: 反弹值
    static func bounce(_ t: Float) -> Float {
        if t < (1.0 / 2.75) {
            return 7.5625 * t * t
        } else if t < (2.0 / 2.75) {
            let t2 = t - (1.5 / 2.75)
            return 7.5625 * t2 * t2 + 0.75
        } else if t < (2.5 / 2.75) {
            let t2 = t - (2.25 / 2.75)
            return 7.5625 * t2 * t2 + 0.9375
        } else {
            let t2 = t - (2.625 / 2.75)
            return 7.5625 * t2 * t2 + 0.984375
        }
    }
}

// MARK: - 时间测量工具

/// 简单的时间测量工具类
/// 用于性能分析和代码执行时间测量
class Stopwatch {
    private var startTime: CFTimeInterval = 0
    private var endTime: CFTimeInterval = 0
    private var isRunning: Bool = false
    
    /// 开始计时
    func start() {
        startTime = CACurrentMediaTime()
        isRunning = true
    }
    
    /// 停止计时
    func stop() {
        if isRunning {
            endTime = CACurrentMediaTime()
            isRunning = false
        }
    }
    
    /// 重置计时器
    func reset() {
        startTime = 0
        endTime = 0
        isRunning = false
    }
    
    /// 获取经过的时间 (秒)
    var elapsedSeconds: Float {
        if isRunning {
            return Float(CACurrentMediaTime() - startTime)
        } else {
            return Float(endTime - startTime)
        }
    }
    
    /// 获取经过的时间 (毫秒)
    var elapsedMilliseconds: Float {
        return elapsedSeconds * 1000
    }
    
    /// 获取经过的时间 (微秒)
    var elapsedMicroseconds: Float {
        return elapsedSeconds * 1_000_000
    }
}

// MARK: - 使用示例和注释

/*
 Time 系统使用示例:
 
 // 在 GameLoop 中每帧调用
 Time.shared.update()
 
 // 获取当前帧时间
 let dt = Time.shared.deltaTime
 
 // 移动物体
 transform.position += velocity * dt
 
 // 获取 FPS
 let fps = Time.shared.fps
 
 // 暂停/恢复游戏
 Time.shared.pause()
 Time.shared.resume()
 
 // 慢动作效果
 Time.shared.timeScale = 0.5
 
 // 性能测量
 let stopwatch = Stopwatch()
 stopwatch.start()
 // ... 执行代码 ...
 stopwatch.stop()
 print("执行时间: \(stopwatch.elapsedMilliseconds)ms")
 */
