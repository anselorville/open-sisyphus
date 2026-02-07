"""Alphonso — Web 信息检索 Agent。

Alphonso 是一个独立的子 Agent，通过 Playwright MCP Server 操控
headless Chrome 浏览器，执行 Web 搜索和信息提取任务。

架构：
    调用方 ──(需求)──► AlphonsoAgent ──(MCP tool call)──► Playwright MCP Server
           ◄──(精炼结果)──              ◄──(tool result)──  (headless Chrome)

快速使用：
    from brain.agents.alphonso.agent import AlphonsoAgent

    agent = AlphonsoAgent()
    await agent.start()
    result = await agent.run("查找 Python 3.13 新特性")
    await agent.stop()
"""

from .agent import AlphonsoAgent

__all__ = ["AlphonsoAgent"]
