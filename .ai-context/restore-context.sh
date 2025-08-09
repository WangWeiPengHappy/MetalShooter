#!/bin/bash

# AI上下文恢复脚本
echo "🤖 恢复AI对话上下文..."

# 显示最新的会话记录
LATEST_SESSION=$(ls -t .ai-context/session-*.md 2>/dev/null | head -1)

if [ -f "$LATEST_SESSION" ]; then
    echo "📋 找到最新会话记录: $LATEST_SESSION"
    echo ""
    cat "$LATEST_SESSION"
    echo ""
    echo "✅ 上下文恢复完成！"
    echo "💡 提示: 将上述内容复制给AI助手以恢复对话上下文"
else
    echo "❌ 未找到会话记录文件"
fi
