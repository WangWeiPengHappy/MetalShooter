#!/bin/bash

# MetalShooter 项目编译脚本
# 用法: ./build.sh [debug|release|clean|test]

PROJECT_DIR="/Users/eric_wang/Projects/TestProjects/Metal4/MetalShooter"
PROJECT_NAME="MetalShooter"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查是否在正确目录
check_directory() {
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    if [ ! -f "$PROJECT_NAME.xcodeproj/project.pbxproj" ]; then
        print_error "找不到 Xcode 项目文件"
        exit 1
    fi
    
    print_info "工作目录: $(pwd)"
}

# 编译函数
build_project() {
    local configuration=$1
    print_info "编译 $configuration 配置..."
    
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        -configuration "$configuration" \
        -sdk macosx \
        build
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "$configuration 编译成功!"
    else
        print_error "$configuration 编译失败 (退出码: $exit_code)"
        return $exit_code
    fi
}

# 清理函数
clean_project() {
    print_info "清理项目..."
    
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        clean
    
    if [ $? -eq 0 ]; then
        print_success "项目清理完成"
    else
        print_error "项目清理失败"
        return 1
    fi
}

# 运行测试
run_tests() {
    print_info "运行测试..."
    
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        -configuration Debug \
        -sdk macosx \
        test
    
    if [ $? -eq 0 ]; then
        print_success "测试通过"
    else
        print_error "测试失败"
        return 1
    fi
}

# 详细编译（显示错误）
verbose_build() {
    local configuration=${1:-Debug}
    print_info "详细编译 ($configuration)..."
    
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        -configuration "$configuration" \
        -sdk macosx \
        build \
        -verbose 2>&1 | tee "build_${configuration,,}.log"
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "详细编译完成，日志保存到 build_${configuration,,}.log"
    else
        print_error "编译失败，详细信息请查看 build_${configuration,,}.log"
    fi
    
    return $exit_code
}

# 显示帮助信息
show_help() {
    echo "MetalShooter 编译脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  debug     - 编译 Debug 配置 (默认)"
    echo "  release   - 编译 Release 配置"
    echo "  clean     - 清理项目"
    echo "  test      - 运行测试"
    echo "  verbose   - 详细编译输出"
    echo "  all       - 清理后编译 Debug 和 Release"
    echo "  help      - 显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 debug     # 编译 Debug 版本"
    echo "  $0 release   # 编译 Release 版本"
    echo "  $0 clean     # 清理项目"
    echo "  $0 all       # 完整编译流程"
}

# 主函数
main() {
    local command=${1:-debug}
    
    print_info "🚀 MetalShooter 编译脚本启动"
    print_info "命令: $command"
    
    check_directory
    
    case "$command" in
        "debug")
            build_project "Debug"
            ;;
        "release")
            build_project "Release"
            ;;
        "clean")
            clean_project
            ;;
        "test")
            run_tests
            ;;
        "verbose")
            verbose_build "Debug"
            ;;
        "all")
            clean_project && \
            build_project "Debug" && \
            build_project "Release" && \
            run_tests
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "🎉 操作完成!"
    else
        print_error "💥 操作失败!"
    fi
    
    exit $exit_code
}

# 运行主函数
main "$@"
