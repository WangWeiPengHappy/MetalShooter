#!/bin/bash

# 快速编译测试脚本
# 用于快速检查项目是否可以成功编译

PROJECT_DIR="/Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter"
PROJECT_NAME="MetalShooter"

echo "🔍 快速编译测试..."
echo "项目: $PROJECT_NAME"
echo "路径: $PROJECT_DIR"
echo

cd "$PROJECT_DIR"

# 记录开始时间
START_TIME=$(date +%s)

echo "🚀 开始编译..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -configuration Debug \
    -sdk macosx \
    build \
    CODE_SIGNING_ALLOWED=NO \
    2>&1

# 记录结束时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo
echo "⏱️  编译耗时: ${DURATION} 秒"

# 检查编译结果
if [ $? -eq 0 ]; then
    echo "✅ 编译成功！"
    
    # 显示生成的文件信息
    echo
    echo "📦 编译产物:"
    find . -name "*.app" -type d 2>/dev/null | head -3
    
    echo
    echo "🎉 项目可以正常编译！"
else
    echo "❌ 编译失败！"
    echo
    echo "💡 建议检查:"
    echo "- 代码语法错误"
    echo "- 缺失的依赖"
    echo "- 导入语句问题"
    echo "- 类型定义缺失"
    
    exit 1
fi
