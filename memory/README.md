# Memory — 记忆系统

AI 助手的长期记忆，跨会话积累的知识资产。

## 目录结构

```
memory/
├── notepad/
│   ├── learnings/     # 经验教训："我踩过这个坑"
│   ├── references/    # 参考资料："我查到的有用信息"
│   └── patterns/      # 最佳实践："这个套路好用"
└── index/             # 记忆索引（未来可扩展为向量数据库）
```

## 写入规则

- 每条笔记使用独立的 Markdown 文件
- 文件名应有描述性，如 `docker-multistage-build.md`
- 文件开头注明创建日期和来源 session
- 定期回顾和整理，合并重复条目

## 示例

```markdown
# Docker 多阶段构建要点

> 来源：worklog/2026-02-07/session-a1b2.md
> 创建：2026-02-07

## 核心思路
- builder 阶段安装编译工具，runtime 阶段只保留运行时
- 频繁变化的层放后面，利用缓存
...
```
