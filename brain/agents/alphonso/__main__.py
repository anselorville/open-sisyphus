"""Alphonso Agent — 命令行入口。

使用方式：
    # 交互模式（默认）
    python -m brain.agents.alphonso

    # 单次任务模式
    python -m brain.agents.alphonso "查找 Python 3.13 新特性"
"""

from __future__ import annotations

import asyncio
import logging
import sys

from .agent import AlphonsoAgent

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("alphonso")


async def interactive_mode(agent: AlphonsoAgent) -> None:
    """交互模式：反复接受用户输入并执行检索。"""
    print("Alphonso Agent 已启动（交互模式）。输入需求开始检索，输入 'quit' 退出。\n", file=sys.stderr)
    while True:
        try:
            task = input(">>> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not task or task.lower() in ("quit", "exit", "q"):
            break
        result = await agent.run(task)
        print(result)
        print()  # 空行分隔


async def single_task_mode(agent: AlphonsoAgent, task: str) -> None:
    """单次任务模式：执行一次检索后退出。"""
    result = await agent.run(task)
    print(result)


async def main() -> None:
    agent = AlphonsoAgent()
    try:
        await agent.start()
        if len(sys.argv) > 1:
            task = " ".join(sys.argv[1:])
            await single_task_mode(agent, task)
        else:
            await interactive_mode(agent)
    finally:
        await agent.stop()


if __name__ == "__main__":
    asyncio.run(main())
