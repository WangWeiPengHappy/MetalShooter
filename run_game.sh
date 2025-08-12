#!/usr/bin/env bash
# 游戏运行脚本 run_game.sh (合并原 run_app.sh / run_debug.sh / run_simple.sh)
# 功能:
#  - 编译 (可选自定义 DerivedData)
#  - 同步 Assets 资源进 .app/Contents/Resources/Assets
#  - 可选: 仅打印关键日志/完整跟随日志/直接打开 Finder GUI
#  - 默认行为: 构建 + 运行 + tail 跟随日志

set -euo pipefail

SCHEME="MetalShooter"
CONFIG="Debug"
DERIVED_DIR="DerivedSimple"        # 可通过 --derived 指定
LOG_DIR="logs"                      # 输出日志目录
MODE="run"                         # run | keylog | open
KEYLOG_FILTER='PlayerModel外部OBJ解析|选定OBJ文件|外部OBJ模型加载成功|玩家模型包围盒|玩家模型为空|索引数量为0|渲染状态调试|开始渲染玩家模型'
QUIET_BUILD=1

usage() {
  cat <<EOF
用法: run_game.sh [选项]
  --config Debug|Release      设置编译配置 (默认 Debug)
  --derived PATH              自定义 derivedDataPath (默认 DerivedSimple)
  --mode run|keylog|open      运行模式:
                                run    构建并运行, 完整日志 tail (默认)
                                keylog 构建并截取关键初始化日志后 GUI 打开
                                open   构建后仅 GUI 启动 (不重定向日志)
  --verbose-build             显示编译详细输出 (取消 -quiet)
  -h|--help                   显示此帮助
示例:
  ./run_game.sh --mode run
  ./run_game.sh --mode keylog --config Release
  ./run_game.sh --derived /tmp/D1 --verbose-build
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2;;
    --derived) DERIVED_DIR="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --verbose-build) QUIET_BUILD=0; shift;;
    -h|--help) usage; exit 0;;
    *) echo "未知参数: $1"; usage; exit 1;;
  esac
done

mkdir -p "$LOG_DIR"
TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/run_${MODE}_${TS}.log"

echo "[build] $SCHEME ($CONFIG) -> $DERIVED_DIR" | tee "$LOG_FILE"
if [[ $QUIET_BUILD -eq 1 ]]; then
  xcodebuild -project MetalShooter.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" -derivedDataPath "$DERIVED_DIR" -quiet build >>"$LOG_FILE" 2>&1
else
  xcodebuild -project MetalShooter.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" -derivedDataPath "$DERIVED_DIR" build 2>&1 | tee -a "$LOG_FILE"
fi

APP_BUNDLE="$DERIVED_DIR/Build/Products/$CONFIG/MetalShooter.app"
APP_EXE="$APP_BUNDLE/Contents/MacOS/MetalShooter"
[[ -x "$APP_EXE" ]] || { echo "[error] 构建产物不存在: $APP_EXE" | tee -a "$LOG_FILE"; exit 2; }

# 同步 Assets
if [[ -d Assets ]]; then
  rsync -a Assets/ "$APP_BUNDLE/Contents/Resources/Assets/" >>"$LOG_FILE" 2>&1 || true
fi

# 列表玩家模型目录
if [[ -d "$APP_BUNDLE/Contents/Resources/Assets/Models/Player" ]]; then
  echo "[info] Player 目录:" >>"$LOG_FILE"
  ls -1 "$APP_BUNDLE/Contents/Resources/Assets/Models/Player" >>"$LOG_FILE" 2>&1 || true
fi

case "$MODE" in
  keylog)
    echo "[mode] keylog: 捕获关键初始化日志" | tee -a "$LOG_FILE"
    "$APP_EXE" 2>&1 | egrep "$KEYLOG_FILTER" | sed -n '1,150p' | tee -a "$LOG_FILE" || true
    echo "[open] GUI 启动" | tee -a "$LOG_FILE"
    open "$APP_BUNDLE"
    echo "[done] 关键日志已写入: $LOG_FILE" | tee -a "$LOG_FILE"
    ;;
  open)
    echo "[mode] open: 仅 GUI 启动 (日志记录在构建阶段)" | tee -a "$LOG_FILE"
    open "$APP_BUNDLE"
    echo "[done] 已启动: $APP_BUNDLE (构建日志: $LOG_FILE)" | tee -a "$LOG_FILE"
    ;;
  run|*)
    echo "[run] 启动应用 (完整日志 -> $LOG_FILE)" | tee -a "$LOG_FILE"
    "$APP_EXE" >>"$LOG_FILE" 2>&1 &
    PID=$!
    echo "[info] PID=$PID" | tee -a "$LOG_FILE"
    echo "[follow] tail -f (Ctrl+C 结束跟随, 不影响进程)" | tee -a "$LOG_FILE"
    tail -f "$LOG_FILE" &
    TAILPID=$!
    wait $PID || true
    kill $TAILPID 2>/dev/null || true
    echo "[done] 退出. 日志: $LOG_FILE" | tee -a "$LOG_FILE"
    ;;
esac

exit 0
