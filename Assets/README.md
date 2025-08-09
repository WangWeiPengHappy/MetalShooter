# MetalShooter Assets 资源管理

## 文件夹结构说明

### Models/ - 3D模型文件
- **Player/** - 玩家角色模型
- **Enemies/** - 敌人模型
- **Weapons/** - 武器模型
- **Environment/** - 环境物体模型

### Textures/ - 纹理贴图
- 各种材质的纹理文件（.png, .jpg等）

### Materials/ - 材质定义
- Metal材质配置文件
- 着色器参数设置

### Designs/ - 设计文档
- 角色设计说明
- 模型规格文档
- 概念图和参考资料

## 文件命名规范

### 模型文件
- 格式：`{类别}_{名称}_{版本}.{扩展名}`
- 示例：`player_geometric_warrior_v1.obj`

### 纹理文件
- 格式：`{对象}_{类型}_{尺寸}.{扩展名}`
- 示例：`warrior_diffuse_512.png`

### 材质文件
- 格式：`{对象}_material.json`
- 示例：`warrior_material.json`

## 版本控制
- v1: 初始版本
- v2: 功能迭代
- v3: 优化版本

---
*创建日期: 2025年8月8日*
