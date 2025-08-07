# Xcode 中手动创建 MetalShooter 项目流程

## 第一步：创建新项目

### 1. 启动 Xcode
- 打开 Xcode 应用程序
- 如果出现欢迎界面，点击 "Create a new Xcode project"
- 如果已经打开 Xcode，选择菜单 `File` → `New` → `Project...` (快捷键: Cmd+Shift+N)

### 2. 选择项目模板
- 在模板选择界面，选择 **macOS** 标签页
- 选择 **App** 模板
- 点击 **Next** 按钮

### 3. 配置项目信息
填写以下信息：
- **Product Name**: `MetalShooter`
- **Team**: 选择你的开发团队（如果有）
- **Organization Identifier**: `com.yourcompany.metalshooter`
- **Bundle Identifier**: 会自动生成为 `com.yourcompany.metalshooter`
- **Language**: 选择 **Swift**
- **Interface**: 选择 **AppKit** (重要！不要选择 SwiftUI)
- **Use Core Data**: ❌ 不勾选
- **Include Tests**: ✅ 勾选

点击 **Next** 按钮

### 4. 选择保存位置
- 导航到 `/Users/eric_wang/Projects/TestProjects/Metal4/`
- 确认 "Create Git repository on my Mac" 已勾选
- 点击 **Create** 按钮

## 第二步：配置 Metal 框架

### 1. 添加 Metal 框架
- 在项目导航器中选择项目文件 (`MetalShooter.xcodeproj`)
- 选择 **MetalShooter** target
- 切换到 **General** 标签页
- 滚动到 **Frameworks, Libraries, and Embedded Content** 部分
- 点击 **+** 按钮
- 搜索并添加以下框架：
  - `Metal.framework`
  - `MetalKit.framework` 
  - `GameController.framework`
  - `AVFoundation.framework`
  - `CoreAudio.framework`

### 2. 配置构建设置
在 **Build Settings** 标签页中：
- 搜索 "Metal"
- 设置 **Metal Compiler - Options**:
  - `MTL_ENABLE_DEBUG_INFO` = YES (Debug 配置)
  - `MTL_ENABLE_DEBUG_INFO` = NO (Release 配置)
- 设置 **Deployment Target**: `macOS 12.0`

## 第三步：导入项目文件结构

### 1. 运行准备脚本
在终端中执行：
```bash
cd /Users/eric_wang/Projects/TestProjects/Metal4
./create_project.sh
```

### 2. 将文件夹导入 Xcode
- 在 Finder 中打开生成的 `MetalShooter` 文件夹
- 选择所有子文件夹（Application, Engine, ECS, Rendering 等）
- 将它们拖拽到 Xcode 项目导航器中的 `MetalShooter` 文件夹内
- 在弹出的对话框中选择：
  - ✅ Copy items if needed
  - ✅ Create groups
  - ✅ Add to target: MetalShooter
- 点击 **Finish**

### 3. 组织项目结构
在 Xcode 中重新整理文件夹，确保结构如下：
```
MetalShooter/
├── Application/
├── Engine/
├── ECS/
├── Rendering/
├── Shaders/
├── Physics/
├── AI/
├── Input/
├── Audio/
├── Gameplay/
├── World/
├── UI/
├── Resources/
├── Utilities/
└── Configuration/
```

## 第四步：配置 Metal 着色器

### 1. 设置着色器编译
- 选择项目文件，进入 **Build Rules**
- 点击 **+** 添加新规则
- **Process**: `Source files with names matching: *.metal`
- **Using**: `Metal Compiler`
- **Output Files**: `$(DERIVED_FILE_DIR)/$(INPUT_FILE_BASE).air`

### 2. 创建着色器库
- 在 **Build Phases** 中，展开 **Copy Bundle Resources**
- 确保所有 `.metal` 文件都在其中

## 第五步：项目最终配置

### 1. 更新 Info.plist
确保 Info.plist 包含：
```xml
<key>LSMinimumSystemVersion</key>
<string>12.0</string>
<key>NSHighResolutionCapable</key>
<true/>
<key>NSSupportsAutomaticGraphicsSwitching</key>
<true/>
```

### 2. 配置 App Transport Security (如果需要网络功能)
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

### 3. 设置启动参数 (可选)
在 **Edit Scheme** → **Run** → **Arguments** 中添加：
- Environment Variables:
  - `MTL_DEBUG_LAYER = 1` (Debug 时启用 Metal 调试)
  - `MTL_SHADER_VALIDATION = 1` (启用着色器验证)

## 第六步：验证项目设置

### 1. 编译测试
- 按 `Cmd+B` 编译项目
- 确保没有编译错误

### 2. 运行测试
- 按 `Cmd+R` 运行项目
- 应该看到控制台输出 "MetalShooter 启动完成"

### 3. 检查框架链接
在 **Build Phases** → **Link Binary With Libraries** 中确认所有 Metal 相关框架都已正确链接。

## 快速检查清单

创建完成后，确认以下项目：
- [ ] 项目名称为 MetalShooter
- [ ] Bundle ID 为 com.yourcompany.metalshooter  
- [ ] 已添加 Metal, MetalKit, GameController 框架
- [ ] 最低部署目标为 macOS 12.0
- [ ] 文件结构按模块组织
- [ ] .metal 文件设置了正确的构建规则
- [ ] 项目可以成功编译和运行

## 下一步开发建议

1. **先实现基础架构**：GameEngine, EntityManager, MetalRenderer
2. **创建简单场景**：显示一个三角形或立方体
3. **添加输入处理**：键盘和鼠标控制
4. **逐步完善系统**：物理、AI、音频等

这样你就有了一个完整的、可工作的 MetalShooter 项目基础！
