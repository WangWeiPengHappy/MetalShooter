//
//  Entity.swift
//  MetalShooter
//
//  实体类型定义
//

import Foundation

/// 游戏实体结构
public struct Entity {
    /// 实体唯一标识符
    public let id: UUID
    
    /// 初始化实体
    public init() {
        self.id = UUID()
    }
    
    /// 使用指定ID初始化实体
    public init(id: UUID) {
        self.id = id
    }
}

extension Entity: Identifiable {}
extension Entity: Hashable {}
