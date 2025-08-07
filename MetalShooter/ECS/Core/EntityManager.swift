//
//  EntityManager.swift
//  MetalShooter
//
//  实体管理器 - ECS 系统的核心
//  负责实体和组件的创建、管理、查询和销毁
//

import Foundation

// MARK: - 实体管理器

/// 实体管理器 - ECS 系统的核心类
/// 使用单例模式管理所有实体和组件
/// 提供高效的组件查询和实体操作功能
class EntityManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = EntityManager()
    
    /// 私有初始化器，确保单例模式
    private init() {}
    
    // MARK: - 私有属性
    
    /// 所有激活的实体ID集合
    private var activeEntities: Set<UUID> = []
    
    /// 组件存储：[组件类型ID: [实体ID: 组件实例]]
    private var componentStorage: [String: [UUID: Component]] = [:]
    
    /// 实体到组件类型的映射：[实体ID: 组件类型ID集合]
    private var entityToComponents: [UUID: Set<String>] = [:]
    
    /// 组件类型到实体的映射：[组件类型ID: 实体ID集合] (用于快速查询)
    private var componentToEntities: [String: Set<UUID>] = [:]
    
    /// 组件池：[组件类型ID: [可复用的组件实例]]
    private var componentPools: [String: [Component]] = [:]
    
    /// 待销毁的实体队列 (延迟销毁，避免在系统更新时立即销毁)
    private var entitiesToDestroy: Set<UUID> = []
    
    /// 待添加的组件队列 (延迟添加)
    private var componentsToAdd: [(entityId: UUID, component: Component)] = []
    
    /// 待移除的组件队列 (延迟移除)
    private var componentsToRemove: [(entityId: UUID, typeId: String)] = []
    
    /// 读写锁，确保线程安全
    private let lock = NSRecursiveLock()
    
    // MARK: - 统计信息
    
    /// 当前活跃实体数量
    var entityCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeEntities.count
    }
    
    /// 当前组件总数量
    var componentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return componentStorage.values.reduce(0) { $0 + $1.count }
    }
    
    /// 获取指定类型组件的数量
    /// - Parameter type: 组件类型
    /// - Returns: 组件数量
    func getComponentCount<T: Component & ComponentType>(_ type: T.Type) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return componentStorage[T.typeId]?.count ?? 0
    }
    
    // MARK: - 实体管理
    
    /// 创建一个新实体
    /// - Returns: 新实体的唯一标识符
    @discardableResult
    func createEntity() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        
        let entityId = UUID()
        activeEntities.insert(entityId)
        entityToComponents[entityId] = Set<String>()
        
        // 广播实体创建事件
        // TODO: 实现实体事件系统
        
        return entityId
    }
    
    /// 销毁实体 (延迟销毁)
    /// - Parameter entityId: 要销毁的实体ID
    func destroyEntity(_ entityId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        guard activeEntities.contains(entityId) else {
            print("警告: 试图销毁不存在的实体: \(entityId)")
            return
        }
        
        // 加入待销毁队列，避免在系统更新时立即销毁
        entitiesToDestroy.insert(entityId)
    }
    
    /// 立即销毁实体 (危险操作，仅在确保安全时使用)
    /// - Parameter entityId: 要销毁的实体ID
    func destroyEntityImmediate(_ entityId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        guard activeEntities.contains(entityId) else { return }
        
        // 销毁该实体的所有组件
        if let componentTypes = entityToComponents[entityId] {
            for typeId in componentTypes {
                if let component = componentStorage[typeId]?[entityId] {
                    component.onDestroy()
                    
                    // 广播组件销毁事件
                    ComponentEventManager.shared.broadcast(.destroyed(component: component))
                    
                    // 从存储中移除
                    componentStorage[typeId]?[entityId] = nil
                    componentToEntities[typeId]?.remove(entityId)
                    
                    // 回收到组件池
                    recycleComponent(component, typeId: typeId)
                }
            }
        }
        
        // 移除实体
        activeEntities.remove(entityId)
        entityToComponents[entityId] = nil
        
        // 广播实体销毁事件
        // TODO: 实现实体事件系统
    }
    
    /// 检查实体是否存在
    /// - Parameter entityId: 实体ID
    /// - Returns: 如果实体存在返回 true
    func entityExists(_ entityId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeEntities.contains(entityId)
    }
    
    /// 获取所有活跃的实体ID
    /// - Returns: 实体ID数组
    func getAllEntities() -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        return Array(activeEntities)
    }
    
    // MARK: - 组件管理
    
    /// 添加组件到实体 (延迟添加)
    /// - Parameters:
    ///   - component: 要添加的组件
    ///   - entityId: 目标实体ID
    func addComponent<T: Component & ComponentType>(_ component: T, to entityId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        guard activeEntities.contains(entityId) else {
            print("警告: 试图向不存在的实体添加组件: \(entityId)")
            return
        }
        
        component.entityId = entityId
        componentsToAdd.append((entityId: entityId, component: component))
    }
    
    /// 立即添加组件到实体 (危险操作)
    /// - Parameters:
    ///   - component: 要添加的组件
    ///   - entityId: 目标实体ID
    func addComponentImmediate<T: Component & ComponentType>(_ component: T, to entityId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        guard activeEntities.contains(entityId) else {
            print("警告: 试图向不存在的实体添加组件: \(entityId)")
            return
        }
        
        let typeId = T.typeId
        component.entityId = entityId
        
        // 检查是否已有相同类型组件
        if componentStorage[typeId]?[entityId] != nil {
            print("警告: 实体 \(entityId) 已有 \(T.typeName) 组件，将被替换")
        }
        
        // 存储组件
        if componentStorage[typeId] == nil {
            componentStorage[typeId] = [:]
        }
        if componentToEntities[typeId] == nil {
            componentToEntities[typeId] = Set<UUID>()
        }
        
        componentStorage[typeId]![entityId] = component
        componentToEntities[typeId]!.insert(entityId)
        entityToComponents[entityId]?.insert(typeId)
        
        // 初始化组件
        component.awake()
        if component.isEnabled {
            component.onEnable()
        }
        
        // 广播组件添加事件
        ComponentEventManager.shared.broadcast(.added(component: component))
    }
    
    /// 获取实体的指定类型组件
    /// - Parameters:
    ///   - type: 组件类型
    ///   - entityId: 实体ID
    /// - Returns: 组件实例，如果不存在返回 nil
    func getComponent<T: Component & ComponentType>(_ type: T.Type, for entityId: UUID) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        return componentStorage[T.typeId]?[entityId] as? T
    }
    
    /// 获取实体的所有指定类型组件
    /// - Parameters:
    ///   - type: 组件类型
    ///   - entityId: 实体ID
    /// - Returns: 组件数组
    func getComponents<T: Component & ComponentType>(_ type: T.Type, for entityId: UUID) -> [T] {
        lock.lock()
        defer { lock.unlock() }
        
        // 目前每个实体每种类型只能有一个组件，但保留接口以便将来扩展
        if let component = componentStorage[T.typeId]?[entityId] as? T {
            return [component]
        }
        return []
    }
    
    /// 移除实体的指定类型组件 (延迟移除)
    /// - Parameters:
    ///   - type: 组件类型
    ///   - entityId: 实体ID
    func removeComponent<T: Component & ComponentType>(_ type: T.Type, from entityId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        componentsToRemove.append((entityId: entityId, typeId: T.typeId))
    }
    
    /// 立即移除实体的指定类型组件
    /// - Parameters:
    ///   - type: 组件类型
    ///   - entityId: 实体ID
    func removeComponentImmediate<T: Component & ComponentType>(_ type: T.Type, from entityId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        let typeId = T.typeId
        
        guard let component = componentStorage[typeId]?[entityId] else {
            return
        }
        
        // 禁用并销毁组件
        if component.isEnabled {
            component.isEnabled = false
        }
        component.onDestroy()
        
        // 从存储中移除
        componentStorage[typeId]?[entityId] = nil
        componentToEntities[typeId]?.remove(entityId)
        entityToComponents[entityId]?.remove(typeId)
        
        // 广播组件移除事件
        ComponentEventManager.shared.broadcast(.removed(component: component))
        
        // 回收到组件池
        recycleComponent(component, typeId: typeId)
    }
    
    /// 检查实体是否有指定类型组件
    /// - Parameters:
    ///   - type: 组件类型
    ///   - entityId: 实体ID
    /// - Returns: 如果有该类型组件返回 true
    func hasComponent<T: Component & ComponentType>(_ type: T.Type, for entityId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return componentStorage[T.typeId]?[entityId] != nil
    }
    
    /// 检查实体是否有指定类型ID的组件 (内部使用)
    /// - Parameters:
    ///   - typeId: 组件类型ID
    ///   - entityId: 实体ID
    /// - Returns: 如果有该类型组件返回 true
    func hasComponentOfType(_ typeId: String, for entityId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return componentStorage[typeId]?[entityId] != nil
    }
    
    // MARK: - 组件查询
    
    /// 获取所有拥有指定类型组件的实体
    /// - Parameter type: 组件类型
    /// - Returns: 实体ID数组
    func getEntitiesWith<T: Component & ComponentType>(_ type: T.Type) -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(componentToEntities[T.typeId] ?? [])
    }
    
    /// 获取所有指定类型的组件
    /// - Parameter type: 组件类型
    /// - Returns: 组件数组
    func getAllComponents<T: Component & ComponentType>(_ type: T.Type) -> [T] {
        lock.lock()
        defer { lock.unlock() }
        
        return componentStorage[T.typeId]?.values.compactMap { $0 as? T } ?? []
    }
    
    /// 根据查询条件获取匹配的实体
    /// - Parameter query: 查询条件
    /// - Returns: 匹配的实体ID数组
    func getEntitiesMatching(_ query: ComponentQuery) -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        
        return activeEntities.filter { entityId in
            query.matches(entityId: entityId)
        }
    }
    
    // MARK: - 系统更新
    
    /// 处理延迟操作 (应在每帧开始时调用)
    /// 处理待销毁的实体、待添加的组件、待移除的组件
    func processPendingOperations() {
        lock.lock()
        defer { lock.unlock() }
        
        // 处理待销毁的实体
        for entityId in entitiesToDestroy {
            destroyEntityImmediate(entityId)
        }
        entitiesToDestroy.removeAll()
        
        // 处理待添加的组件
        for (entityId, component) in componentsToAdd {
            if let typedComponent = component as? (Component & ComponentType) {
                addComponentImmediate(typedComponent, to: entityId)
            }
        }
        componentsToAdd.removeAll()
        
        // 处理待移除的组件
        for (entityId, typeId) in componentsToRemove {
            if let component = componentStorage[typeId]?[entityId] {
                // 禁用并销毁组件
                if component.isEnabled {
                    component.isEnabled = false
                }
                component.onDestroy()
                
                // 从存储中移除
                componentStorage[typeId]?[entityId] = nil
                componentToEntities[typeId]?.remove(entityId)
                entityToComponents[entityId]?.remove(typeId)
                
                // 广播组件移除事件
                ComponentEventManager.shared.broadcast(.removed(component: component))
                
                // 回收到组件池
                recycleComponent(component, typeId: typeId)
            }
        }
        componentsToRemove.removeAll()
    }
    
    /// 清理所有数据 (游戏重启时调用)
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        // 销毁所有实体和组件
        for entityId in activeEntities {
            destroyEntityImmediate(entityId)
        }
        
        // 清理所有数据结构
        activeEntities.removeAll()
        componentStorage.removeAll()
        entityToComponents.removeAll()
        componentToEntities.removeAll()
        componentPools.removeAll()
        entitiesToDestroy.removeAll()
        componentsToAdd.removeAll()
        componentsToRemove.removeAll()
    }
    
    // MARK: - 组件池管理
    
    /// 从组件池获取组件实例 (对象池模式)
    /// - Parameter type: 组件类型
    /// - Returns: 组件实例
    private func getPooledComponent<T: Component & ComponentType>(_ type: T.Type) -> T? {
        let typeId = T.typeId
        return componentPools[typeId]?.popLast() as? T
    }
    
    /// 回收组件到池中
    /// - Parameters:
    ///   - component: 要回收的组件
    ///   - typeId: 组件类型ID
    private func recycleComponent(_ component: Component, typeId: String) {
        // 重置组件状态
        component.entityId = UUID()
        component.isEnabled = true
        
        // 添加到池中 (限制池大小避免内存过多占用)
        if componentPools[typeId] == nil {
            componentPools[typeId] = []
        }
        
        if componentPools[typeId]!.count < 100 { // 最大池大小
            componentPools[typeId]!.append(component)
        }
    }
    
    // MARK: - 调试和统计
    
    /// 获取内存使用统计
    /// - Returns: 统计信息字典
    func getMemoryStats() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        
        var stats: [String: Any] = [:]
        stats["activeEntities"] = activeEntities.count
        stats["totalComponents"] = componentCount
        
        var componentStats: [String: Int] = [:]
        for (typeId, components) in componentStorage {
            componentStats[typeId] = components.count
        }
        stats["componentsByType"] = componentStats
        
        var poolStats: [String: Int] = [:]
        for (typeId, pool) in componentPools {
            poolStats[typeId] = pool.count
        }
        stats["pooledComponents"] = poolStats
        
        return stats
    }
    
    /// 打印调试信息
    func printDebugInfo() {
        lock.lock()
        defer { lock.unlock() }
        
        print("=== EntityManager 调试信息 ===")
        print("活跃实体数: \(activeEntities.count)")
        print("组件总数: \(componentCount)")
        print("组件类型数: \(componentStorage.keys.count)")
        
        for (typeId, components) in componentStorage {
            print("  \(typeId): \(components.count) 个实例")
        }
        
        print("待销毁实体数: \(entitiesToDestroy.count)")
        print("待添加组件数: \(componentsToAdd.count)")
        print("待移除组件数: \(componentsToRemove.count)")
        print("==========================")
    }
}
