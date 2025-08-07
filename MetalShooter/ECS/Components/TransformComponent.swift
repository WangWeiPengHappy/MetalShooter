//
//  TransformComponent.swift
//  MetalShooter
//
//  变换组件 - 处理实体的位置、旋转、缩放
//  是大多数可见对象的基础组件
//

import Foundation
import simd

// MARK: - 变换组件

/// 变换组件 - 存储和管理实体的空间变换信息
/// 提供位置、旋转、缩放以及层级关系管理
class TransformComponent: BaseComponent {
    
    // MARK: - ComponentType 协议
    override var category: ComponentCategory {
        return .rendering
    }
    
    // MARK: - 变换属性
    
    /// 本地位置 (相对于父节点)
    var localPosition: Float3 = Float3.zero {
        didSet {
            markDirty()
        }
    }
    
    /// 本地旋转 (相对于父节点)
    var localRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) {
        didSet {
            markDirty()
        }
    }
    
    /// 本地缩放 (相对于父节点)
    var localScale: Float3 = Float3(1, 1, 1) {
        didSet {
            markDirty()
        }
    }
    
    // MARK: - 缓存的变换矩阵
    
    /// 本地变换矩阵 (缓存)
    private var _localMatrix: Float4x4?
    
    /// 世界变换矩阵 (缓存)
    private var _worldMatrix: Float4x4?
    
    /// 变换是否需要重新计算
    private var isDirty: Bool = true
    
    /// 子节点变换是否需要重新计算
    private var childrenDirty: Bool = true
    
    // MARK: - 层级关系
    
    /// 父变换组件的实体ID (如果有父节点)
    var parentEntityId: UUID? {
        didSet {
            if oldValue != parentEntityId {
                markDirty()
                // 通知旧父节点移除子节点
                if let oldParent = oldValue,
                   let oldParentTransform = EntityManager.shared.getComponent(TransformComponent.self, for: oldParent) {
                    oldParentTransform.removeChild(entityId)
                }
                
                // 通知新父节点添加子节点
                if let newParent = parentEntityId,
                   let newParentTransform = EntityManager.shared.getComponent(TransformComponent.self, for: newParent) {
                    newParentTransform.addChild(entityId)
                }
            }
        }
    }
    
    /// 子变换组件的实体ID列表
    private var childEntityIds: Set<UUID> = []
    
    // MARK: - 计算属性
    
    /// 世界位置
    var worldPosition: Float3 {
        let matrix = worldMatrix
        return Float3(matrix[3][0], matrix[3][1], matrix[3][2])
    }
    
    /// 世界旋转
    var worldRotation: simd_quatf {
        if let parent = parent {
            return simd_normalize(parent.worldRotation * localRotation)
        }
        return localRotation
    }
    
    /// 世界缩放
    var worldScale: Float3 {
        if let parent = parent {
            return parent.worldScale * localScale
        }
        return localScale
    }
    
    /// 前方向量 (世界空间)
    var forward: Float3 {
        let forward = Float3(0, 0, -1)
        return normalize(worldRotation.act(forward))
    }
    
    /// 右方向量 (世界空间)
    var right: Float3 {
        let right = Float3(1, 0, 0)
        return normalize(worldRotation.act(right))
    }
    
    /// 上方向量 (世界空间)
    var up: Float3 {
        let up = Float3(0, 1, 0)
        return normalize(worldRotation.act(up))
    }
    
    /// 父变换组件
    var parent: TransformComponent? {
        guard let parentId = parentEntityId else { return nil }
        return EntityManager.shared.getComponent(TransformComponent.self, for: parentId)
    }
    
    /// 子变换组件列表
    var children: [TransformComponent] {
        return childEntityIds.compactMap { childId in
            EntityManager.shared.getComponent(TransformComponent.self, for: childId)
        }
    }
    
    /// 本地变换矩阵
    var localMatrix: Float4x4 {
        if isDirty || _localMatrix == nil {
            updateLocalMatrix()
        }
        return _localMatrix!
    }
    
    /// 世界变换矩阵
    var worldMatrix: Float4x4 {
        if isDirty || _worldMatrix == nil {
            updateWorldMatrix()
        }
        return _worldMatrix!
    }
    
    // MARK: - 初始化
    
    override init() {
        super.init()
        componentTags.insert(.spatial)
        markDirty()
    }
    
    /// 使用变换信息初始化
    /// - Parameters:
    ///   - position: 位置
    ///   - rotation: 旋转
    ///   - scale: 缩放
    convenience init(position: Float3 = Float3.zero,
                     rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                     scale: Float3 = Float3(1, 1, 1)) {
        self.init()
        self.localPosition = position
        self.localRotation = rotation
        self.localScale = scale
    }
    
    // MARK: - 组件生命周期
    
    override func awake() {
        super.awake()
        markDirty()
    }
    
    override func onEnable() {
        super.onEnable()
    }
    
    override func onDisable() {
        super.onDisable()
    }
    
    override func onDestroy() {
        // 清理层级关系
        parentEntityId = nil
        childEntityIds.removeAll()
        super.onDestroy()
    }
    
    // MARK: - 变换操作
    
    /// 平移 (本地空间)
    /// - Parameter deltaPosition: 位移向量
    func translate(_ deltaPosition: Float3) {
        localPosition += deltaPosition
    }
    
    /// 平移 (世界空间)
    /// - Parameter deltaPosition: 世界空间位移向量
    func translateWorld(_ deltaPosition: Float3) {
        if let parent = parent {
            // 转换到本地空间
            let invParentRotation = parent.worldRotation.inverse
            let localDelta = invParentRotation.act(deltaPosition)
            translate(localDelta)
        } else {
            translate(deltaPosition)
        }
    }
    
    /// 旋转 (本地空间)
    /// - Parameter deltaRotation: 旋转四元数
    func rotate(_ deltaRotation: simd_quatf) {
        localRotation = simd_normalize(localRotation * deltaRotation)
    }
    
    /// 旋转 (世界空间)
    /// - Parameter deltaRotation: 世界空间旋转四元数
    func rotateWorld(_ deltaRotation: simd_quatf) {
        if let parent = parent {
            // 转换到本地空间
            let invParentRotation = parent.worldRotation.inverse
            let localDelta = invParentRotation * deltaRotation * parent.worldRotation
            rotate(localDelta)
        } else {
            rotate(deltaRotation)
        }
    }
    
    /// 绕轴旋转 (本地空间)
    /// - Parameters:
    ///   - angle: 旋转角度 (弧度)
    ///   - axis: 旋转轴
    func rotateAround(angle: Float, axis: Float3) {
        let rotation = simd_quatf(angle: angle, axis: normalize(axis))
        rotate(rotation)
    }
    
    /// 绕轴旋转 (世界空间)
    /// - Parameters:
    ///   - angle: 旋转角度 (弧度)
    ///   - axis: 世界空间旋转轴
    func rotateAroundWorld(angle: Float, axis: Float3) {
        let rotation = simd_quatf(angle: angle, axis: normalize(axis))
        rotateWorld(rotation)
    }
    
    /// 缩放
    /// - Parameter deltaScale: 缩放系数
    func scale(_ deltaScale: Float3) {
        localScale *= deltaScale
    }
    
    /// 统一缩放
    /// - Parameter factor: 缩放系数
    func scale(_ factor: Float) {
        scale(Float3(factor, factor, factor))
    }
    
    /// 看向目标 (世界空间)
    /// - Parameters:
    ///   - target: 目标位置
    ///   - up: 上方向 (默认为世界Y轴)
    func lookAt(_ target: Float3, up: Float3 = Float3(0, 1, 0)) {
        let forward = normalize(target - worldPosition)
        let right = normalize(cross(up, forward))
        let correctedUp = cross(forward, right)
        
        let lookRotation = simd_quatf(from: Float3(0, 0, -1), to: forward)
        
        if let parent = parent {
            // 转换到本地空间
            let worldRotation = lookRotation
            localRotation = parent.worldRotation.inverse * worldRotation
        } else {
            localRotation = lookRotation
        }
    }
    
    // MARK: - 层级管理
    
    /// 设置父节点
    /// - Parameter parent: 父变换组件
    func setParent(_ parent: TransformComponent?) {
        parentEntityId = parent?.entityId
    }
    
    /// 添加子节点 (内部使用)
    /// - Parameter childEntityId: 子节点实体ID
    private func addChild(_ childEntityId: UUID) {
        childEntityIds.insert(childEntityId)
        markChildrenDirty()
    }
    
    /// 移除子节点 (内部使用)
    /// - Parameter childEntityId: 子节点实体ID
    private func removeChild(_ childEntityId: UUID) {
        childEntityIds.remove(childEntityId)
    }
    
    /// 获取根节点
    /// - Returns: 根变换组件
    func getRoot() -> TransformComponent {
        var current = self
        while let parent = current.parent {
            current = parent
        }
        return current
    }
    
    /// 获取所有祖先节点
    /// - Returns: 从直接父节点到根节点的变换组件数组
    func getAncestors() -> [TransformComponent] {
        var ancestors: [TransformComponent] = []
        var current = parent
        while let ancestor = current {
            ancestors.append(ancestor)
            current = ancestor.parent
        }
        return ancestors
    }
    
    /// 获取所有后代节点
    /// - Returns: 所有子节点和子孙节点的变换组件数组
    func getDescendants() -> [TransformComponent] {
        var descendants: [TransformComponent] = []
        
        func collectDescendants(_ transform: TransformComponent) {
            for child in transform.children {
                descendants.append(child)
                collectDescendants(child)
            }
        }
        
        collectDescendants(self)
        return descendants
    }
    
    // MARK: - 坐标系转换
    
    /// 将点从本地空间转换到世界空间
    /// - Parameter localPoint: 本地空间点
    /// - Returns: 世界空间点
    func transformPoint(_ localPoint: Float3) -> Float3 {
        let point4 = Float4(localPoint.x, localPoint.y, localPoint.z, 1.0)
        let worldPoint4 = worldMatrix * point4
        return Float3(worldPoint4.x, worldPoint4.y, worldPoint4.z)
    }
    
    /// 将方向从本地空间转换到世界空间
    /// - Parameter localDirection: 本地空间方向
    /// - Returns: 世界空间方向
    func transformDirection(_ localDirection: Float3) -> Float3 {
        return worldRotation.act(localDirection * worldScale)
    }
    
    /// 将点从世界空间转换到本地空间
    /// - Parameter worldPoint: 世界空间点
    /// - Returns: 本地空间点
    func inverseTransformPoint(_ worldPoint: Float3) -> Float3 {
        let point4 = Float4(worldPoint.x, worldPoint.y, worldPoint.z, 1.0)
        let localPoint4 = worldMatrix.inverse * point4
        return Float3(localPoint4.x, localPoint4.y, localPoint4.z)
    }
    
    /// 将方向从世界空间转换到本地空间
    /// - Parameter worldDirection: 世界空间方向
    /// - Returns: 本地空间方向
    func inverseTransformDirection(_ worldDirection: Float3) -> Float3 {
        return worldRotation.inverse.act(worldDirection / worldScale)
    }
    
    // MARK: - 私有方法
    
    /// 标记变换为脏状态，需要重新计算
    private func markDirty() {
        isDirty = true
        _worldMatrix = nil
        markChildrenDirty()
    }
    
    /// 标记所有子节点为脏状态
    private func markChildrenDirty() {
        childrenDirty = true
        for child in children {
            child.markDirty()
        }
    }
    
    /// 更新本地变换矩阵
    private func updateLocalMatrix() {
        let translation = Float4x4.translation(localPosition)
        let rotation = Float4x4.rotation(from: localRotation)
        let scale = Float4x4.scaling(localScale)
        
        _localMatrix = translation * rotation * scale
        isDirty = false
    }
    
    /// 更新世界变换矩阵
    private func updateWorldMatrix() {
        if let parent = parent {
            _worldMatrix = parent.worldMatrix * localMatrix
        } else {
            _worldMatrix = localMatrix
        }
        isDirty = false
        childrenDirty = false
    }
}

// MARK: - 扩展：便利构造器

extension TransformComponent {
    /// 创建指定位置的变换组件
    /// - Parameter position: 位置
    /// - Returns: 变换组件实例
    static func at(_ position: Float3) -> TransformComponent {
        return TransformComponent(position: position)
    }
    
    /// 创建指定位置和旋转的变换组件
    /// - Parameters:
    ///   - position: 位置
    ///   - rotation: 旋转
    /// - Returns: 变换组件实例
    static func at(_ position: Float3, rotation: simd_quatf) -> TransformComponent {
        return TransformComponent(position: position, rotation: rotation)
    }
    
    /// 创建指定位置、旋转和缩放的变换组件
    /// - Parameters:
    ///   - position: 位置
    ///   - rotation: 旋转
    ///   - scale: 缩放
    /// - Returns: 变换组件实例
    static func at(_ position: Float3, rotation: simd_quatf, scale: Float3) -> TransformComponent {
        return TransformComponent(position: position, rotation: rotation, scale: scale)
    }
}
