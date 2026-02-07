"""Alphonso MCP Client — 连接 Playwright MCP Server，获取浏览器工具列表并执行调用。

通过 stdio 启动 @playwright/mcp 进程，走标准 MCP 协议通信。
"""

from __future__ import annotations

import asyncio
import json
import logging
import sys
from typing import Any

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from . import config

logger = logging.getLogger("alphonso.mcp_client")


class PlaywrightMCPClient:
    """管理与 Playwright MCP Server 的 stdio 连接。"""

    def __init__(self) -> None:
        self._session: ClientSession | None = None
        self._context_manager: Any = None
        self._streams_cm: Any = None
        self._tools: list[dict[str, Any]] = []

    @property
    def tools(self) -> list[dict[str, Any]]:
        """当前可用的 MCP 工具列表（Anthropic tool schema 格式）。"""
        return self._tools

    @property
    def tools_for_anthropic(self) -> list[dict[str, Any]]:
        """转换为 Anthropic API tool 格式。"""
        result = []
        for t in self._tools:
            tool_def: dict[str, Any] = {
                "name": t["name"],
                "description": t.get("description", ""),
                "input_schema": t.get("inputSchema", {"type": "object", "properties": {}}),
            }
            result.append(tool_def)
        return result

    async def connect(self) -> None:
        """启动 Playwright MCP Server 并连接。"""
        if self._session is not None:
            return

        server_params = StdioServerParameters(
            command=config.PLAYWRIGHT_MCP_COMMAND,
            args=config.PLAYWRIGHT_MCP_ARGS,
        )

        # stdio_client 返回 (read_stream, write_stream) 的 async context manager
        self._streams_cm = stdio_client(server_params)
        read_stream, write_stream = await self._streams_cm.__aenter__()

        self._context_manager = ClientSession(read_stream, write_stream)
        self._session = await self._context_manager.__aenter__()

        # 初始化 MCP 会话
        await self._session.initialize()

        # 获取可用工具
        tools_response = await self._session.list_tools()
        self._tools = [
            {
                "name": t.name,
                "description": t.description or "",
                "inputSchema": t.inputSchema if hasattr(t, "inputSchema") else {"type": "object", "properties": {}},
            }
            for t in tools_response.tools
        ]

        logger.info(
            "Connected to Playwright MCP Server. Available tools: %s",
            [t["name"] for t in self._tools],
        )

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> str:
        """调用一个 MCP 工具并返回结果文本。"""
        if self._session is None:
            raise RuntimeError("MCP client not connected. Call connect() first.")

        logger.debug("Calling MCP tool: %s(%s)", name, json.dumps(arguments, ensure_ascii=False)[:200])

        result = await self._session.call_tool(name, arguments)

        # 将结果内容拼成文本
        parts: list[str] = []
        for content in result.content:
            if hasattr(content, "text"):
                parts.append(content.text)
            elif hasattr(content, "data"):
                # 图片等二进制数据，标注类型
                parts.append(f"[{getattr(content, 'mimeType', 'binary')} data, {len(content.data)} chars]")
            else:
                parts.append(str(content))

        text = "\n".join(parts)
        logger.debug("Tool result (%d chars): %s", len(text), text[:300])
        return text

    async def disconnect(self) -> None:
        """断开与 MCP Server 的连接。"""
        if self._context_manager is not None:
            try:
                await self._context_manager.__aexit__(None, None, None)
            except Exception:
                pass
        if self._streams_cm is not None:
            try:
                await self._streams_cm.__aexit__(None, None, None)
            except Exception:
                pass
        self._session = None
        self._context_manager = None
        self._streams_cm = None
        self._tools = []
        logger.info("Disconnected from Playwright MCP Server")
