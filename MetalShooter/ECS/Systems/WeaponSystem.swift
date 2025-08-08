//
//  WeaponSystem.swift
//  MetalShooter
//
//  Created by GitHub Copilot on 8/8/25.
//

import Foundation
import simd

/// 武器类型枚举
public enum WeaponType {
    case pistol
    case rifle
    case shotgun
    case machineGun
}

/// 子弹类型结构
public struct Bullet {
    public let id: UUID = UUID()
    public var position: Float3
    public var velocity: Float3
    public var damage: Float
    public var lifespan: Float
    public var currentLife: Float
    public var owner: UUID
    
    public init(position: Float3, velocity: Float3, damage: Float, lifespan: Float, owner: UUID) {
        self.position = position
        self.velocity = velocity
        self.damage = damage
        self.lifespan = lifespan
        self.currentLife = lifespan
        self.owner = owner
    }
    
    public mutating func update(deltaTime: Float) -> Bool {
        position += velocity * deltaTime
        currentLife -= deltaTime
        return currentLife > 0
    }
    
    public var isAlive: Bool {
        return currentLife > 0
    }
}

/// 武器组件
class WeaponComponent: BaseComponent {
    public var weaponType: WeaponType
    public var damage: Float
    public var fireRate: Float // 每秒射击次数
    public var bulletSpeed: Float
    public var bulletLifespan: Float
    public var lastFireTime: Float
    public var ammunition: Int
    public var maxAmmunition: Int
    public var reloadTime: Float
    public var isReloading: Bool
    public var reloadStartTime: Float
    
    override var category: ComponentCategory {
        return .gameplay
    }
    
    public init(
        weaponType: WeaponType = .pistol,
        damage: Float = 25.0,
        fireRate: Float = 2.0,
        bulletSpeed: Float = 50.0,
        bulletLifespan: Float = 5.0,
        ammunition: Int = 12,
        maxAmmunition: Int = 12,
        reloadTime: Float = 2.0
    ) {
        self.weaponType = weaponType
        self.damage = damage
        self.fireRate = fireRate
        self.bulletSpeed = bulletSpeed
        self.bulletLifespan = bulletLifespan
        self.lastFireTime = 0.0
        self.ammunition = ammunition
        self.maxAmmunition = maxAmmunition
        self.reloadTime = reloadTime
        self.isReloading = false
        self.reloadStartTime = 0.0
        
        super.init()
        super.addTag(.weapon)
    }
    
    /// 检查是否可以射击
    public func canFire(currentTime: Float) -> Bool {
        guard !isReloading && ammunition > 0 else { return false }
        let timeSinceLastShot = currentTime - lastFireTime
        return timeSinceLastShot >= (1.0 / fireRate)
    }
    
    /// 开始射击
    public func fire(currentTime: Float) -> Bool {
        guard canFire(currentTime: currentTime) else { return false }
        
        ammunition -= 1
        lastFireTime = currentTime
        
        // 如果弹药用完，自动开始装弹
        if ammunition <= 0 {
            startReload(currentTime: currentTime)
        }
        
        return true
    }
    
    /// 开始装弹
    public func startReload(currentTime: Float) {
        guard !isReloading && ammunition < maxAmmunition else { return }
        
        isReloading = true
        reloadStartTime = currentTime
    }
    
    /// 更新武器状态
    public func update(currentTime: Float) {
        if isReloading {
            let reloadProgress = currentTime - reloadStartTime
            if reloadProgress >= reloadTime {
                // 装弹完成
                ammunition = maxAmmunition
                isReloading = false
            }
        }
    }
}

/// 武器系统 - 管理所有武器和子弹
public class WeaponSystem {
    public static let shared = WeaponSystem()
    
    private var activeBullets: [Bullet] = []
    private let entityManager = EntityManager.shared
    
    private init() {}
    
    /// 更新武器系统
    public func update(deltaTime: Float, currentTime: Float) {
        updateWeapons(currentTime: currentTime)
        updateBullets(deltaTime: deltaTime)
    }
    
    /// 更新所有武器状态
    private func updateWeapons(currentTime: Float) {
        for entity in entityManager.getEntitiesWith(WeaponComponent.self) {
            if let weapon = entityManager.getComponent(WeaponComponent.self, for: entity) {
                weapon.update(currentTime: currentTime)
            }
        }
    }
    
    /// 更新所有子弹
    private func updateBullets(deltaTime: Float) {
        activeBullets.removeAll { bullet in
            var mutableBullet = bullet
            return !mutableBullet.update(deltaTime: deltaTime)
        }
    }
    
    /// 射击 - 从指定实体的武器发射子弹
    public func fireWeapon(from entityId: UUID, direction: Float3, currentTime: Float) -> Bool {
        guard let weapon = entityManager.getComponent(WeaponComponent.self, for: entityId),
              let transform = entityManager.getComponent(TransformComponent.self, for: entityId) else {
            return false
        }
        
        guard weapon.fire(currentTime: currentTime) else {
            return false
        }
        
        // 创建子弹
        let bulletVelocity = normalize(direction) * weapon.bulletSpeed
        let bullet = Bullet(
            position: transform.localPosition,
            velocity: bulletVelocity,
            damage: weapon.damage,
            lifespan: weapon.bulletLifespan,
            owner: entityId
        )
        
        activeBullets.append(bullet)
        
        print("🔫 武器射击! 弹药剩余: \(weapon.ammunition)/\(weapon.maxAmmunition)")
        return true
    }
    
    /// 装弹
    public func reloadWeapon(entityId: UUID, currentTime: Float) {
        if let weapon = entityManager.getComponent(WeaponComponent.self, for: entityId) {
            weapon.startReload(currentTime: currentTime)
            print("🔄 开始装弹...")
        }
    }
    
    /// 获取活跃子弹列表
    public func getActiveBullets() -> [Bullet] {
        return activeBullets
    }
    
    /// 移除指定子弹
    public func removeBullet(withId bulletId: UUID) {
        activeBullets.removeAll { $0.id == bulletId }
    }
    
    /// 清除所有子弹
    public func clearAllBullets() {
        activeBullets.removeAll()
    }
    
    /// 获取子弹数量
    public func getBulletCount() -> Int {
        return activeBullets.count
    }
    
    /// 为实体创建默认武器
    public func createDefaultWeapon(for entityId: UUID, weaponType: WeaponType = .pistol) {
        let weapon: WeaponComponent
        
        switch weaponType {
        case .pistol:
            weapon = WeaponComponent(
                weaponType: .pistol,
                damage: 25.0,
                fireRate: 2.0,
                bulletSpeed: 50.0,
                bulletLifespan: 5.0,
                ammunition: 12,
                maxAmmunition: 12,
                reloadTime: 2.0
            )
        case .rifle:
            weapon = WeaponComponent(
                weaponType: .rifle,
                damage: 35.0,
                fireRate: 5.0,
                bulletSpeed: 75.0,
                bulletLifespan: 8.0,
                ammunition: 30,
                maxAmmunition: 30,
                reloadTime: 3.0
            )
        case .shotgun:
            weapon = WeaponComponent(
                weaponType: .shotgun,
                damage: 60.0,
                fireRate: 1.0,
                bulletSpeed: 40.0,
                bulletLifespan: 3.0,
                ammunition: 8,
                maxAmmunition: 8,
                reloadTime: 4.0
            )
        case .machineGun:
            weapon = WeaponComponent(
                weaponType: .machineGun,
                damage: 20.0,
                fireRate: 10.0,
                bulletSpeed: 60.0,
                bulletLifespan: 6.0,
                ammunition: 100,
                maxAmmunition: 100,
                reloadTime: 5.0
            )
        }
        
        entityManager.addComponent(weapon, to: entityId)
        print("🎯 为实体创建武器: \(weaponType)")
    }
}
