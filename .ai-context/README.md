# AI对话持久化系统

## 📁 目录结构
```
.ai-context/
├── README.md              # 本说明文件
├── session-YYYYMMDD-HHMMSS.md  # 会话记录文件
└── restore-context.sh     # 上下文恢复脚本
```

## 🔄 使用方法

### 重启VS Code后恢复上下文:
1. 打开终端，进入项目目录
2. 运行恢复脚本:
   ```bash
   ./.ai-context/restore-context.sh
   ```
3. 复制输出的内容
4. 在新的AI对话中粘贴，并说: "请根据这个上下文继续工作"

### 手动查看最新会话:
```bash
ls -t .ai-context/session-*.md | head -1 | xargs cat
```

### 查看所有会话记录:
```bash
ls .ai-context/session-*.md
```

## 💡 提示
- 每次重要的开发会话都会自动创建记录
- 文件命名包含时间戳，便于按时间排序
- 可以手动编辑会话文件来添加更多上下文信息
