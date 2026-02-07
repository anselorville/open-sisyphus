#!/usr/bin/env bash
# ============================================================================
# AI 助手健康检查脚本
# 使用：bash tools/scripts/health-check.sh
# ============================================================================

echo "=========================================="
echo "  AI 助手环境健康检查"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "=========================================="

echo ""
echo "--- 系统 ---"
echo "时区: $(cat /etc/timezone 2>/dev/null || echo 'unknown')"
echo "磁盘: $(df -h /workspace | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
echo "内存: $(free -h | grep Mem | awk '{print $3 "/" $2}')"

echo ""
echo "--- Python ---"
python3.13 --version 2>/dev/null && echo "  venv: $(which python)" || echo "  [FAIL] Python 3.13 not found"

echo ""
echo "--- Node.js ---"
node -v 2>/dev/null || echo "  [FAIL] Node.js not found"
npm -v 2>/dev/null && echo "  npm OK" || echo "  [FAIL] npm not found"

echo ""
echo "--- GPU ---"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,memory.total,memory.used,driver_version --format=csv,noheader 2>/dev/null \
        || echo "  [FAIL] nvidia-smi error"
else
    echo "  [SKIP] nvidia-smi not available"
fi

echo ""
echo "--- Chrome ---"
google-chrome-stable --version 2>/dev/null || echo "  [FAIL] Chrome not found"

echo ""
echo "--- Postgres ---"
if command -v psql &>/dev/null; then
    psql -h localhost -U "${POSTGRES_USER:-dev}" -d "${POSTGRES_DB:-app}" -c "SELECT 1;" &>/dev/null \
        && echo "  Postgres: connected" \
        || echo "  Postgres: connection failed"
else
    echo "  [SKIP] psql not installed (use: apt install postgresql-client)"
fi

echo ""
echo "--- Workspace 统计 ---"
echo "  worklog 条目: $(find /workspace/worklog -name 'session-*.md' 2>/dev/null | wc -l)"
echo "  memory 笔记:  $(find /workspace/memory/notepad -name '*.md' 2>/dev/null | wc -l)"
echo "  inbox 待办:   $(grep -c '^## ' /workspace/inbox/backlog.md 2>/dev/null || echo 0)"

echo ""
echo "=========================================="
