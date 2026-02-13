# 行为规范

工作流程和协作准则。自律准则见 `SOUL.md`。

---

## 工作记录

每次对话在 `worklog/` 留下记录：

```
worklog/YYYY-MM-DD/
├── session-{id}.md      # 对话纪要
└── daily-summary.md     # 当日汇总
```

**纪要格式**：

```markdown
# Session {id} | {date} {start_time} - {end_time}
## 来源
Channel: {渠道} / User: {对话人}
## 任务
{任务描述}
## 执行过程
1. {步骤}
## 结论/产出
- {产出}
## 小结
{耗时} | {关键指标}
```

---

## 知识沉淀

| 类型 | 目录 |
|------|------|
| 经验教训 | `memory/notepad/learnings/` |
| 参考资料 | `memory/notepad/references/` |
| 最佳实践 | `memory/notepad/patterns/` |

---

## 任务管理

- 新任务 → `inbox/backlog.md`
- 被阻塞 → `inbox/blocked.md`（标注原因）
- 灵感想法 → `inbox/ideas.md`
- 完成 → 归档到 `worklog/` session

---

## 产出管理

| 类型 | 目录 |
|------|------|
| 报告 | `artifacts/reports/` |
| 导出文件 | `artifacts/exports/` |
| 截图/快照 | `artifacts/snapshots/` |

---

## 对话渠道

通过 OpenClaw Gateway 连接外部渠道。配置：`config/openclaw.json`。

| 渠道 | 说明 |
|------|------|
| **飞书** | 私聊 + 群聊（@mention），流式回复，图片/文件 |

添加渠道：`openclaw channels add` → `openclaw gateway restart`

---

## 助手团队

### Alphonso — 深度检索

- 启动：`python -m brain.agents.alphonso "查询内容"`
- 输出：信息摘要（标注来源和可信度）
- 底线：遇到登录墙/验证码如实报告，不绕过；查到的信息标注来源

---

## 述职

被要求述职时提供：

1. 当日工作汇报（`worklog/{today}/daily-summary.md`）
2. 周报（`worklog/weekly/YYYY-Www.md`）
3. 知识积累盘点（`memory/notepad/` 条目统计）
4. 待办状态（`inbox/`）
5. 环境健康（磁盘、GPU、服务状态）
