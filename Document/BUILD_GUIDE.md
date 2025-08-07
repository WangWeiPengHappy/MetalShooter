# XcodeBuild 编译指南

## 基本编译命令

### 1. 编译项目（Debug 配置）
```bash
cd /Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build
```

### 2. 编译项目（Release 配置）
```bash
cd /Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Release build
```

### 3. 清理后重新编译
```bash
# 清理
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter clean

# 清理后编译
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug clean build
```

### 4. 指定目标平台编译
```bash
# 编译 macOS 版本
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -sdk macosx -configuration Debug build

# 如果支持 iOS（目前项目是 macOS）
# xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -sdk iphoneos -configuration Debug build
```

## 高级编译选项

### 5. 详细输出（查看具体编译错误）
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build -verbose
```

### 6. 仅检查语法（不生成二进制文件）
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

### 7. 并行编译（加快编译速度）
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build -jobs 8
```

### 8. 指定输出目录
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build \
  CONFIGURATION_BUILD_DIR=/Users/eric_wang/Projects/TestProjects/Metal4/Build
```

## 测试相关命令

### 9. 运行单元测试
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug test
```

### 10. 运行 UI 测试
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug test -testPlan MetalShooterUITests
```

## 编译脚本示例

### 完整编译脚本 (build.sh)
```bash
#!/bin/bash

PROJECT_DIR="/Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter"
PROJECT_NAME="MetalShooter"

cd "$PROJECT_DIR"

echo "🚀 开始编译 $PROJECT_NAME..."

# 清理项目
echo "🧹 清理项目..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" clean

# 编译 Debug 版本
echo "🔨 编译 Debug 版本..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$PROJECT_NAME" \
  -configuration Debug \
  -sdk macosx \
  build

if [ $? -eq 0 ]; then
    echo "✅ Debug 编译成功!"
    
    # 可选：编译 Release 版本
    echo "🔨 编译 Release 版本..."
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
      -scheme "$PROJECT_NAME" \
      -configuration Release \
      -sdk macosx \
      build
    
    if [ $? -eq 0 ]; then
        echo "✅ Release 编译成功!"
        echo "🎉 所有编译完成！"
    else
        echo "❌ Release 编译失败"
        exit 1
    fi
else
    echo "❌ Debug 编译失败"
    exit 1
fi
```

## 常见编译参数说明

- **-project**: 指定 .xcodeproj 文件
- **-scheme**: 指定编译方案
- **-configuration**: 指定编译配置（Debug/Release）
- **-sdk**: 指定 SDK（macosx/iphoneos/iphonesimulator）
- **-verbose**: 显示详细编译信息
- **-jobs**: 指定并行编译任务数
- **clean**: 清理编译产物
- **build**: 执行编译
- **test**: 运行测试

## 编译错误处理

### 查看详细错误信息
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build 2>&1 | tee build.log
```

### 只显示错误和警告
```bash
xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build 2>&1 | grep -E "(error:|warning:)"
```

### 统计编译时间
```bash
time xcodebuild -project MetalShooter.xcodeproj -scheme MetalShooter -configuration Debug build
```

## 自动化集成

### 持续集成脚本
```bash
# 用于 CI/CD 的编译脚本
#!/bin/bash
set -e  # 遇到错误立即退出

# 设置环境变量
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# 编译并测试
xcodebuild -project MetalShooter.xcodeproj \
  -scheme MetalShooter \
  -configuration Debug \
  -sdk macosx \
  clean build test \
  CODE_SIGNING_ALLOWED=NO \
  | xcpretty
```

## 推荐的编译流程

1. **首次编译**：使用清理后编译
2. **日常开发**：使用增量编译
3. **发布前**：使用 Release 配置编译
4. **调试问题**：使用 verbose 选项查看详细信息
