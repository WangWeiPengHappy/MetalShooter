//
//  GameWorldSetup.swift
//  MetalShooter
//
//  Created by GitHub Copilot on 8/8/25.
//

import Foundation
import simd

/// 游戏世界设置工具类
/// 用于创建测试场景、敌人、环境等
public class GameWorldSetup {
    public static let shared = GameWorldSetup()
    
    private let entityManager = EntityManager.shared
    private let collisionSystem = CollisionSystem.shared
    
    private init() {}
    
    /// 创建基础测试场景
    public func createBasicTestScene() {
        print("🌍 开始创建基础测试场景...")
        
        // 创建地面
        createGround()
        
        // 创建几面墙
        createWalls()
        
        // 创建一些测试目标
        createTestTargets()
        
        print("✅ 基础测试场景创建完成")
    }
    
    /// 创建地面
    private func createGround() {
        let groundSize = Float3(50, 1, 50)  // 50x1x50的地面
        let groundPosition = Float3(0, -0.5, 0)
        
        let groundEntity = collisionSystem.createStaticCollider(
            at: groundPosition,
            size: groundSize,
            layer: .environment
        )
        
        // 添加渲染组件 (如果需要可视化)
        if let render = entityManager.getComponent(RenderComponent.self, for: groundEntity) {
            render.isVisible = true
        }
        
        print("🟫 地面创建完成: size=\(groundSize)")
    }
    
    /// 创建墙壁
    private func createWalls() {
        let wallThickness: Float = 1.0
        let wallHeight: Float = 5.0
        let roomSize: Float = 25.0
        
        // 前墙
        _ = collisionSystem.createStaticCollider(
            at: Float3(0, wallHeight/2, -roomSize/2),
            size: Float3(roomSize, wallHeight, wallThickness),
            layer: .environment
        )
        
        // 后墙
        _ = collisionSystem.createStaticCollider(
            at: Float3(0, wallHeight/2, roomSize/2),
            size: Float3(roomSize, wallHeight, wallThickness),
            layer: .environment
        )
        
        // 左墙
        _ = collisionSystem.createStaticCollider(
            at: Float3(-roomSize/2, wallHeight/2, 0),
            size: Float3(wallThickness, wallHeight, roomSize),
            layer: .environment
        )
        
        // 右墙
        _ = collisionSystem.createStaticCollider(
            at: Float3(roomSize/2, wallHeight/2, 0),
            size: Float3(wallThickness, wallHeight, roomSize),
            layer: .environment
        )
        
        print("🧱 墙壁创建完成: 4面墙, 房间大小=\(roomSize)x\(roomSize)")
    }
    
    /// 创建测试目标
    private func createTestTargets() {
        // 创建几个不同位置的目标
        let targetPositions: [Float3] = [
            Float3(5, 1, -8),   // 右前方
            Float3(-3, 2, -10), // 左前方，稍高
            Float3(0, 1.5, -12), // 正前方
            Float3(8, 1, -5),   // 右侧
            Float3(-8, 1, -5)   // 左侧
        ]
        
        for (index, position) in targetPositions.enumerated() {
            createTestTarget(at: position, id: index)
        }
        
        print("🎯 创建了 \(targetPositions.count) 个测试目标")
    }
    
    /// 创建单个测试目标
    private func createTestTarget(at position: Float3, id: Int) {
        let entity = Entity()
        
        // Transform组件
        let transform = TransformComponent()
        transform.localPosition = position
        entityManager.addComponent(transform, to: entity.id)
        
        // Collider组件 (目标可以被子弹击中)
        let targetSize = Float3(1, 2, 0.5)  // 1x2x0.5 的目标
        let collider = ColliderComponent(
            colliderType: .box,
            bounds: AABB(center: position, size: targetSize),
            layer: .enemy,
            mask: [.bullet]
        )
        
        // 添加命中回调
        collider.onCollisionEnter = { [weak self] (entityId, collisionInfo) in
            self?.onTargetHit(targetId: entityId, targetNumber: id, collisionInfo: collisionInfo)
        }
        
        entityManager.addComponent(collider, to: entity.id)
        
        // 添加渲染组件 (用于可视化)
        let render = RenderComponent()
        render.isVisible = true
        // 注意: RenderComponent没有boundingBox属性，这里只是为了标记可见
        entityManager.addComponent(render, to: entity.id)
        
        print("🎯 目标 #\(id) 创建完成: position=\(position)")
    }
    
    /// 目标被击中的回调
    private func onTargetHit(targetId: UUID, targetNumber: Int, collisionInfo: CollisionInfo) {
        print("🎉 目标 #\(targetNumber) 被击中! 位置: \(collisionInfo.contactPoint)")
        
        // 可以添加击中效果
        spawnTargetHitEffect(at: collisionInfo.contactPoint)
        
        // 可以选择销毁目标或移动到新位置
        // respawnTarget(targetId: targetId)
    }
    
    /// 生成目标击中特效
    private func spawnTargetHitEffect(at position: Float3) {
        // TODO: 添加粒子特效
        print("💫 目标击中特效: \(position)")
    }
    
    /// 重新生成目标
    private func respawnTarget(targetId: UUID) {
        // 将目标移动到随机位置
        if let transform = entityManager.getComponent(TransformComponent.self, for: targetId) {
            let newPosition = Float3(
                Float.random(in: -10...10),
                Float.random(in: 1...3),
                Float.random(in: -15...(-5))
            )
            transform.localPosition = newPosition
            print("🔄 目标重新生成: \(newPosition)")
        }
    }
    
    /// 创建简单的敌人实体 (暂时静态)
    public func createSimpleEnemy(at position: Float3) -> UUID {
        let entity = Entity()
        
        // Transform组件
        let transform = TransformComponent()
        transform.localPosition = position
        entityManager.addComponent(transform, to: entity.id)
        
        // Collider组件
        let enemySize = Float3(1, 2, 1)
        let collider = ColliderComponent(
            colliderType: .box,
            bounds: AABB(center: position, size: enemySize),
            layer: .enemy,
            mask: [.bullet, .player]
        )
        
        collider.onCollisionEnter = { (entityId, collisionInfo) in
            print("💀 敌人被击中: \(entityId)")
        }
        
        entityManager.addComponent(collider, to: entity.id)
        
        // 渲染组件
        let render = RenderComponent()
        render.isVisible = true
        // 注意: RenderComponent没有boundingBox属性，这里只是为了标记可见
        entityManager.addComponent(render, to: entity.id)
        
        print("👹 简单敌人创建完成: position=\(position)")
        return entity.id
    }
    
    /// 清空所有创建的实体
    public func clearScene() {
        // 获取所有实体并销毁它们
        let allEntities = entityManager.getAllEntities()
        for entity in allEntities {
            entityManager.destroyEntity(entity)
        }
        
        // 清理碰撞系统
        collisionSystem.cleanup()
        
        // 清理武器系统
        WeaponSystem.shared.clearAllBullets()
        
        print("🧹 场景清空完成")
    }
    
    /// 添加一些测试用的障碍物
    public func addObstacles() {
        let obstaclePositions: [Float3] = [
            Float3(3, 1, -6),
            Float3(-4, 1.5, -8),
            Float3(0, 0.5, -4)
        ]
        
        for position in obstaclePositions {
            let obstacleSize = Float3(
                Float.random(in: 0.5...2.0),
                Float.random(in: 0.5...2.0),
                Float.random(in: 0.5...2.0)
            )
            
            _ = collisionSystem.createStaticCollider(
                at: position,
                size: obstacleSize,
                layer: .environment
            )
        }
        
        print("🗿 添加了 \(obstaclePositions.count) 个障碍物")
    }
}
