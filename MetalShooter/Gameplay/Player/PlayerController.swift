// PlayerController.swift
// MetalShooter - 第三阶段玩家控制系统
// 使用ECS架构实现WASD移动和鼠标视角控制

import Foundation
import simd
import Cocoa
import GameController

/// 玩家控制器 - FPS游戏核心输入处理
class PlayerController: InputManager.InputListener {
    // MARK: - 属性
    private weak var entityManager: EntityManager?
    private var playerEntity: Entity?
    
    // 玩家移动参数
    private var moveSpeed: Float = 5.0  // 单位/秒
    private var sprintMultiplier: Float = 2.0
    private var jumpForce: Float = 8.0
    
    // 相机控制
    private var pitch: Float = 0.0  // 上下看 (-π/2 到 π/2)
    private var yaw: Float = 0.0    // 左右看 (0 到 2π)
    private let pitchLimit: Float = .pi / 2.0 - 0.1  // 防止翻转
    private var mouseSensitivity: Float = 0.003
    
    // 状态标记
    private var isGrounded: Bool = true
    private var isSprinting: Bool = false
    
    // 输入缓存
    private var currentMouseDelta: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    // MARK: - 键盘映射常量 (使用 InputManager 的映射)
    private typealias KeyCode = InputManager.KeyCode
    
    // MARK: - 初始化
    init(entityManager: EntityManager) {
        self.entityManager = entityManager
        createPlayerEntity()
        setupPlayerWeapon()  // 设置玩家武器
        
        // 注册到 InputManager
        InputManager.shared.addInputListener(self)
        
        print("✅ PlayerController: 玩家控制器初始化完成")
    }
    
    // MARK: - 玩家实体创建
    private func createPlayerEntity() {
        guard let entityManager = entityManager else { return }
        
        // 创建玩家实体
        let entityId = entityManager.createEntity()
        playerEntity = Entity(id: entityId)
        
        // 添加Transform组件 (位置/旋转)
        let transform = TransformComponent()
        transform.localPosition = SIMD3<Float>(0, 2, 0)  // 起始位置
        transform.localRotation = simd_quatf()
        entityManager.addComponent(transform, to: playerEntity!.id)
        
        // 添加Camera组件 (第一人称视角)
        let camera = CameraComponent()
        camera.fieldOfView = 60.0  // 60度视野
        camera.nearPlane = 0.1
        camera.farPlane = 1000.0
        camera.aspectRatio = 16.0 / 9.0  // 默认宽高比
        entityManager.addComponent(camera, to: playerEntity!.id)
        
        print("✅ PlayerController: 玩家实体创建成功")
    }
    
    // MARK: - InputManager.InputListener 协议实现
    
    func onKeyPressed(_ key: InputManager.KeyCode) {
        switch key {
        case .leftShift:
            isSprinting = true
            print("🏃 PlayerController: 开始冲刺")
        case .r:
            // 装弹
            reloadWeapon()
        default:
            // WASD移动在 update() 中处理
            break
        }
    }
    
    func onKeyReleased(_ keyCode: InputManager.KeyCode) {
        print("🔐 PlayerController: onKeyReleased - \(keyCode)")
        switch keyCode {
        case .w, .a, .s, .d:
            print("🔐 PlayerController: WASD按键释放 - \(keyCode)")
            // WASD键的处理在update方法中通过isKeyPressed检查
        case .leftShift:
            isSprinting = false
        default:
            break
        }
    }
    
    func onMouseMoved(_ delta: SIMD2<Float>) {
        currentMouseDelta += delta * mouseSensitivity
        print("🖱️ PlayerController: 鼠标移动 delta=\(delta)")
    }
    
    func onMouseButtonPressed(_ button: InputManager.MouseButton) {
        guard let playerEntity = playerEntity else { return }
        
        switch button {
        case .left:
            // 射击
            fireWeapon()
        case .right:
            // 瞄准
            print("🎯 PlayerController: 瞄准")
        case .middle:
            // 特殊功能
            break
        }
    }
    
    func onMouseButtonReleased(_ button: InputManager.MouseButton) {
        // 处理鼠标按键释放
    }
    
    func onMouseScrolled(_ delta: SIMD2<Float>) {
        // TODO: 切换武器或缩放
        if delta.y > 0 {
            print("🔄 PlayerController: 上一个武器")
        } else if delta.y < 0 {
            print("🔄 PlayerController: 下一个武器")
        }
    }
    
    func onGamepadConnected() {
        print("🎮 PlayerController: 游戏手柄已连接")
    }
    
    func onGamepadDisconnected() {
        print("🎮 PlayerController: 游戏手柄已断开")
    }
    
    func onGamepadInput(_ state: InputManager.GamepadState) {
        // TODO: 处理游戏手柄输入
    }
    
    // MARK: - 更新循环 (每帧调用)
    func update(deltaTime: Float) {
        guard let _ = playerEntity,
              let _ = entityManager else { return }
        
        // 更新相机旋转
        updateCameraRotation()
        
        // 更新玩家移动
        updatePlayerMovement(deltaTime: deltaTime)
        
        // 重置鼠标增量
        currentMouseDelta = SIMD2<Float>(0, 0)
    }
    
    // MARK: - 相机旋转更新
    private func updateCameraRotation() {
        guard let playerEntity = playerEntity,
              let entityManager = entityManager,
              let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id) else {
            return
        }
        
        // 更新偏航角和俯仰角
        yaw += currentMouseDelta.x
        pitch -= currentMouseDelta.y  // 反转Y轴 (符合FPS习惯)
        
        // 限制俯仰角度
        pitch = max(-pitchLimit, min(pitchLimit, pitch))
        
        // 标准化偏航角
        if yaw > 2 * .pi {
            yaw -= 2 * .pi
        } else if yaw < 0 {
            yaw += 2 * .pi
        }
        
        // 创建旋转四元数
        let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        transform.localRotation = yawQuat * pitchQuat
    }
    
    // MARK: - 玩家移动更新
    private func updatePlayerMovement(deltaTime: Float) {
        print("🎮 PlayerController: updatePlayerMovement 被调用")
        
        print("🔍 PlayerController: playerEntity = \(playerEntity?.id.uuidString ?? "nil")")
        print("🔍 PlayerController: entityManager = \(entityManager != nil ? "存在" : "nil")")
        
        guard let playerEntity = playerEntity else {
            print("❌ PlayerController: playerEntity 为 nil")
            return
        }
        
        guard let entityManager = entityManager else {
            print("❌ PlayerController: entityManager 为 nil")
            return
        }
        
        print("🔍 PlayerController: 尝试获取 TransformComponent for entity \(playerEntity.id.uuidString)")
        guard let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id) else {
            print("❌ PlayerController: TransformComponent 获取失败 for entity \(playerEntity.id.uuidString)")
            return
        }
        
        print("✅ PlayerController: 所有guard条件通过，继续移动处理")
        
        let inputManager = InputManager.shared
        
        // 计算移动向量
        var moveVector = SIMD3<Float>(0, 0, 0)
        var hasMovement = false
        
        // WASD键处理 - 使用 InputManager
        if inputManager.isKeyPressed(.w) {
            moveVector.z -= 1.0  // 向前
            hasMovement = true
            print("✅ PlayerController: W键按下，向前移动")
        }
        if inputManager.isKeyPressed(.s) {
            moveVector.z += 1.0  // 向后
            hasMovement = true
            print("✅ PlayerController: S键按下，向后移动")
        }
        if inputManager.isKeyPressed(.a) {
            moveVector.x -= 1.0  // 向左
            hasMovement = true
            print("✅ PlayerController: A键按下，向左移动")
        }
        if inputManager.isKeyPressed(.d) {
            moveVector.x += 1.0  // 向右
            hasMovement = true
            print("✅ PlayerController: D键按下，向右移动")
        }
        
        if hasMovement {
            print("⌨️ PlayerController: WASD移动 vector=\(moveVector)")
        }
        
        // 跳跃处理
        if inputManager.isKeyPressed(.space) && isGrounded {
            moveVector.y += jumpForce
            isGrounded = false  // 简单重力系统会在后面添加
            print("🦘 PlayerController: 跳跃!")
        }
        
        // 标准化水平移动向量
        let horizontalMove = SIMD2<Float>(moveVector.x, moveVector.z)
        if length(horizontalMove) > 0 {
            let normalizedMove = normalize(horizontalMove)
            moveVector.x = normalizedMove.x
            moveVector.z = normalizedMove.y
        }
        
        // 应用冲刺倍数
        let currentSpeed = moveSpeed * (isSprinting ? sprintMultiplier : 1.0)
        
        // 基于相机旋转转换移动向量到世界坐标
        let rotation = transform.localRotation
        let worldMoveVector = rotation.act(moveVector)
        
        // 更新位置
        let oldPosition = transform.localPosition
        transform.localPosition += worldMoveVector * currentSpeed * deltaTime
        
        if hasMovement {
            print("📍 PlayerController: 位置变化 \(oldPosition) -> \(transform.localPosition)")
        }
        
        // 简单地面检测 (后续会用物理系统替代)
        if transform.localPosition.y <= 0 {
            transform.localPosition.y = 0
            isGrounded = true
        }
    }
    
    // MARK: - 工具方法
    private func handleEscapeKey() {
        // 处理ESC键 - 暂停/菜单
        print("🎮 PlayerController: ESC键按下 - 显示菜单")
        // TODO: 显示暂停菜单或退出游戏
    }
    
    // MARK: - 公共接口
    
    /// 获取玩家实体
    func getPlayerEntity() -> Entity? {
        return playerEntity
    }
    
    /// 设置鼠标敏感度
    func setMouseSensitivity(_ sensitivity: Float) {
        mouseSensitivity = max(0.001, min(0.01, sensitivity))
    }
    
    /// 设置移动速度
    func setMoveSpeed(_ speed: Float) {
        moveSpeed = max(1.0, speed)
    }
    
    /// 获取当前相机方向
    func getCameraDirection() -> SIMD3<Float> {
        guard let playerEntity = playerEntity,
              let entityManager = entityManager,
              let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id) else {
            return SIMD3<Float>(0, 0, -1)
        }
        
        return transform.localRotation.act(SIMD3<Float>(0, 0, -1))
    }
    
    /// 获取相机位置
    func getCameraPosition() -> SIMD3<Float> {
        guard let playerEntity = playerEntity,
              let entityManager = entityManager,
              let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id) else {
            return SIMD3<Float>(0, 0, 0)
        }
        
        // 相机稍微高于玩家位置
        return transform.localPosition + SIMD3<Float>(0, 1.8, 0)
    }
    
    /// 清理资源
    func cleanup() {
        // 从 InputManager 中移除监听器
        InputManager.shared.removeInputListener(self)
        print("🗑️ PlayerController: 清理完成")
    }
    
    deinit {
        cleanup()
        print("🗑️ PlayerController: 已销毁")
    }
    
    // MARK: - 武器系统相关方法
    
    /// 射击武器
    private func fireWeapon() {
        guard let playerEntity = playerEntity,
              let entityManager = entityManager else { return }
        
        // 获取当前时间
        let currentTime = Time.shared.totalTime
        
        // 获取射击方向 (相机前方)
        guard let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id) else {
            print("❌ PlayerController: 无法获取 TransformComponent 进行射击")
            return
        }
        
        // 计算射击方向 (相机朝前的方向)
        let forward = transform.forward
        
        // 使用武器系统进行射击
        let success = WeaponSystem.shared.fireWeapon(
            from: playerEntity.id,
            direction: forward,
            currentTime: currentTime
        )
        
        if success {
            print("🔫 PlayerController: 射击成功! 方向=\(forward)")
        } else {
            print("🚫 PlayerController: 射击失败 (可能在装弹或无弹药)")
        }
    }
    
    /// 装弹武器
    private func reloadWeapon() {
        guard let playerEntity = playerEntity else { return }
        
        let currentTime = Time.shared.totalTime
        WeaponSystem.shared.reloadWeapon(entityId: playerEntity.id, currentTime: currentTime)
        print("🔄 PlayerController: 开始装弹")
    }
    
    /// 为玩家创建默认武器
    private func setupPlayerWeapon() {
        guard let playerEntity = playerEntity else { return }
        
        // 为玩家创建默认手枪
        WeaponSystem.shared.createDefaultWeapon(for: playerEntity.id, weaponType: .pistol)
        print("🎯 PlayerController: 为玩家创建默认武器")
    }
}

// MARK: - 扩展: 调试信息
extension PlayerController {
    func printDebugInfo() {
        guard let playerEntity = playerEntity,
              let entityManager = entityManager,
              let transform = entityManager.getComponent(TransformComponent.self, for: playerEntity.id) else {
            print("❌ PlayerController: 无法获取调试信息")
            return
        }
        
        print("""
        📊 PlayerController 调试信息:
        - 位置: \(transform.localPosition)
        - 偏航角: \(yaw * 180 / .pi)°
        - 俯仰角: \(pitch * 180 / .pi)°
        - 在地面: \(isGrounded)
        - 冲刺: \(isSprinting)
        - 鼠标敏感度: \(mouseSensitivity)
        - 移动速度: \(moveSpeed)
        """)
    }
}
