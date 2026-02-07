#!/usr/bin/env bash
# ============================================================================
# 一键安装 PyTorch + CUDA 12.6
# 使用：bash tools/scripts/install-torch-gpu.sh
# 详细说明：docs/INSTALL-TORCH-CUDA.md
# ============================================================================
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
