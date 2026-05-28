# livesync-sync-docker

Docker 镜像构建仓库，自动从 [vrtmrz/obsidian-livesync](https://github.com/vrtmrz/obsidian-livesync/tree/main/src/apps/cli) 构建并推送 **Self-hosted LiveSync CLI** 镜像到 GitHub Container Registry。

源码不存储在本仓库 — 每次构建从上游实时拉取。

## 快速开始

### 前置条件

- 已配置好 CouchDB（或任何兼容 LiveSync 的后端）
- 已有 `.livesync/settings.json` 配置文件（可通过 `init-settings` 命令生成）

### 拉取镜像

```bash
docker pull ghcr.io/starskyzheng/livesync-sync-docker:latest
```

### 初始化配置

```bash
# 生成默认 settings.json
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker init-settings
```

然后用 Obsidian 的 Self-hosted LiveSync 插件导出的 URI 配置：

```bash
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker \
  setup "obsidian://setuplivesync?settings=..."
```

或者手动编辑 `vault/.livesync/settings.json`，至少包含：

```json
{
  "couchDB_URI": "http://your-couchdb:5984",
  "couchDB_USER": "admin",
  "couchDB_PASSWORD": "password",
  "couchDB_DBNAME": "obsidian-livesync",
  "isConfigured": true
}
```

### 运行同步

```bash
# 单次同步
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker sync

# 持续守护模式（推荐）
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker daemon
```

## Docker Compose

```bash
# 下载 docker-compose.yml
wget https://raw.githubusercontent.com/starskyzheng/livesync-sync-docker/main/docker-compose.yml

# 创建 vault 目录
mkdir -p vault

# 启动（持续同步）
docker compose up -d

# 查看日志
docker compose logs -f

# 停止
docker compose down
```

## 命令参考

| 命令 | 用途 |
|------|------|
| `sync` | 运行一次同步周期后退出 |
| `daemon` | **（默认）** 持续双向同步（文件监听 + CouchDB _changes 推送） |
| `daemon --interval 60` | 轮询模式（60s/次），替代 _changes 推送 |
| `mirror [vault-path]` | 将数据库内容镜像到本地目录 |
| `ls [prefix]` | 列出数据库中的文件 |
| `init-settings` | 生成默认 settings.json |
| `setup <URI>` | 从 Obsidian 导出 URI 配置 |
| `push <src> <dst>` | 推送本地文件到数据库 |
| `pull <src> <dst>` | 从数据库拉取文件到本地 |
| `info <path>` | 查看文件版本和元数据 |
| `remote-add <name> <connstr>` | 添加远程配置 |

> 所有命令的数据库路径默认使用 `/data`，可通过 `LIVESYNC_DB_PATH` 环境变量覆盖。

## P2P 同步

容器默认使用 Docker bridge 网络，P2P 的 ICE 候选地址为桥接 IP（不可达）。需要 LAN P2P 时：

```bash
# Linux 主机网络模式
docker run --rm --network host -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker p2p-host
```

Internet P2P 和 CouchDB 同步无需特殊网络配置。

详情见[官方文档](https://github.com/vrtmrz/obsidian-livesync/tree/main/src/apps/cli#p2p-webrtc-and-docker-networking)。

## Docker 镜像标签

| 标签 | 说明 |
|------|------|
| `latest` | main 分支最新构建 |
| `sha-<hash>` | 每次构建的短 SHA |
| `v*.*.*` | 手动打 tag 触发（格式同上游版本号） |

## 构建上游版本

默认从 `main` 分支构建。要指定版本：

### 手动触发（GitHub Actions）

在 Actions 页面选择 **workflow_dispatch**，填入 `upstream_ref`（如 `0.25.70`）。

### 本地构建

```bash
docker build --build-arg UPSTREAM_REF=0.25.70 -t livesync-sync .
```

## 许可证

Apache License 2.0 — 与上游 [vrtmrz/obsidian-livesync](https://github.com/vrtmrz/obsidian-livesync) 一致。
