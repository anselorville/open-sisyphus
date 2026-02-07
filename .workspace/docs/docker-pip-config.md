# 容器内 Pip 源配置说明

容器默认 pip 源已设为**清华大学镜像**（`https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple`），
配置文件为 `.system/.docker/pip.conf`，构建时被复制到容器内 `/etc/pip.conf`。

## 当前默认源

```ini
[global]
index-url = https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
trusted-host = mirrors.tuna.tsinghua.edu.cn
```

## 修改方法

### 方式 A：直接修改 `.system/.docker/pip.conf`

编辑 `.system/.docker/pip.conf` 后重新构建即可。常用国内源：

| 源 | index-url |
|----|-----------|
| 清华 | `https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple` |
| 阿里 | `https://mirrors.aliyun.com/pypi/simple/` |
| 中科大 | `https://pypi.mirrors.ustc.edu.cn/simple/` |
| 华为 | `https://repo.huaweicloud.com/repository/pypi/simple/` |

### 方式 B：构建参数覆盖

不修改文件时，可在构建时传入地址：

```bash
docker build -t openclaw-dev -f .system/Dockerfile \
  --build-arg PIP_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/" \
  .
```

- `PIP_INDEX_URL`：主索引，覆盖 `.system/.docker/pip.conf` 中的设置。
- `PIP_EXTRA_INDEX_URL`：可选，额外索引。

### 方式 C：容器内临时修改

```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
```

## 验证

```bash
pip config list
# 或
python3.13 -m pip config list
```

## 注意：PyTorch 下载不走 pip 源

PyTorch GPU 版使用独立 `--index-url https://download.pytorch.org/whl/cu126`，
不经过清华源。详见 [docs/INSTALL-TORCH-CUDA.md](../../docs/INSTALL-TORCH-CUDA.md)。
