#!/bin/bash

# MetalShooter Xcode 项目创建脚本
# 使用方法: ./create_project.sh

PROJECT_NAME="MetalShooter"
PROJECT_DIR="/Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter"
BUNDLE_ID="com.yourcompany.metalshooter"

echo "🚀 开始创建 MetalShooter 项目结构..."

# 检查是否安装了 Xcode 命令行工具
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 xcodebuild 命令"
    echo "请先安装 Xcode 命令行工具: xcode-select --install"
    exit 1
fi

# 创建项目目录结构
echo "📁 创建目录结构..."

# 主应用程序目录
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Application"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Engine/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Engine/Scene"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Engine/Math"

# ECS 系统
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/ECS/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/ECS/Components"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/ECS/Systems"

# 渲染系统
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Rendering/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Rendering/Passes"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Rendering/Resources"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Rendering/Lighting"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Rendering/Optimization"

# Metal 着色器
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Shaders/Common"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Shaders/Geometry"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Shaders/Lighting"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Shaders/PostProcess"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Shaders/Compute"

# 其他系统
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Physics/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Physics/Collision"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/AI/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/AI/States"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Input/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Audio/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Gameplay/Player"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Gameplay/Weapons"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/UI/HUD"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Resources/Core"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Utilities/Extensions"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Configuration"

# 资源目录
mkdir -p "$PROJECT_DIR/Assets/Textures"
mkdir -p "$PROJECT_DIR/Assets/Models"
mkdir -p "$PROJECT_DIR/Assets/Audio"
mkdir -p "$PROJECT_DIR/Assets/Shaders"

# 测试目录
mkdir -p "$PROJECT_DIR/${PROJECT_NAME}Tests"
mkdir -p "$PROJECT_DIR/${PROJECT_NAME}UITests"

echo "✅ 目录结构创建完成"

# 创建基础文件
echo "📝 创建基础配置文件..."

# Info.plist
cat > "$PROJECT_DIR/$PROJECT_NAME/Application/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>\$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 基础 Swift 文件模板
cat > "$PROJECT_DIR/$PROJECT_NAME/Application/AppDelegate.swift" << 'EOF'
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        print("MetalShooter 启动完成")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
EOF

echo "✅ 基础文件创建完成"

# 创建 README
cat > "$PROJECT_DIR/README.md" << EOF
# MetalShooter

基于 Metal 4 的 macOS 第一人称射击游戏

## 系统要求
- macOS 12.0+
- Xcode 14.0+
- Apple Silicon 或 Intel Mac

## 项目结构
请参考 MetalShooter-FileStructure.md 文件

## 构建说明
1. 打开 MetalShooter.xcodeproj
2. 选择目标设备
3. 按 Cmd+R 运行

## 开发团队
- 主程序员: [Your Name]
- 图形程序员: [Your Name] 
- 游戏设计师: [Your Name]

EOF

echo "📋 项目文档创建完成"

# 显示下一步操作
echo ""
echo "🎉 MetalShooter 项目结构创建完成!"
echo ""
echo "⚠️  下一步需要手动操作:"
echo "1. 打开 Xcode"
echo "2. File → New → Project"
echo "3. 选择 macOS → App"
echo "4. 配置项目信息:"
echo "   - Product Name: $PROJECT_NAME"
echo "   - Bundle Identifier: $BUNDLE_ID"
echo "   - Language: Swift"
echo "   - Interface: AppKit"
echo "5. 选择项目保存位置: $PROJECT_DIR"
echo "6. 将创建的文件夹结构导入到 Xcode 项目中"
echo ""
echo "📍 项目位置: $PROJECT_DIR"
echo "📖 查看完整文件结构: cat MetalShooter-FileStructure.md"

# 打开项目目录
if command -v open &> /dev/null; then
    echo "🔍 打开项目目录..."
    open "$PROJECT_DIR"
fi

echo ""
echo "✨ 脚本执行完成!"
