"""Alphonso Agent 配置。"""

import os

# ── LLM ──────────────────────────────────────────────────────────────────────
# 支持 anthropic / openai，默认 anthropic
LLM_PROVIDER = os.getenv("ALPHONSO_LLM_PROVIDER", "anthropic")

# Anthropic
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
ANTHROPIC_MODEL = os.getenv("ALPHONSO_MODEL", "claude-sonnet-4-20250514")

# OpenAI（备用）
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("ALPHONSO_OPENAI_MODEL", "gpt-4o")

# LLM 参数
MAX_TOKENS = int(os.getenv("ALPHONSO_MAX_TOKENS", "4096"))
TEMPERATURE = float(os.getenv("ALPHONSO_TEMPERATURE", "0.0"))

# ── Playwright MCP Server ────────────────────────────────────────────────────
# 通过 stdio 启动 Playwright MCP Server 的命令
# @playwright/mcp 是 npm 包，运行后提供 MCP 工具（navigate、click 等）
PLAYWRIGHT_MCP_COMMAND = os.getenv(
    "PLAYWRIGHT_MCP_COMMAND",
    "npx",
)
PLAYWRIGHT_MCP_ARGS = os.getenv(
    "PLAYWRIGHT_MCP_ARGS",
    "@playwright/mcp --headless --no-sandbox",
).split()

# ── Agent 行为 ───────────────────────────────────────────────────────────────
# 单次任务最大 LLM 循环轮数（防止无限循环）
MAX_ITERATIONS = int(os.getenv("ALPHONSO_MAX_ITERATIONS", "20"))

# 是否在 stderr 打印调试信息
DEBUG = os.getenv("ALPHONSO_DEBUG", "0") == "1"
