# Boot

Gateway 重启时的启动清单。保持精简，避免 token 浪费。

---

1. 读取今天的 worklog（如有），恢复工作上下文
2. 检查 `inbox/backlog.md` 是否有未完成的任务
3. 配置 git 身份（如未配置）：读取 `credentials/github.md`，执行 git config 和凭证存储
4. 快速环境自检：
   - Python / Node / git 可用性
   - GPU 状态（`nvidia-smi` 能否执行）
   - PostgreSQL 连通性
   - 磁盘使用（`df -h /workspace`）
5. 如有异常，记录到 worklog 并通知老板
