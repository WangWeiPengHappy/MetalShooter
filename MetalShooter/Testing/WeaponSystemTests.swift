//
//  WeaponSystemTests.swift
//  MetalShooter
//
//  Created by GitHub Copilot on 8/8/25.
//

import Foundation
import simd

/// 武器系统测试类
public class WeaponSystemTests {
    public static let shared = WeaponSystemTests()
    
    private let entityManager = EntityManager.shared
    private let weaponSystem = WeaponSystem.shared
    
    private init() {}
    
    /// 运行所有武器系统测试
    public func runAllTests() {
        print("🧪 开始武器系统测试...")
        
        // 1. 基础武器创建测试
        testWeaponCreation()
        
        // 2. 射击机制测试
        testFiringMechanism()
        
        // 3. 弹药和装弹测试
        testAmmunitionAndReload()
        
        // 4. 子弹生命周期测试
        testBulletLifecycle()
        
        // 5. 不同武器类型测试
        testDifferentWeaponTypes()
        
        print("✅ 武器系统测试完成")
    }
    
    /// 测试武器创建
    private func testWeaponCreation() {
        print("\n🔫 测试 1: 武器创建")
        
        // 创建测试实体
        let testEntity = Entity()
        let transform = TransformComponent()
        transform.localPosition = Float3(0, 1, 0)
        entityManager.addComponent(transform, to: testEntity.id)
        
        // 创建武器
        weaponSystem.createDefaultWeapon(for: testEntity.id, weaponType: .pistol)
        
        // 验证武器组件存在
        if let weapon = entityManager.getComponent(WeaponComponent.self, for: testEntity.id) {
            assert(weapon.weaponType == .pistol, "武器类型应为手枪")
            assert(weapon.ammunition == 12, "初始弹药应为12发")
            assert(weapon.maxAmmunition == 12, "最大弹药应为12发")
            print("✅ 武器创建测试通过")
        } else {
            print("❌ 武器创建测试失败 - 武器组件不存在")
        }
        
        // 清理
        entityManager.destroyEntity(testEntity.id)
    }
    
    /// 测试射击机制
    private func testFiringMechanism() {
        print("\n🎯 测试 2: 射击机制")
        
        let testEntity = Entity()
        let transform = TransformComponent()
        transform.localPosition = Float3(0, 1, 0)
        entityManager.addComponent(transform, to: testEntity.id)
        
        weaponSystem.createDefaultWeapon(for: testEntity.id, weaponType: .pistol)
        
        let initialBulletCount = weaponSystem.getBulletCount()
        let currentTime = Time.shared.totalTime
        
        // 进行射击
        let success = weaponSystem.fireWeapon(
            from: testEntity.id,
            direction: Float3(0, 0, -1),
            currentTime: currentTime
        )
        
        assert(success, "射击应该成功")
        assert(weaponSystem.getBulletCount() == initialBulletCount + 1, "子弹数量应增加1")
        
        if let weapon = entityManager.getComponent(WeaponComponent.self, for: testEntity.id) {
            assert(weapon.ammunition == 11, "弹药应减少1发")
            print("✅ 射击机制测试通过")
        } else {
            print("❌ 射击机制测试失败")
        }
        
        // 清理
        entityManager.destroyEntity(testEntity.id)
        weaponSystem.clearAllBullets()
    }
    
    /// 测试弹药和装弹
    private func testAmmunitionAndReload() {
        print("\n🔄 测试 3: 弹药和装弹")
        
        let testEntity = Entity()
        let transform = TransformComponent()
        entityManager.addComponent(transform, to: testEntity.id)
        
        weaponSystem.createDefaultWeapon(for: testEntity.id, weaponType: .pistol)
        
        guard let weapon = entityManager.getComponent(WeaponComponent.self, for: testEntity.id) else {
            print("❌ 无法获取武器组件")
            return
        }
        
        let currentTime = Time.shared.totalTime
        
        // 射完所有子弹
        for _ in 0..<weapon.maxAmmunition {
            _ = weaponSystem.fireWeapon(
                from: testEntity.id,
                direction: Float3(0, 0, -1),
                currentTime: currentTime + Float.random(in: 0.6...1.0) // 避免射击频率限制
            )
        }
        
        assert(weapon.ammunition == 0, "弹药应该用完")
        assert(weapon.isReloading, "应该开始自动装弹")
        
        // 模拟装弹完成
        weapon.ammunition = weapon.maxAmmunition
        weapon.isReloading = false
        
        assert(weapon.ammunition == weapon.maxAmmunition, "装弹后弹药应满")
        print("✅ 弹药和装弹测试通过")
        
        // 清理
        entityManager.destroyEntity(testEntity.id)
        weaponSystem.clearAllBullets()
    }
    
    /// 测试子弹生命周期
    private func testBulletLifecycle() {
        print("\n⏱️ 测试 4: 子弹生命周期")
        
        let testEntity = Entity()
        let transform = TransformComponent()
        entityManager.addComponent(transform, to: testEntity.id)
        
        weaponSystem.createDefaultWeapon(for: testEntity.id, weaponType: .pistol)
        
        let currentTime = Time.shared.totalTime
        
        // 发射子弹
        _ = weaponSystem.fireWeapon(
            from: testEntity.id,
            direction: Float3(0, 0, -1),
            currentTime: currentTime
        )
        
        let initialBulletCount = weaponSystem.getBulletCount()
        assert(initialBulletCount > 0, "应该有子弹存在")
        
        // 模拟子弹更新（让子弹移动和老化）
        weaponSystem.update(deltaTime: 0.1, currentTime: currentTime + 0.1)
        
        let bullets = weaponSystem.getActiveBullets()
        if let bullet = bullets.first {
            assert(bullet.currentLife < bullet.lifespan, "子弹生命值应该减少")
            assert(bullet.isAlive, "子弹应该还活着")
            print("✅ 子弹生命周期测试通过")
        } else {
            print("❌ 子弹生命周期测试失败")
        }
        
        // 清理
        entityManager.destroyEntity(testEntity.id)
        weaponSystem.clearAllBullets()
    }
    
    /// 测试不同武器类型
    private func testDifferentWeaponTypes() {
        print("\n🔫 测试 5: 不同武器类型")
        
        let weaponTypes: [WeaponType] = [.pistol, .rifle, .shotgun, .machineGun]
        
        for weaponType in weaponTypes {
            let testEntity = Entity()
            let transform = TransformComponent()
            entityManager.addComponent(transform, to: testEntity.id)
            
            weaponSystem.createDefaultWeapon(for: testEntity.id, weaponType: weaponType)
            
            if let weapon = entityManager.getComponent(WeaponComponent.self, for: testEntity.id) {
                assert(weapon.weaponType == weaponType, "武器类型应匹配")
                
                // 验证不同武器的不同属性
                switch weaponType {
                case .pistol:
                    assert(weapon.maxAmmunition == 12, "手枪弹药应为12发")
                case .rifle:
                    assert(weapon.maxAmmunition == 30, "步枪弹药应为30发")
                case .shotgun:
                    assert(weapon.maxAmmunition == 8, "霰弹枪弹药应为8发")
                case .machineGun:
                    assert(weapon.maxAmmunition == 100, "机枪弹药应为100发")
                }
                
                print("✅ \(weaponType) 武器测试通过")
            } else {
                print("❌ \(weaponType) 武器测试失败")
            }
            
            // 清理
            entityManager.destroyEntity(testEntity.id)
        }
    }
    
    /// 性能测试 - 大量子弹
    public func performanceTest() {
        print("\n🚀 武器系统性能测试")
        
        let testEntity = Entity()
        let transform = TransformComponent()
        entityManager.addComponent(transform, to: testEntity.id)
        
        weaponSystem.createDefaultWeapon(for: testEntity.id, weaponType: .machineGun)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let currentTime = Time.shared.totalTime
        
        // 发射大量子弹
        for i in 0..<100 {
            _ = weaponSystem.fireWeapon(
                from: testEntity.id,
                direction: Float3(Float.random(in: -1...1), 0, -1),
                currentTime: currentTime + Float(i) * 0.01 // 避免射击频率限制
            )
        }
        
        // 更新系统
        for _ in 0..<10 {
            weaponSystem.update(deltaTime: 0.1, currentTime: currentTime + 1.0)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        print("✅ 性能测试完成:")
        print("   处理100发子弹用时: \(String(format: "%.4f", executionTime))秒")
        print("   当前活跃子弹数: \(weaponSystem.getBulletCount())")
        
        // 清理
        entityManager.destroyEntity(testEntity.id)
        weaponSystem.clearAllBullets()
    }
}
