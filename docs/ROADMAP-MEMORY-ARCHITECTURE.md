# 未来优化：按需加载记忆架构

> 状态：规划中 | 优先级：高 | 依赖：OpenClaw bootstrap 机制

---

## 问题

当前 OpenClaw 的 bootstrap 机制在**每一轮对话**（每次 agent turn）都将所有 MD 文件全量注入 system prompt：

```
SOUL.md + AGENTS.md + TOOLS.md + IDENTITY.md + USER.md
+ HEARTBEAT.md + BOOT.md + MEMORY.md
≈ 3000-3500 tokens/轮
```

20 轮对话 = 7 万 tokens 纯 bootstrap 消耗。这是一种"被动全量灌入"模式——agent 被迫每轮重新接收全部身份和规范信息，无论当前任务是否需要。

## 理想目标

**Agent as Master of OS**：Sisyphus 应该像操作系统的大脑中枢一样工作——

- 文件系统就是记忆的持久化层
- 记忆应该像 Skills 一样**主动发现、按需加载**，而不是被动全量注入
- 只需知道"记忆在哪"，需要时去检索，不需要每轮把所有知识重新加载

这和人类的认知模式一致：你不会每次说话前把所有知识重新加载一遍。

## OpenClaw Skills 已经验证了可行性

OpenClaw 的 Skills 机制就是按需加载的成功实践：

```
system prompt 只注入简短的技能列表（名称 + 路径）
  → agent 根据当前任务判断需要哪个 skill
  → 主动 read SKILL.md
  → 按指令执行
```

Bootstrap 文件应该采用同样的模式。

## 短期方案（当前 OpenClaw 架构下的变通）

### 最小 bootstrap（保留在 /workspace 根目录，每轮注入）

| 文件 | 理由 |
|------|------|
| `SOUL.md` | 核心身份，精简到极致（~800 tokens） |
| `IDENTITY.md` | 身份卡片（~100 tokens） |
| `USER.md` | 老板偏好，每轮都需要（~400 tokens） |

### 按需加载（移出根目录，agent 主动读取）

| 文件 | 迁移到 | 触发时机 |
|------|--------|----------|
| `AGENTS.md` | `docs/agents-handbook.md` | 需要记 worklog、述职时读取 |
| `TOOLS.md` | `docs/tools-handbook.md` | OpenClaw 已注入工具 schema，额外约定按需读取 |
| `MEMORY.md` | 删除 | memory_search 工具本身就是按需的 |
| `HEARTBEAT.md` | `docs/heartbeat-checklist.md` | 仅心跳 cron 触发时读取 |
| `BOOT.md` | `docs/boot-checklist.md` | 仅启动时执行一次 |

### 实现要点

1. `SOUL.md` 中增加一段"知识索引"，告诉 agent 各类规范文件的路径
2. 将非核心 MD 移到 `docs/` 子目录，脱离 bootstrap 自动注入范围
3. `skipBootstrap` 保持 `false`，让核心文件仍然自动注入
4. 测试验证 agent 能否在需要时主动读取迁移后的文件

### 预期效果

- 每轮 bootstrap 从 ~3500 tokens 降至 ~1300 tokens
- 20 轮对话节省 ~44,000 tokens
- agent 行为质量不下降（关键身份信息仍在，规范按需可达）

## 长期方向

### 文件系统即记忆

```
/workspace/
├── SOUL.md              ← 核心身份（始终注入）
├── memory/              ← 长期记忆（向量化索引，memory_search 检索）
│   ├── notepad/         ←   知识笔记
│   └── index/           ←   记忆索引
├── docs/                ← 规范和手册（agent 按需 read）
│   ├── agents-handbook.md
│   ├── tools-handbook.md
│   └── ...
└── worklog/             ← 工作日志（agent 主动维护）
```

- SOUL.md 是唯一的"固化身份"
- 其他所有知识都通过文件系统持久化 + 按需检索
- memory_search（向量化 + BM25）覆盖 memory/ 目录
- 规范类文件通过 read 工具按需加载
- 工作上下文通过 worklog/ 恢复（BOOT.md 指引）

### 需要 OpenClaw 支持的能力

| 能力 | 当前状态 | 说明 |
|------|----------|------|
| 选择性 bootstrap | 不支持 | `skipBootstrap` 是全有或全无，需要支持白名单 |
| bootstrap 路径配置 | 不支持 | 硬编码扫描 workspace 根目录，需要可配置 |
| memory_search 覆盖 docs/ | 需配置 | 可通过 `memorySearch.extraPaths` 实现 |
| 启动时自动执行 BOOT.md | 部分支持 | 可通过 heartbeat 或 cron 实现 |

### 可向 OpenClaw 提的 Feature Request

1. **`agents.defaults.bootstrap.include`**：允许指定哪些文件注入 system prompt（白名单模式）
2. **`agents.defaults.bootstrap.index`**：在 system prompt 中只注入文件索引（名称 + 路径 + 一句话摘要），不注入全文，让 agent 按需 read
3. 这本质上就是把 Skills 的"简短列表 + 按需 read"模式推广到所有 bootstrap 文件

---

## 相关文档

- OpenClaw bootstrap 机制：https://docs.openclaw.ai/start/bootstrapping
- System prompt 结构：https://docs.openclaw.ai/concepts/system-prompt
- Memory 系统：https://docs.openclaw.ai/concepts/memory
- Skills 机制：https://docs.openclaw.ai/tools/skills
