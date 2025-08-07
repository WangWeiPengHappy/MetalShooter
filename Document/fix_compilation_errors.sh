#!/bin/bash
# fix_compilation_errors.sh
# 修复Metal射击游戏项目中的常见编译错误

PROJECT_DIR="/Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter/MetalShooter"

echo "开始修复编译错误..."

# 1. 移除所有Swift文件中的@Published属性包装器
echo "移除@Published属性包装器..."
find "$PROJECT_DIR" -name "*.swift" -exec sed -i '' 's/@Published //g' {} \;

# 2. 修复组件类的协议继承问题
echo "修复组件协议继承..."
find "$PROJECT_DIR" -name "*Component.swift" -exec sed -i '' 's/: BaseComponent, ComponentType/: BaseComponent/g' {} \;

# 3. 移除冗余的类型ID定义
echo "移除冗余的类型ID定义..."
find "$PROJECT_DIR" -name "*Component.swift" -exec sed -i '' '/static let typeId:/d' {} \;
find "$PROJECT_DIR" -name "*Component.swift" -exec sed -i '' '/static let typeName:/d' {} \;

# 4. 添加适当的category重写
echo "添加组件分类..."
# 这部分需要手动处理，因为每个组件的分类可能不同

echo "编译错误修复完成!"
echo "请检查以下文件是否需要手动调整："
echo "- 组件分类设置"
echo "- 导入语句"
echo "- 缺失的类型定义"
