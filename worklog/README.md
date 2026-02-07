# Worklog — 工作日志

按天记录每次会话的工作纪要，是述职的核心材料。

## 目录结构

```
worklog/
├── YYYY-MM-DD/
│   ├── session-{id}.md       # 单次会话纪要
│   └── daily-summary.md      # 当日自动汇总
└── weekly/
    └── YYYY-Www.md           # 周报
```

## 会话纪要模板

参见 [AGENTS.md](../AGENTS.md) 中的 session 纪要格式。

## 日报自动汇总

每天结束时（或被要求述职时），根据当天所有 session 文件生成 `daily-summary.md`。

## 周报

每周末聚合本周的重点产出，写入 `weekly/YYYY-Www.md`。
