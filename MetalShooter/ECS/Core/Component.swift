//
//  Component.swift
//  MetalShooter
//
//  ECS 系统的组件基类和协议定义
//  为实体组件系统提供类型安全和高效的组件管理
//

import Foundation

// MARK: - 组件基础协议

/// 所有组件必须实现的基础协议
/// 提供组件与实体的关联和基本生命周期管理
protocol Component: AnyObject {
    /// 组件所属的实体ID
    var entityId: UUID { get set }
    
    /// 组件是否启用
    var isEnabled: Bool { get set }
    
    /// 组件初始化时调用 (可选)
    func awake()
    
    /// 组件启用时调用 (可选)
    func onEnable()
    
    /// 组件禁用时调用 (可选)
    func onDisable()
    
    /// 组件销毁时调用 (可选)
    func onDestroy()
}

/// 为 Component 协议提供默认实现
extension Component {
    func awake() {
        // 默认空实现
    }
    
    func onEnable() {
        // 默认空实现
    }
    
    func onDisable() {
        // 默认空实现
    }
    
    func onDestroy() {
        // 默认空实现
    }
}

// MARK: - 组件类型标识协议

/// 组件类型标识协议
/// 提供类型安全的组件查询和管理功能
protocol ComponentType {
    /// 组件类型的唯一标识符
    static var typeId: String { get }
    
    /// 组件类型的显示名称
    static var typeName: String { get }
    
    /// 组件在编辑器中的分类
    var category: ComponentCategory { get }
}

/// 为 ComponentType 提供默认实现
extension ComponentType {
    static var typeId: String {
        return String(describing: Self.self)
    }
    
    static var typeName: String {
        return String(describing: Self.self).replacingOccurrences(of: "Component", with: "")
    }
    
    static var category: ComponentCategory {
        return .general
    }
}

// MARK: - 组件分类枚举

/// 组件分类，用于在编辑器中组织组件
enum ComponentCategory: String, CaseIterable {
    case general = "General"        // 通用组件
    case rendering = "Rendering"    // 渲染相关
    case physics = "Physics"        // 物理相关
    case gameplay = "Gameplay"      // 游戏玩法
    case ai = "AI"                  // 人工智能
    case audio = "Audio"            // 音频相关
    case ui = "UI"                  // 用户界面
    case effects = "Effects"        // 特效
    case networking = "Networking"  // 网络相关
    case debug = "Debug"           // 调试工具
    
    /// 分类的显示顺序
    var sortOrder: Int {
        switch self {
        case .general: return 0
        case .rendering: return 1
        case .physics: return 2
        case .gameplay: return 3
        case .ai: return 4
        case .audio: return 5
        case .ui: return 6
        case .effects: return 7
        case .networking: return 8
        case .debug: return 9
        }
    }
}

// MARK: - 组件基类

/// 所有组件的基类
/// 提供基础的组件功能和生命周期管理
class BaseComponent: Component, ComponentType {
    // MARK: - Component 协议实现
    
    /// 组件所属的实体ID
    var entityId: UUID = UUID()
    
    /// 组件是否启用
    var isEnabled: Bool = true {
        didSet {
            if oldValue != isEnabled {
                if isEnabled {
                    onEnable()
                } else {
                    onDisable()
                }
            }
        }
    }
    
    /// 组件标签集合
    var componentTags: Set<ComponentTag> = []
    
    // MARK: - ComponentType 协议实现
    
    /// 默认分类为通用
    var category: ComponentCategory {
        return .general
    }
    
    // MARK: - 组件信息
    
    /// 组件创建时间
    let creationTime: TimeInterval
    
    /// 组件是否已经初始化
    private(set) var isAwake: Bool = false
    
    /// 组件是否已经启用过
    private(set) var hasBeenEnabled: Bool = false
    
    // MARK: - 初始化
    
    /// 初始化组件
    init() {
        self.creationTime = Date().timeIntervalSince1970
    }
    
    /// 组件初始化时调用
    /// 子类应该重写此方法进行初始化
    func awake() {
        if !isAwake {
            isAwake = true
            // 子类实现
        }
    }
    
    /// 组件启用时调用
    /// 子类应该重写此方法进行启用时的设置
    func onEnable() {
        hasBeenEnabled = true
        // 子类实现
    }
    
    /// 组件禁用时调用
    /// 子类应该重写此方法进行清理
    func onDisable() {
        // 子类实现
    }
    
    /// 组件销毁时调用
    /// 子类应该重写此方法进行资源释放
    func onDestroy() {
        // 子类实现
    }
    
    // MARK: - 便捷方法
    
    /// 获取组件所属的实体管理器
    var entityManager: EntityManager {
        return EntityManager.shared
    }
    
    /// 获取同一实体上的其他组件
    /// - Parameter type: 组件类型
    /// - Returns: 指定类型的组件，如果不存在则返回 nil
    func getComponent<T: Component & ComponentType>(_ type: T.Type) -> T? {
        return entityManager.getComponent(type, for: entityId)
    }
    
    /// 获取同一实体上的所有指定类型组件
    /// - Parameter type: 组件类型
    /// - Returns: 指定类型的组件数组
    func getComponents<T: Component & ComponentType>(_ type: T.Type) -> [T] {
        return entityManager.getComponents(type, for: entityId)
    }
    
    /// 添加组件到同一实体
    /// - Parameter component: 要添加的组件
    func addComponent<T: Component & ComponentType>(_ component: T) {
        entityManager.addComponent(component, to: entityId)
    }
    
    /// 移除同一实体上的组件
    /// - Parameter type: 要移除的组件类型
    func removeComponent<T: Component & ComponentType>(_ type: T.Type) {
        entityManager.removeComponent(type, from: entityId)
    }
    
    /// 检查同一实体是否有指定类型的组件
    /// - Parameter type: 组件类型
    /// - Returns: 如果有该类型组件返回 true
    func hasComponent<T: Component & ComponentType>(_ type: T.Type) -> Bool {
        return entityManager.hasComponent(type, for: entityId)
    }
    
    // MARK: - 标签管理
    
    /// 添加标签
    /// - Parameter tag: 要添加的标签
    func addTag(_ tag: ComponentTag) {
        componentTags.insert(tag)
    }
    
    /// 移除标签
    /// - Parameter tag: 要移除的标签
    func removeTag(_ tag: ComponentTag) {
        componentTags.remove(tag)
    }
    
    /// 检查是否有指定标签
    /// - Parameter tag: 要检查的标签
    /// - Returns: 如果有该标签返回 true
    func hasTag(_ tag: ComponentTag) -> Bool {
        return componentTags.contains(tag)
    }
    
    /// 检查是否有任意一个指定标签
    /// - Parameter tags: 要检查的标签数组
    /// - Returns: 如果有任意一个标签返回 true
    func hasAnyTag(_ tags: [ComponentTag]) -> Bool {
        return !Set(tags).isDisjoint(with: componentTags)
    }
    
    /// 检查是否有所有指定标签
    /// - Parameter tags: 要检查的标签数组
    /// - Returns: 如果有所有标签返回 true
    func hasAllTags(_ tags: [ComponentTag]) -> Bool {
        return Set(tags).isSubset(of: componentTags)
    }
}

// MARK: - 组件标签系统

/// 组件标签，用于快速筛选和查找组件
struct ComponentTag: Hashable, CustomStringConvertible {
    let name: String
    
    init(_ name: String) {
        self.name = name
    }
    
    var description: String {
        return name
    }
    
    // 预定义的常用标签
    static let player = ComponentTag("Player")
    static let enemy = ComponentTag("Enemy")
    static let weapon = ComponentTag("Weapon")
    static let projectile = ComponentTag("Projectile")
    static let collectible = ComponentTag("Collectible")
    static let environment = ComponentTag("Environment")
    static let ui = ComponentTag("UI")
    static let effect = ComponentTag("Effect")
    static let audio = ComponentTag("Audio")
    static let camera = ComponentTag("Camera")
    static let spatial = ComponentTag("Spatial")
    static let renderable = ComponentTag("Renderable")
    static let physics = ComponentTag("Physics")
    static let ai = ComponentTag("AI")
}

// MARK: - 组件事件系统

/// 组件事件类型
enum ComponentEvent {
    case added(component: Component)
    case removed(component: Component)
    case enabled(component: Component)
    case disabled(component: Component)
    case destroyed(component: Component)
}

/// 组件事件监听器协议
protocol ComponentEventListener: AnyObject {
    func onComponentEvent(_ event: ComponentEvent)
}

/// 专用的弱引用组件事件监听器包装器
class WeakComponentEventListener {
    weak var listener: ComponentEventListener?
    
    init(_ listener: ComponentEventListener) {
        self.listener = listener
    }
}

/// 组件事件管理器
class ComponentEventManager {
    static let shared = ComponentEventManager()
    
    private var listeners: [WeakComponentEventListener] = []
    
    private init() {}
    
    /// 添加事件监听器
    /// - Parameter listener: 监听器
    func addListener(_ listener: ComponentEventListener) {
        // 清理无效的弱引用
        cleanupListeners()
        listeners.append(WeakComponentEventListener(listener))
    }
    
    /// 移除事件监听器
    /// - Parameter listener: 监听器
    func removeListener(_ listener: ComponentEventListener) {
        listeners.removeAll { weakListener in
            weakListener.listener == nil || ObjectIdentifier(weakListener.listener!) == ObjectIdentifier(listener)
        }
    }
    
    /// 广播组件事件
    /// - Parameter event: 事件
    func broadcast(_ event: ComponentEvent) {
        cleanupListeners()
        for weakListener in listeners {
            weakListener.listener?.onComponentEvent(event)
        }
    }
    
    /// 清理无效的监听器引用
    private func cleanupListeners() {
        listeners.removeAll { $0.listener == nil }
    }
}

// MARK: - 辅助类

/// 弱引用包装器
class WeakReference<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - 组件查询系统

/// 组件查询构建器
/// 用于构建复杂的组件查询条件
struct ComponentQuery {
    private var requiredTypes: Set<String> = []
    private var excludedTypes: Set<String> = []
    private var requiredTags: Set<ComponentTag> = []
    private var excludedTags: Set<ComponentTag> = []
    
    /// 要求包含指定类型的组件
    /// - Parameter type: 组件类型
    /// - Returns: 查询构建器
    func with<T: Component & ComponentType>(_ type: T.Type) -> ComponentQuery {
        var query = self
        query.requiredTypes.insert(T.typeId)
        return query
    }
    
    /// 要求不包含指定类型的组件
    /// - Parameter type: 组件类型
    /// - Returns: 查询构建器
    func without<T: Component & ComponentType>(_ type: T.Type) -> ComponentQuery {
        var query = self
        query.excludedTypes.insert(T.typeId)
        return query
    }
    
    /// 要求包含指定标签
    /// - Parameter tag: 标签
    /// - Returns: 查询构建器
    func withTag(_ tag: ComponentTag) -> ComponentQuery {
        var query = self
        query.requiredTags.insert(tag)
        return query
    }
    
    /// 要求不包含指定标签
    /// - Parameter tag: 标签
    /// - Returns: 查询构建器
    func withoutTag(_ tag: ComponentTag) -> ComponentQuery {
        var query = self
        query.excludedTags.insert(tag)
        return query
    }
    
    /// 检查实体是否匹配查询条件
    /// - Parameter entityId: 实体ID
    /// - Returns: 如果匹配返回 true
    func matches(entityId: UUID) -> Bool {
        let entityManager = EntityManager.shared
        
        // 检查必需的组件类型
        for typeId in requiredTypes {
            if !entityManager.hasComponentOfType(typeId, for: entityId) {
                return false
            }
        }
        
        // 检查排除的组件类型
        for typeId in excludedTypes {
            if entityManager.hasComponentOfType(typeId, for: entityId) {
                return false
            }
        }
        
        // TODO: 实现标签检查 (需要在 EntityManager 中添加标签支持)
        
        return true
    }
}

// MARK: - 使用示例和注释

/*
 组件系统使用示例:
 
 // 创建自定义组件
 class HealthComponent: BaseComponent {
     var maxHealth: Float = 100.0
     var currentHealth: Float = 100.0
     
     static override var category: ComponentCategory { .gameplay }
     
     override func awake() {
         super.awake()
         currentHealth = maxHealth
         addTag(.player)
     }
 }
 
 // 创建实体并添加组件
 let entityId = EntityManager.shared.createEntity()
 let healthComponent = HealthComponent()
 EntityManager.shared.addComponent(healthComponent, to: entityId)
 
 // 组件查询
 let query = ComponentQuery()
     .with(HealthComponent.self)
     .withTag(.player)
 
 let entities = EntityManager.shared.getEntitiesMatching(query)
 */
