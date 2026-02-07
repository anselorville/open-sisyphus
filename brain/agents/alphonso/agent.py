"""Alphonso Agent — 核心推理循环。

架构：
    用户/主 Agent  ──(需求)──►  Alphonso Agent  ──(MCP tool call)──►  Playwright MCP Server
                   ◄──(精炼结果)──               ◄──(tool result)──   (headless Chrome)

Alphonso 作为一个独立 Agent：
    1. 接收自然语言需求
    2. 用 LLM 推理出下一步操作
    3. 通过 MCP 调用 Playwright 操控浏览器
    4. LLM 根据工具返回的结果决定继续操作还是返回最终答案
    5. 循环直到任务完成或达到最大迭代次数
"""

from __future__ import annotations

import json
import logging
import sys
from typing import Any

import anthropic

from . import config, prompts
from .mcp_client import PlaywrightMCPClient

logger = logging.getLogger("alphonso.agent")


class AlphonsoAgent:
    """Web 信息检索 Agent：LLM 推理 + Playwright MCP 工具调用。"""

    def __init__(self) -> None:
        self._mcp = PlaywrightMCPClient()
        self._client: anthropic.AsyncAnthropic | None = None

    # ------------------------------------------------------------------
    # 生命周期
    # ------------------------------------------------------------------

    async def start(self) -> None:
        """启动 Agent：连接 Playwright MCP Server，初始化 LLM 客户端。"""
        # 连接 Playwright MCP
        await self._mcp.connect()

        # 初始化 LLM 客户端
        if config.LLM_PROVIDER == "anthropic":
            self._client = anthropic.AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)
        else:
            raise ValueError(f"Unsupported LLM provider: {config.LLM_PROVIDER}")

        logger.info(
            "Alphonso Agent started. Provider=%s, Model=%s, Tools=%d",
            config.LLM_PROVIDER,
            config.ANTHROPIC_MODEL,
            len(self._mcp.tools),
        )

    async def stop(self) -> None:
        """停止 Agent：断开 MCP 连接。"""
        await self._mcp.disconnect()
        logger.info("Alphonso Agent stopped.")

    # ------------------------------------------------------------------
    # 核心推理循环
    # ------------------------------------------------------------------

    async def run(self, task: str) -> str:
        """执行一次信息检索任务。

        Args:
            task: 自然语言描述的需求，例如 "查找 Python 3.13 的新特性"

        Returns:
            精炼后的结果文本
        """
        if self._client is None:
            raise RuntimeError("Agent not started. Call start() first.")

        logger.info("Task: %s", task[:200])

        # 构建初始消息
        messages: list[dict[str, Any]] = [
            {"role": "user", "content": task},
        ]

        tools = self._mcp.tools_for_anthropic

        for iteration in range(1, config.MAX_ITERATIONS + 1):
            logger.info("--- Iteration %d/%d ---", iteration, config.MAX_ITERATIONS)

            # 调用 LLM
            response = await self._client.messages.create(
                model=config.ANTHROPIC_MODEL,
                max_tokens=config.MAX_TOKENS,
                temperature=config.TEMPERATURE,
                system=prompts.SYSTEM_PROMPT,
                tools=tools,
                messages=messages,
            )

            if config.DEBUG:
                print(f"[DEBUG] stop_reason={response.stop_reason}", file=sys.stderr)
                for block in response.content:
                    if hasattr(block, "text"):
                        print(f"[DEBUG] text: {block.text[:300]}", file=sys.stderr)
                    elif block.type == "tool_use":
                        print(f"[DEBUG] tool_use: {block.name}({json.dumps(block.input)[:200]})", file=sys.stderr)

            # 如果 LLM 认为任务完成，提取最终文本返回
            if response.stop_reason == "end_turn":
                final_text = self._extract_text(response)
                logger.info("Task completed in %d iterations.", iteration)
                return final_text

            # 如果 LLM 需要调用工具
            if response.stop_reason == "tool_use":
                # 将 assistant 的回复加入消息历史
                messages.append({"role": "assistant", "content": response.content})

                # 收集所有 tool_use block 并逐一执行
                tool_results: list[dict[str, Any]] = []
                for block in response.content:
                    if block.type == "tool_use":
                        tool_name = block.name
                        tool_input = block.input
                        tool_use_id = block.id

                        logger.info("Calling tool: %s", tool_name)

                        try:
                            result_text = await self._mcp.call_tool(tool_name, tool_input)
                        except Exception as e:
                            result_text = f"[Tool Error] {type(e).__name__}: {e}"
                            logger.warning("Tool %s failed: %s", tool_name, result_text)

                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": tool_use_id,
                            "content": result_text,
                        })

                # 将工具结果加入消息历史
                messages.append({"role": "user", "content": tool_results})
            else:
                # 未知的 stop_reason，提取文本返回
                logger.warning("Unexpected stop_reason: %s", response.stop_reason)
                return self._extract_text(response)

        # 达到最大循环次数
        logger.warning("Max iterations (%d) reached.", config.MAX_ITERATIONS)
        return (
            f"[Alphonso] 达到最大操作轮数 ({config.MAX_ITERATIONS})，以下是目前收集到的信息：\n\n"
            + self._extract_text(response)
        )

    # ------------------------------------------------------------------
    # 辅助
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_text(response: Any) -> str:
        """从 LLM 响应中提取所有文本块。"""
        parts: list[str] = []
        for block in response.content:
            if hasattr(block, "text"):
                parts.append(block.text)
        return "\n".join(parts) if parts else "[No text in response]"
