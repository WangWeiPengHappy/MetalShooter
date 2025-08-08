//
//  CollisionSystem.swift
//  MetalShooter
//
//  Created by GitHub Copilot on 8/8/25.
//

import Foundation
import simd

/// 碰撞体类型
public enum ColliderType {
    case box        // 立方体碰撞器
    case sphere     // 球形碰撞器
    case capsule    // 胶囊碰撞器
    case mesh       // 网格碰撞器
}

/// 碰撞层级
public struct CollisionLayer: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let player        = CollisionLayer(rawValue: 1 << 0)
    public static let enemy         = CollisionLayer(rawValue: 1 << 1)
    public static let environment   = CollisionLayer(rawValue: 1 << 2)
    public static let bullet        = CollisionLayer(rawValue: 1 << 3)
    public static let pickup        = CollisionLayer(rawValue: 1 << 4)
    public static let trigger       = CollisionLayer(rawValue: 1 << 5)
    
    public static let all: CollisionLayer = [.player, .enemy, .environment, .bullet, .pickup, .trigger]
}

/// 碰撞体组件
class ColliderComponent: BaseComponent {
    public var colliderType: ColliderType
    public var bounds: AABB
    public var layer: CollisionLayer
    public var mask: CollisionLayer  // 与哪些层级发生碰撞
    public var isTrigger: Bool
    
    // 碰撞回调
    public var onCollisionEnter: ((UUID, CollisionInfo) -> Void)?
    public var onTriggerEnter: ((UUID, CollisionInfo) -> Void)?
    
    override var category: ComponentCategory {
        return .physics
    }
    
    public init(
        colliderType: ColliderType = .box,
        bounds: AABB = AABB(min: Float3(-0.5, -0.5, -0.5), max: Float3(0.5, 0.5, 0.5)),
        layer: CollisionLayer = .environment,
        mask: CollisionLayer = .all,
        isTrigger: Bool = false
    ) {
        self.colliderType = colliderType
        self.bounds = bounds
        self.layer = layer
        self.mask = mask
        self.isTrigger = isTrigger
        
        super.init()
        super.addTag(.physics)
        self.isEnabled = true
    }
    
    /// 更新碰撞体边界 (基于Transform)
    public func updateBounds(from transform: TransformComponent) {
        let size = bounds.size
        let halfSize = size * 0.5
        bounds = AABB(min: transform.localPosition - halfSize, max: transform.localPosition + halfSize)
        // 这里可以根据colliderType进行更复杂的计算
    }
}

/// 碰撞信息
public struct CollisionInfo {
    public let otherEntity: UUID
    public let contactPoint: Float3
    public let contactNormal: Float3
    public let penetrationDepth: Float
    public let collisionTime: Float
    
    public init(otherEntity: UUID, contactPoint: Float3, contactNormal: Float3, penetrationDepth: Float, collisionTime: Float) {
        self.otherEntity = otherEntity
        self.contactPoint = contactPoint
        self.contactNormal = contactNormal
        self.penetrationDepth = penetrationDepth
        self.collisionTime = collisionTime
    }
}

/// 射线投射结果
public struct RaycastHit {
    public let entity: UUID
    public let point: Float3
    public let normal: Float3
    public let distance: Float
    
    public init(entity: UUID, point: Float3, normal: Float3, distance: Float) {
        self.entity = entity
        self.point = point
        self.normal = normal
        self.distance = distance
    }
}

/// 碰撞检测系统
public class CollisionSystem {
    public static let shared = CollisionSystem()
    
    private let entityManager = EntityManager.shared
    private var activeCollisions: Set<String> = [] // 防止重复处理同一碰撞
    
    private init() {}
    
    /// 更新碰撞系统
    public func update(deltaTime: Float) {
        updateColliderBounds()
        checkCollisions()
        checkBulletCollisions()
    }
    
    /// 更新所有碰撞体的边界
    private func updateColliderBounds() {
        for entity in entityManager.getEntitiesWith(ColliderComponent.self) {
            if let collider = entityManager.getComponent(ColliderComponent.self, for: entity),
               let transform = entityManager.getComponent(TransformComponent.self, for: entity),
               collider.isEnabled {
                collider.updateBounds(from: transform)
            }
        }
    }
    
    /// 检查所有实体之间的碰撞
    private func checkCollisions() {
        let entities = entityManager.getEntitiesWith(ColliderComponent.self)
        
        for i in 0..<entities.count {
            for j in (i+1)..<entities.count {
                let entityA = entities[i]
                let entityB = entities[j]
                
                guard let colliderA = entityManager.getComponent(ColliderComponent.self, for: entityA),
                      let colliderB = entityManager.getComponent(ColliderComponent.self, for: entityB),
                      colliderA.isEnabled && colliderB.isEnabled else { continue }
                
                // 检查层级掩码
                guard colliderA.layer.intersects(colliderB.mask) || colliderB.layer.intersects(colliderA.mask) else {
                    continue
                }
                
                // 碰撞检测
                if checkAABBCollision(colliderA.bounds, colliderB.bounds) {
                    handleCollision(entityA: entityA, entityB: entityB, colliderA: colliderA, colliderB: colliderB)
                }
            }
        }
    }
    
    /// 专门检查子弹碰撞
    private func checkBulletCollisions() {
        let bullets = WeaponSystem.shared.getActiveBullets()
        let colliderEntities = entityManager.getEntitiesWith(ColliderComponent.self)
        
        for bullet in bullets {
            for entity in colliderEntities {
                guard let collider = entityManager.getComponent(ColliderComponent.self, for: entity),
                      collider.isEnabled else { continue }
                
                // 子弹不与发射者碰撞
                if entity == bullet.owner { continue }
                
                // 检查子弹与实体的碰撞
                if checkPointInAABB(bullet.position, collider.bounds) {
                    handleBulletCollision(bullet: bullet, targetEntity: entity, collider: collider)
                }
            }
        }
    }
    
    /// AABB碰撞检测
    private func checkAABBCollision(_ aabb1: AABB, _ aabb2: AABB) -> Bool {
        return aabb1.intersects(aabb2)
    }
    
    /// 点在AABB内检测
    private func checkPointInAABB(_ point: Float3, _ aabb: AABB) -> Bool {
        return point.x >= aabb.min.x && point.x <= aabb.max.x &&
               point.y >= aabb.min.y && point.y <= aabb.max.y &&
               point.z >= aabb.min.z && point.z <= aabb.max.z
    }
    
    /// 处理实体间碰撞
    private func handleCollision(entityA: UUID, entityB: UUID, colliderA: ColliderComponent, colliderB: ColliderComponent) {
        let collisionKey = "\(entityA)_\(entityB)"
        let reverseKey = "\(entityB)_\(entityA)"
        
        // 防止重复处理
        if activeCollisions.contains(collisionKey) || activeCollisions.contains(reverseKey) {
            return
        }
        
        activeCollisions.insert(collisionKey)
        
        // 计算碰撞信息
        let contactPoint = (colliderA.bounds.center + colliderB.bounds.center) * 0.5
        let contactNormal = normalize(colliderB.bounds.center - colliderA.bounds.center)
        let penetrationDepth = Float(0.0) // 简化处理
        let currentTime = Time.shared.totalTime
        
        let collisionInfoA = CollisionInfo(
            otherEntity: entityB,
            contactPoint: contactPoint,
            contactNormal: contactNormal,
            penetrationDepth: penetrationDepth,
            collisionTime: currentTime
        )
        
        let collisionInfoB = CollisionInfo(
            otherEntity: entityA,
            contactPoint: contactPoint,
            contactNormal: -contactNormal,
            penetrationDepth: penetrationDepth,
            collisionTime: currentTime
        )
        
        // 触发碰撞回调
        if colliderA.isTrigger {
            colliderA.onTriggerEnter?(entityA, collisionInfoA)
        } else {
            colliderA.onCollisionEnter?(entityA, collisionInfoA)
        }
        
        if colliderB.isTrigger {
            colliderB.onTriggerEnter?(entityB, collisionInfoB)
        } else {
            colliderB.onCollisionEnter?(entityB, collisionInfoB)
        }
        
        print("💥 碰撞检测: \(entityA) ↔ \(entityB)")
    }
    
    /// 处理子弹碰撞
    private func handleBulletCollision(bullet: Bullet, targetEntity: UUID, collider: ColliderComponent) {
        // 移除子弹
        WeaponSystem.shared.removeBullet(withId: bullet.id)
        
        // 如果目标有生命值组件，造成伤害
        // TODO: 实现生命值系统后添加伤害处理
        
        print("🎯 子弹命中: 目标=\(targetEntity), 伤害=\(bullet.damage)")
        
        // 触发碰撞效果
        spawnHitEffect(at: bullet.position, normal: Float3(0, 1, 0))
    }
    
    /// 射线投射
    public func raycast(from origin: Float3, direction: Float3, maxDistance: Float = 100.0, layerMask: CollisionLayer = .all) -> RaycastHit? {
        let ray = Ray(origin: origin, direction: normalize(direction))
        var closestHit: RaycastHit? = nil
        var closestDistance = maxDistance
        
        for entity in entityManager.getEntitiesWith(ColliderComponent.self) {
            guard let collider = entityManager.getComponent(ColliderComponent.self, for: entity),
                  collider.isEnabled && layerMask.contains(collider.layer) else { continue }
            
            if let distance = collider.bounds.intersects(ray), distance < closestDistance {
                let hitPoint = origin + direction * distance
                let hitNormal = normalize(hitPoint - collider.bounds.center) // 简化法向量
                
                closestHit = RaycastHit(entity: entity, point: hitPoint, normal: hitNormal, distance: distance)
                closestDistance = distance
            }
        }
        
        return closestHit
    }
    
    /// 创建基础碰撞体 (静态物体)
    public func createStaticCollider(at position: Float3, size: Float3, layer: CollisionLayer = .environment) -> UUID {
        let entity = Entity()
        
        // 添加Transform组件
        let transform = TransformComponent()
        transform.localPosition = position
        entityManager.addComponent(transform, to: entity.id)
        
        // 添加Collider组件
        let bounds = AABB(center: position, size: size)
        let collider = ColliderComponent(
            colliderType: .box,
            bounds: bounds,
            layer: layer,
            mask: [.player, .bullet]
        )
        entityManager.addComponent(collider, to: entity.id)
        
        print("🏗️ 创建静态碰撞体: position=\(position), size=\(size)")
        return entity.id
    }
    
    /// 生成命中特效 (占位符)
    private func spawnHitEffect(at position: Float3, normal: Float3) {
        // TODO: 实现粒子系统后添加命中特效
        print("✨ 命中特效: position=\(position), normal=\(normal)")
    }
    
    /// 清理过期的碰撞记录
    public func cleanup() {
        activeCollisions.removeAll()
    }
}

// MARK: - CollisionLayer 扩展
extension CollisionLayer {
    /// 检查是否包含指定层级
    func intersects(_ other: CollisionLayer) -> Bool {
        return self.intersection(other) != []
    }
}
