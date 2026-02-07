# PyTorch GPU (CUDA) 安装说明

本文档针对容器内环境：
- **显卡**：NVIDIA GTX 2080 Ti（魔改 22GB 显存）
- **主机驱动**：NVIDIA-SMI 560.94 / Driver 560.94 / CUDA 12.6
- **容器**：Ubuntu 22.04 + Python 3.13，通过 `nvidia-container-toolkit` 使用 GPU

---

## 前置条件

| 组件 | 要求 |
|------|------|
| 主机 NVIDIA 驱动 | >= 560.x（你当前 560.94，已满足） |
| nvidia-container-toolkit | 主机已安装（`nvidia-ctk --version`） |
| Docker Compose GPU 配置 | `.system/docker-compose.yml` 中已声明 `deploy.resources.reservations.devices` |
| Python | 3.10+（容器内为 3.13） |

进入容器后先验证 GPU 可见：

```bash
nvidia-smi
```

应显示 GTX 2080 Ti（22GB）及 CUDA 12.6。如果该命令不存在或报错，说明
nvidia-container-toolkit 未正确安装在主机上或 compose 配置有误。

---

## 核心概念：CUDA 版本匹配

PyTorch 的 GPU 版本与 **CUDA 运行时版本**绑定，而非驱动版本。关键规则：

1. **主机驱动版本**决定能支持的最高 CUDA 运行时版本（560.94 支持 CUDA <= 12.6）。
2. PyTorch 发行包按 CUDA 版本分别编译（cu118 / cu121 / cu124 / cu126 等）。
3. **选择 <= 主机 CUDA 版本的 PyTorch CUDA 包**即可，向下兼容。
4. 你的主机 CUDA 12.6 → 可用 cu126、cu124、cu121、cu118 的 PyTorch 包，**推荐 cu126**。

> 魔改 2080 Ti 架构为 Turing (sm_75)，PyTorch 官方包已包含该架构支持。

---

## 安装步骤

### 1. 激活 base 虚拟环境

容器内 `.bashrc` 默认已激活 `/opt/venv`，确认：

```bash
which python
# 应为 /opt/venv/bin/python
```

如需新建独立 venv（推荐）：

```bash
python3.13 -m venv /workspace/.venv-torch
source /workspace/.venv-torch/bin/activate
pip install --upgrade pip
```

### 2. 安装 PyTorch + CUDA 12.6

**推荐命令（最新稳定版 2.9.x + cu126）：**

```bash
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
```

**指定版本（更可控）：**

```bash
pip3 install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
  --index-url https://download.pytorch.org/whl/cu126
```

### 3. 验证安装

```python
import torch

print("PyTorch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("CUDA version:", torch.version.cuda)
print("GPU count:", torch.cuda.device_count())
print("GPU name:", torch.cuda.get_device_name(0))
print("GPU memory:", round(torch.cuda.get_device_properties(0).total_mem / 1024**3, 1), "GB")

# 简单计算测试
x = torch.randn(1000, 1000, device="cuda")
y = x @ x
print("GPU compute OK:", y.shape)
```

预期输出：
```
PyTorch version: 2.9.1+cu126
CUDA available: True
CUDA version: 12.6
GPU count: 1
GPU name: NVIDIA GeForce GTX 2080 Ti
GPU memory: 22.0 GB
GPU compute OK: torch.Size([1000, 1000])
```

---

## CUDA 版本对照表（速查）

| PyTorch 版本 | CUDA 12.6 (cu126) | CUDA 12.4 (cu124) | CUDA 12.1 (cu121) |
|--------------|--------------------|--------------------|---------------------|
| 2.9.1        | `--index-url .../cu126` | `--index-url .../cu124` | `--index-url .../cu121` |
| 2.9.0        | `--index-url .../cu126` | `--index-url .../cu124` | `--index-url .../cu121` |
| 2.8.0        | `--index-url .../cu126` | `--index-url .../cu124` | `--index-url .../cu121` |
| 2.6.0        | N/A                | `--index-url .../cu124` | `--index-url .../cu121` |
| 2.5.x        | N/A                | `--index-url .../cu124` | `--index-url .../cu121` |

> cu126 从 PyTorch 2.7 开始可用。若需更老版本，选 cu124 或 cu121。

---

## 常见问题

### Q: `torch.cuda.is_available()` 返回 False

排查顺序：

1. **容器内 `nvidia-smi` 是否正常？** 不正常 → 主机 nvidia-container-toolkit 问题。
2. **是否安装了 CPU 版 torch？** 执行 `pip show torch | grep Version`，若不含 `+cu` 后缀则是 CPU 版，需卸载重装：
   ```bash
   pip uninstall torch torchvision torchaudio -y
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
   ```
3. **CUDA 版本太新？** 用 `nvidia-smi` 确认 CUDA 版本，选对应 `--index-url`。

### Q: 魔改 2080 Ti（22GB）是否有兼容问题？

- PyTorch 官方对 Turing 架构 (sm_75) 有完整支持。
- 魔改的显存修改在驱动层面透明，不影响 CUDA 运算。
- 实测 22GB 显存在 `torch.cuda.get_device_properties(0).total_mem` 中正确报告。

### Q: 是否需要在容器里安装 CUDA Toolkit？

**不需要**。PyTorch pip 包自带所需的 CUDA 运行时库（`libcudart`、`libcublas` 等）。
主机只需安装 NVIDIA 驱动 + nvidia-container-toolkit 即可。

### Q: 下载 torch 很慢？

PyTorch 包来自 `download.pytorch.org`（非 PyPI），不走清华源。可选：
- 配置代理：`pip install --proxy http://... ...`
- 先下载 `.whl` 再 `pip install xxx.whl`
- 使用国内 PyTorch 镜像（如有）

---

## 一键脚本

保存为 `/workspace/tools/scripts/install-torch-gpu.sh`，进入容器后执行：

```bash
#!/usr/bin/env bash
set -e

echo "=== 检查 GPU ==="
nvidia-smi

echo ""
echo "=== 安装 PyTorch + CUDA 12.6 ==="
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

echo ""
echo "=== 验证 ==="
python3 -c "
import torch
assert torch.cuda.is_available(), 'CUDA not available!'
print(f'PyTorch {torch.__version__}')
print(f'CUDA {torch.version.cuda}')
print(f'GPU: {torch.cuda.get_device_name(0)}')
mem_gb = torch.cuda.get_device_properties(0).total_mem / 1024**3
print(f'VRAM: {mem_gb:.1f} GB')
x = torch.randn(256, 256, device='cuda')
print('Compute test OK')
"

echo ""
echo "=== 完成 ==="
```
