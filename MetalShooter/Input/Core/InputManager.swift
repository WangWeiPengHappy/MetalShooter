// InputManager.swift
// MetalShooter - 第三阶段输入管理系统
// 统一管理键盘、鼠标和游戏手柄输入

import Foundation
import simd
import Cocoa
import GameController

/// 输入管理器 - 统一处理所有输入设备
class InputManager {
    
    // MARK: - 单例
    static let shared = InputManager()
    private init() {
        setupInputHandling()
        setupGameControllerSupport()
    }
    
    // MARK: - 输入状态
    
    /// 键盘按键状态
    private var keyStates: [UInt16: Bool] = [:]
    
    /// 鼠标状态
    private var mouseState = MouseState()
    
    /// 游戏手柄状态
    private var gamepadState = GamepadState()
    
    /// 输入监听器列表
    private var inputListeners: [WeakInputListener] = []
    
    // MARK: - 公共接口
    
    /// 初始化输入管理器（用于设置窗口引用）
    func initialize(window: NSWindow) {
        print("🎮 InputManager: 使用窗口 \(window) 进行初始化")
    }
    
    /// 添加输入监听器
    func addInputListener(_ listener: InputListener) {
        // 清理失效的弱引用
        inputListeners.removeAll { $0.listener == nil }
        
        // 添加新监听器
        inputListeners.append(WeakInputListener(listener: listener))
        print("🎮 InputManager: 添加监听器，当前监听器数量: \(inputListeners.count)")
    }
    
    /// 移除输入监听器
    func removeInputListener(_ listener: InputListener) {
        inputListeners.removeAll { 
            $0.listener == nil || $0.listener === listener 
        }
        print("🎮 InputManager: 移除监听器，当前监听器数量: \(inputListeners.count)")
    }
    
    /// 清理资源
    func cleanup() {
        inputListeners.removeAll()
        keyStates.removeAll()
        mouseState = MouseState()
        gamepadState = GamepadState()
        print("🎮 InputManager: 清理完成")
    }
    
    // MARK: - 输入状态结构
    
    /// 鼠标状态
    struct MouseState {
        var position: SIMD2<Float> = SIMD2<Float>(0, 0)
        var delta: SIMD2<Float> = SIMD2<Float>(0, 0)
        var leftButton: Bool = false
        var rightButton: Bool = false
        var middleButton: Bool = false
        var scrollDelta: SIMD2<Float> = SIMD2<Float>(0, 0)
    }
    
    /// 游戏手柄状态
    struct GamepadState {
        var leftStick: SIMD2<Float> = SIMD2<Float>(0, 0)
        var rightStick: SIMD2<Float> = SIMD2<Float>(0, 0)
        var leftTrigger: Float = 0.0
        var rightTrigger: Float = 0.0
        var buttons: [String: Bool] = [:]
        var isConnected: Bool = false
    }
    
    // MARK: - 键盘映射
    
    /// 键盘按键映射
    enum KeyCode: UInt16, CaseIterable {
        case w = 13          // 前进
        case a = 0           // 左移  
        case s = 1           // 后退
        case d = 2           // 右移
        case space = 49      // 跳跃
        case leftShift = 56  // 冲刺
        case leftControl = 59 // 蹲下
        case escape = 53     // 菜单
        case tab = 48        // 切换武器
        case r = 15          // 重新装弹
        case f = 3           // 互动
        case e = 14          // 使用道具
        case q = 12          // 丢弃道具
        case c = 8           // 蹲下/起立
        case v = 9           // 近战攻击
        case g = 5           // 手雷
        case t = 17          // 聊天
        case m = 46          // 地图
        case i = 34          // 库存
        case p = 35          // 暂停
        
        // 数字键
        case key1 = 18       // 武器槽 1
        case key2 = 19       // 武器槽 2
        case key3 = 20       // 武器槽 3
        case key4 = 21       // 武器槽 4
        case key5 = 23       // 武器槽 5
        
        // 方向键
        case arrowUp = 126
        case arrowDown = 125
        case arrowLeft = 123
        case arrowRight = 124
        
        // 功能键
        case f1 = 122
        case f2 = 120
        case f3 = 99
        case f4 = 118
        case f5 = 96
        
        var description: String {
            switch self {
            case .w: return "前进"
            case .a: return "左移"
            case .s: return "后退"
            case .d: return "右移"
            case .space: return "跳跃"
            case .leftShift: return "冲刺"
            case .escape: return "菜单"
            default: return "按键\(rawValue)"
            }
        }
    }
    
    // MARK: - 输入监听器协议
    
    /// 输入事件监听器协议
    protocol InputListener: AnyObject {
        func onKeyPressed(_ keyCode: KeyCode)
        func onKeyReleased(_ keyCode: KeyCode)
        func onMouseMoved(_ delta: SIMD2<Float>)
        func onMouseButtonPressed(_ button: MouseButton)
        func onMouseButtonReleased(_ button: MouseButton)
        func onMouseScrolled(_ delta: SIMD2<Float>)
        func onGamepadConnected()
        func onGamepadDisconnected()
        func onGamepadInput(_ state: GamepadState)
    }
    
    /// 鼠标按键枚举
    enum MouseButton {
        case left, right, middle
    }
    
    /// 弱引用包装器
    private struct WeakInputListener {
        weak var listener: InputListener?
    }
    
    // MARK: - 输入系统设置
    
    private func setupInputHandling() {
        // 键盘事件监听
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            print("⌨️ InputManager: 键盘事件 - keyCode=\(event.keyCode), type=\(event.type == .keyDown ? "keyDown" : "keyUp")")
            self?.handleKeyboardEvent(event)
            return event
        }
        
        // 鼠标移动监听
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMovement(event)
            return event
        }
        
        // 鼠标按键监听
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]) { [weak self] event in
            self?.handleMouseButton(event)
            return event
        }
        
        // 鼠标滚轮监听
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleMouseScroll(event)
            return event
        }
        
        print("✅ InputManager: 输入事件监听器设置完成")
    }
    
    private func setupGameControllerSupport() {
        // 游戏手柄连接通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameControllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameControllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        
        // 检查已连接的手柄
        updateGamepadState()
        
        print("✅ InputManager: 游戏手柄支持设置完成")
    }
    
    // MARK: - 事件处理
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let isPressed = (event.type == .keyDown)
        
        print("⌨️ InputManager: handleKeyboardEvent - keyCode=\(keyCode), isPressed=\(isPressed)")
        
        // 更新键状态
        keyStates[keyCode] = isPressed
        
        // 通知监听器
        if let mappedKey = KeyCode(rawValue: keyCode) {
            print("⌨️ InputManager: 映射键码成功 - \(mappedKey)")
            if isPressed {
                print("⌨️ InputManager: 通知按键按下 - \(mappedKey)")
                notifyKeyPressed(mappedKey)
            } else {
                notifyKeyReleased(mappedKey)
            }
        }
    }
    
    private func handleMouseMovement(_ event: NSEvent) {
        let delta = SIMD2<Float>(Float(event.deltaX), Float(event.deltaY))
        mouseState.delta += delta
        
        // 更新鼠标位置
        let location = event.locationInWindow
        mouseState.position = SIMD2<Float>(Float(location.x), Float(location.y))
        
        notifyMouseMoved(delta)
    }
    
    private func handleMouseButton(_ event: NSEvent) {
        let isPressed = [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type)
        var button: MouseButton
        
        switch event.type {
        case .leftMouseDown, .leftMouseUp:
            button = .left
            mouseState.leftButton = isPressed
        case .rightMouseDown, .rightMouseUp:
            button = .right  
            mouseState.rightButton = isPressed
        case .otherMouseDown, .otherMouseUp:
            button = .middle
            mouseState.middleButton = isPressed
        default:
            return
        }
        
        if isPressed {
            notifyMouseButtonPressed(button)
        } else {
            notifyMouseButtonReleased(button)
        }
    }
    
    private func handleMouseScroll(_ event: NSEvent) {
        let delta = SIMD2<Float>(Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
        mouseState.scrollDelta += delta
        notifyMouseScrolled(delta)
    }
    
    @objc private func gameControllerDidConnect(_ notification: Notification) {
        updateGamepadState()
        notifyGamepadConnected()
        print("🎮 InputManager: 游戏手柄已连接")
    }
    
    @objc private func gameControllerDidDisconnect(_ notification: Notification) {
        gamepadState.isConnected = false
        notifyGamepadDisconnected()
        print("🎮 InputManager: 游戏手柄已断开")
    }
    
    // MARK: - 公共接口
    
    /// 检查按键是否按下
    func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        let isPressed = keyStates[keyCode.rawValue] ?? false
        if keyCode == .w || keyCode == .a || keyCode == .s || keyCode == .d {
            print("🔍 InputManager: isKeyPressed(\(keyCode)) = \(isPressed), rawValue=\(keyCode.rawValue)")
        }
        return isPressed
    }
    
    /// 检查多个按键是否同时按下
    func areKeysPressed(_ keyCodes: [KeyCode]) -> Bool {
        return keyCodes.allSatisfy { isKeyPressed($0) }
    }
    
    /// 检查任意一个按键是否按下
    func isAnyKeyPressed(_ keyCodes: [KeyCode]) -> Bool {
        return keyCodes.contains { isKeyPressed($0) }
    }
    
    /// 获取鼠标增量 (每帧调用后会重置)
    func getMouseDelta() -> SIMD2<Float> {
        let delta = mouseState.delta
        mouseState.delta = SIMD2<Float>(0, 0)
        return delta
    }
    
    /// 获取鼠标位置
    func getMousePosition() -> SIMD2<Float> {
        return mouseState.position
    }
    
    /// 检查鼠标按键状态
    func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        switch button {
        case .left: return mouseState.leftButton
        case .right: return mouseState.rightButton
        case .middle: return mouseState.middleButton
        }
    }
    
    /// 获取鼠标滚轮增量 (每帧调用后会重置)
    func getMouseScrollDelta() -> SIMD2<Float> {
        let delta = mouseState.scrollDelta
        mouseState.scrollDelta = SIMD2<Float>(0, 0)
        return delta
    }
    
    /// 获取游戏手柄状态
    func getGamepadState() -> GamepadState {
        return gamepadState
    }
    
    /// 添加输入监听器
    func addListener(_ listener: InputListener) {
        // 移除已失效的弱引用
        inputListeners.removeAll { $0.listener == nil }
        
        // 避免重复添加
        if !inputListeners.contains(where: { $0.listener === listener }) {
            inputListeners.append(WeakInputListener(listener: listener))
        }
    }
    
    /// 移除输入监听器
    func removeListener(_ listener: InputListener) {
        inputListeners.removeAll { $0.listener === listener }
    }
    
    // MARK: - 游戏手柄更新
    
    private func updateGamepadState() {
        guard let controller = GCController.controllers().first else {
            gamepadState.isConnected = false
            return
        }
        
        gamepadState.isConnected = true
        
        if let gamepad = controller.extendedGamepad {
            gamepadState.leftStick = SIMD2<Float>(
                gamepad.leftThumbstick.xAxis.value,
                gamepad.leftThumbstick.yAxis.value
            )
            gamepadState.rightStick = SIMD2<Float>(
                gamepad.rightThumbstick.xAxis.value,
                gamepad.rightThumbstick.yAxis.value
            )
            gamepadState.leftTrigger = gamepad.leftTrigger.value
            gamepadState.rightTrigger = gamepad.rightTrigger.value
            
            // 更新按键状态
            gamepadState.buttons["A"] = gamepad.buttonA.isPressed
            gamepadState.buttons["B"] = gamepad.buttonB.isPressed
            gamepadState.buttons["X"] = gamepad.buttonX.isPressed
            gamepadState.buttons["Y"] = gamepad.buttonY.isPressed
            gamepadState.buttons["LeftShoulder"] = gamepad.leftShoulder.isPressed
            gamepadState.buttons["RightShoulder"] = gamepad.rightShoulder.isPressed
        }
        
        notifyGamepadInput()
    }
    
    // MARK: - 每帧更新
    
    /// 每帧更新 (由游戏引擎调用)
    func update() {
        // 清理失效的监听器
        inputListeners.removeAll { $0.listener == nil }
        
        // 更新游戏手柄状态
        if gamepadState.isConnected {
            updateGamepadState()
        }
    }
    
    // MARK: - 通知方法
    
    private func notifyKeyPressed(_ keyCode: KeyCode) {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onKeyPressed(keyCode) 
        }
    }
    
    private func notifyKeyReleased(_ keyCode: KeyCode) {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onKeyReleased(keyCode) 
        }
    }
    
    private func notifyMouseMoved(_ delta: SIMD2<Float>) {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onMouseMoved(delta) 
        }
    }
    
    private func notifyMouseButtonPressed(_ button: MouseButton) {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onMouseButtonPressed(button) 
        }
    }
    
    private func notifyMouseButtonReleased(_ button: MouseButton) {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onMouseButtonReleased(button) 
        }
    }
    
    private func notifyMouseScrolled(_ delta: SIMD2<Float>) {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onMouseScrolled(delta) 
        }
    }
    
    private func notifyGamepadConnected() {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onGamepadConnected() 
        }
    }
    
    private func notifyGamepadDisconnected() {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onGamepadDisconnected() 
        }
    }
    
    private func notifyGamepadInput() {
        inputListeners.compactMap { $0.listener }.forEach { 
            $0.onGamepadInput(gamepadState) 
        }
    }
    
    // MARK: - 调试功能
    
    /// 打印当前输入状态
    func printDebugInfo() {
        let pressedKeys = keyStates.compactMap { (keyCode: UInt16, isPressed: Bool) -> String? in
            guard isPressed, let mappedKey = KeyCode(rawValue: keyCode) else { return nil }
            return mappedKey.description
        }
        
        print("""
        🎮 InputManager 调试信息:
        - 按下的按键: \(pressedKeys.isEmpty ? "无" : pressedKeys.joined(separator: ", "))
        - 鼠标位置: \(mouseState.position)
        - 鼠标按键: L:\(mouseState.leftButton) R:\(mouseState.rightButton) M:\(mouseState.middleButton)
        - 游戏手柄连接: \(gamepadState.isConnected)
        - 监听器数量: \(inputListeners.count)
        """)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("🗑️ InputManager: 清理完成")
    }
}
