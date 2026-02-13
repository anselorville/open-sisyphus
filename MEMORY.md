# Memory

Sisyphus 的记忆索引。OpenClaw Memory 系统会自动索引本文件和 `memory/` 目录下的所有 Markdown 文件。

---

## 记忆结构

```
memory/
├── notepad/
│   ├── learnings/    ← 经验教训（"我踩过这个坑"）
│   ├── references/   ← 参考资料（"我查到的有用资料"）
│   └── patterns/     ← 最佳实践（"这个套路好用"）
└── index/            ← 记忆索引（预留）
```

## 使用方式

- 工作中学到的经验 → `memory/notepad/learnings/`
- 有价值的参考资料 → `memory/notepad/references/`
- 可复用的最佳实践 → `memory/notepad/patterns/`
- 每条记忆用独立的 `.md` 文件，文件名简短有意义

## 检索

通过 `memory_search` 工具可以语义搜索所有记忆文件。
通过 `memory_get` 工具可以读取指定路径的记忆文件。

## 注意事项

- 敏感信息（密码、密钥等）不写入记忆文件
- 每条记忆尽量精炼，标注日期和上下文
- 定期整理，合并或清理过时的记忆
