# MetalShooter V2 开发计划

## 项目概述
MetalShooter V2 将在现有Metal渲染引擎基础上，集成专业3D建模能力，实现更加丰富的游戏体验。

## 核心功能规划

### 1. 3D玩家模型系统
- 使用Blender MCP创建专业级玩家角色模型
- 支持多种角色外观和动画
- 集成到现有Metal渲染管线

### 2. Blender MCP集成方案

#### 2.1 技术方案
**项目地址**: https://github.com/ahujasid/blender-mcp
- **Stars**: 12.8k ⭐
- **Forks**: 1.2k
- **状态**: 活跃开发中

#### 2.2 核心特性
- **Claude AI集成**: 通过自然语言控制Blender进行3D建模
- **Socket服务器**: 基于WebSocket的实时通信
- **对象操作**: 创建、修改、删除3D对象
- **材质控制**: 动态调整材质和纹理
- **Python代码执行**: 在Blender中执行自动化脚本
- **实时预览**: 即时查看建模结果

#### 2.3 安装要求
```bash
# 系统要求
- Blender 3.0+
- Python 3.8+
- uv包管理器

# 安装步骤
uv add blender-mcp
```

#### 2.4 配置步骤
1. **Claude Desktop配置**
   ```json
   {
     "mcpServers": {
       "blender": {
         "command": "uv",
         "args": ["--directory", "/path/to/blender-mcp", "run", "blender-mcp"],
         "env": {
           "BLENDER_EXECUTABLE": "/Applications/Blender.app/Contents/MacOS/Blender"
         }
       }
     }
   }
   ```

2. **Blender插件安装**
   - 下载MCP插件到Blender addons目录
   - 在Blender中启用插件
   - 配置WebSocket连接

#### 2.5 工作流程
1. **模型创建阶段**
   - 使用Claude AI描述玩家角色需求
   - Blender MCP自动生成基础模型
   - 通过对话式交互完善细节

2. **模型导出**
   - 导出为OBJ/DAE格式
   - 包含纹理和材质信息
   - 优化适配Metal渲染管线

3. **游戏集成**
   - 使用现有PlayerModelLoader.swift加载模型
   - 集成到MetalRenderer渲染系统
   - 实现动画和交互逻辑

#### 2.6 开发优势
- **专业质量**: AI辅助创建专业级3D模型
- **快速迭代**: 通过对话快速修改和优化
- **无需建模技能**: 降低3D内容创作门槛
- **自动化流程**: 批量生成多种角色变体

### 3. 现有代码基础

#### 3.1 已完成模块
- **MetalRenderer.swift**: 核心渲染系统，支持三角形居中显示
- **PlayerModelLoader.swift**: 3D模型加载框架（已创建）
- **Camera系统**: 第一人称和第三人称视角切换

#### 3.2 待集成功能
- Blender生成模型的加载和渲染
- 角色动画系统
- 多角色切换功能
- 模型LOD优化

### 4. 开发时间线

#### Phase 1: Blender MCP环境搭建（1-2天）
- [ ] 安装配置Blender MCP
- [ ] 验证Claude AI集成
- [ ] 测试基础建模功能

#### Phase 2: 玩家模型创建（2-3天）
- [ ] 设计玩家角色概念
- [ ] 使用AI生成基础模型
- [ ] 优化模型细节和纹理

#### Phase 3: 游戏引擎集成（3-4天）
- [ ] 完善PlayerModelLoader.swift
- [ ] 集成到Metal渲染管线
- [ ] 实现角色动画
- [ ] 测试性能优化

#### Phase 4: 功能扩展（后续）
- [ ] 多角色系统
- [ ] 装备系统
- [ ] 角色自定义

### 5. 技术风险评估

#### 5.1 潜在风险
- Blender MCP配置复杂度
- AI生成模型质量控制
- Metal渲染管线兼容性
- 性能优化挑战

#### 5.2 应对策略
- 详细记录配置步骤
- 建立模型质量检查标准
- 渐进式集成测试
- 持续性能监控

### 6. 备用方案

如果Blender MCP集成遇到困难，可以考虑：
1. 使用现有3D模型库
2. 程序化生成简单模型
3. 延后到V3版本实现

---

*最后更新: 2025年8月8日*
*状态: 规划阶段*
