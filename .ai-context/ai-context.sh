#!/usr/bin/env bash
# 通用 AI 会话工具脚本
# 统一: 保存(save) / 恢复(restore) / 列出(list) / 查看(show) / 搜索(grep) / 帮助(help)
#
# 用法示例:
#   1) 交互式保存:       ./.ai-context/ai-context.sh save
#   2) 从文件保存:       ./.ai-context/ai-context.sh save -f notes.md -t "阶段总结"
#   3) 管道保存:         some_cmd | ./.ai-context/ai-context.sh save -t Pipeline
#   4) 恢复最新会话:     ./.ai-context/ai-context.sh restore
#   5) 列出会话:         ./.ai-context/ai-context.sh list
#   6) 查看指定文件:     ./.ai-context/ai-context.sh show session-20250812-120000.md
#   7) 关键词搜索:       ./.ai-context/ai-context.sh grep PlayerModel
#   8) 仅输出文件路径:   ./.ai-context/ai-context.sh latest --path
#   9) 编辑最近会话:     ./.ai-context/ai-context.sh edit
#  10) 帮助:            ./.ai-context/ai-context.sh help
#
# 子命令概览:
#   save      保存一份新的会话记录
#   restore   输出最新会话内容(兼容旧 restore-context.sh 行为)
#   latest    显示/返回最新会话文件路径或内容
#   list      列出所有会话文件
#   show      显示指定会话文件内容
#   grep      在所有会话中搜索关键词
#   edit      用编辑器打开最新(或指定)会话
#   help|-h   显示帮助
#
# 环境变量:
#   AI_CONTEXT_DIR  (默认脚本所在目录)
#   EDITOR          (默认 code; 可设置为 vim / nano / subl 等)
#
# 退出码:
#   0 成功
#   1 通用错误/参数错误
#   2 未找到文件或内容为空

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CTX_DIR="${AI_CONTEXT_DIR:-$SCRIPT_DIR}"
EDITOR_CMD="${EDITOR:-code}"

ensure_dir() { mkdir -p "$CTX_DIR"; }

ts() { date +%Y%m%d-%H%M%S; }

latest_file() {
  ls -t "$CTX_DIR"/session-*.md 2>/dev/null | head -1 || true
}

print_header() {
  local iso
  iso="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "# 🤖 AI 会话记录 - ${iso}"
}

cmd_save() {
  ensure_dir
  local title="" src_file="" open_editor=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--title) title="$2"; shift 2;;
      -f|--file) src_file="$2"; shift 2;;
      -e|--edit) open_editor=1; shift;;
      -h|--help) grep '^#' "$0" | sed 's/^# \\{0,1\}//'; exit 0;;
      *) echo "[save] 未知参数: $1" >&2; exit 1;;
    esac
  done
  local content=""
  if [[ -n "$src_file" ]]; then
    [[ -f "$src_file" ]] || { echo "源文件不存在: $src_file" >&2; exit 2; }
    content="$(cat "$src_file")"
  else
    if [[ -t 0 ]]; then
      echo "请输入要保存的内容，结束请按 Ctrl+D:" >&2
    fi
    content="$(cat || true)"
  fi
  if [[ -z "$content" ]]; then
    echo "[warn] 没有读取到内容，创建空模板" >&2
  fi
  local filename="session-$(ts).md"
  local outfile="$CTX_DIR/$filename"
  {
    print_header
    [[ -n "$title" ]] && echo -e "\n> 标题: ${title}"
    echo -e "\n---\n"
    if [[ -n "$content" ]]; then
      echo "$content"
    else
      echo "(空会话内容，后续可补充)"
    fi
    echo -e "\n---\n(使用 ai-context.sh save 生成: $(date +%Y%m%d-%H%M%S))"
  } > "$outfile"
  echo "✅ 已保存: $outfile"
  if [[ $open_editor -eq 1 ]]; then
    echo "打开编辑器: $EDITOR_CMD $outfile"
    $EDITOR_CMD "$outfile" >/dev/null 2>&1 &
  fi
}

cmd_restore() {
  local f
  f="$(latest_file)"
  if [[ -z "$f" ]]; then
    echo "❌ 未找到会话记录文件" >&2; exit 2
  fi
  echo "🤖 恢复AI对话上下文..."
  echo "📋 最新会话: $f\n"
  cat "$f"
  echo -e "\n✅ 上下文恢复完成！\n💡 提示: 将上述内容复制给AI助手以恢复对话上下文"
}

cmd_latest() {
  local path_only=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path) path_only=1; shift;;
      *) echo "[latest] 未知参数: $1" >&2; exit 1;;
    esac
  done
  local f
  f="$(latest_file)"
  [[ -n "$f" ]] || { echo "(无会话文件)"; exit 2; }
  if [[ $path_only -eq 1 ]]; then
    echo "$f"
  else
    cat "$f"
  fi
}

cmd_list() {
  ensure_dir
  local files
  files=$(ls -t "$CTX_DIR"/session-*.md 2>/dev/null || true)
  if [[ -z "$files" ]]; then
    echo "(暂无会话文件)"; return 0
  fi
  echo "$files"
}

cmd_show() {
  local target="$1"; shift || true
  [[ -n "$target" ]] || { echo "用法: show <filename|latest>" >&2; exit 1; }
  if [[ "$target" == latest ]]; then
    target="$(latest_file)"
  elif [[ ! -f "$CTX_DIR/$target" ]]; then
    # 允许传绝对/相对路径
    if [[ -f "$target" ]]; then
      :
    else
      echo "文件不存在: $target" >&2; exit 2
    fi
  else
    target="$CTX_DIR/$target"
  fi
  cat "$target"
}

cmd_grep() {
  [[ $# -gt 0 ]] || { echo "用法: grep <pattern>" >&2; exit 1; }
  local pattern="$1"; shift
  local files
  files=$(ls "$CTX_DIR"/session-*.md 2>/dev/null || true)
  [[ -n "$files" ]] || { echo "(无会话文件)"; exit 2; }
  grep -Hn --color=always -E "$pattern" $files || true
}

cmd_edit() {
  local f
  f="$(latest_file)"
  if [[ -z "$f" ]]; then
    echo "(暂无会话文件, 先创建)" >&2
    cmd_save -e "$@"
    return
  fi
  echo "打开: $EDITOR_CMD $f"
  $EDITOR_CMD "$f" >/dev/null 2>&1 &
}

show_help() { grep '^# ' "$0" | sed 's/^# //' ; }

main() {
  local cmd="${1:-help}"; [[ $# -gt 0 ]] && shift || true
  case "$cmd" in
    save)     cmd_save "$@";;
    restore)  cmd_restore "$@";;
    latest)   cmd_latest "$@";;
    list|ls)  cmd_list "$@";;
    show|cat) cmd_show "$@";;
    grep|search) cmd_grep "$@";;
    edit)     cmd_edit "$@";;
    help|-h|--help) show_help;;
    *) echo "未知子命令: $cmd" >&2; show_help; exit 1;;
  esac
}

main "$@"
