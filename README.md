# livesync-sync-docker 🐘

> 一行命令跑起 Obsidian LiveSync 头号同步。自动配置，长期运行。

Docker 镜像构建仓库，自动从 [vrtmrz/obsidian-livesync](https://github.com/vrtmrz/obsidian-livesync/tree/main/src/apps/cli) 构建 **Self-hosted LiveSync CLI**，推送到 GitHub Container Registry。

**亮点：** 设置环境变量即可自动生成配置，第一次跑起来就不用管了。

## 快速开始

### 1. 准备 CouchDB

确保有一个可用的 CouchDB 实例（本地或远程）。

### 2. 启动同步

```bash
# 拉取镜像
docker pull ghcr.io/starskyzheng/livesync-sync-docker:latest

# 第一次运行：自动配置 + 持续同步
docker run -d --name livesync-sync --restart unless-stopped \
  -v /path/to/vault:/data \
  -e COUCHDB_URL=http://your-couchdb:5984 \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=your-password \
  ghcr.io/starskyzheng/livesync-sync-docker
```

就是这么简单。**没有手动配置步骤。** 容器会自动：
1. 检测到 `.livesync/settings.json` 不存在
2. 从环境变量生成配置文件
3. 启动 `daemon` 持续双向同步

### 3. 查看日志

```bash
docker logs -f livesync-sync
```

## Docker Compose

```yaml
services:
  livesync-sync:
    image: ghcr.io/starskyzheng/livesync-sync-docker:latest
    container_name: livesync-sync
    restart: unless-stopped
    volumes:
      - ./vault:/data
    environment:
      COUCHDB_URL: http://192.168.1.100:5984
      COUCHDB_USER: admin
      COUCHDB_PASSWORD: your-password
      COUCHDB_DBNAME: obsidian-livesync
```

```bash
docker compose up -d
```

### 加解密

```yaml
environment:
  ENCRYPT: "true"
  ENCRYPT_PASSPHRASE: your-passphrase
```

### 从 Obsidian 导出 URI 配置

```yaml
environment:
  SETUP_URI: "obsidian://setuplivesync?settings=..."
```

`SETUP_URI` 优先级高于 `COUCHDB_*` 变量。适合直接复制 Obsidian 插件里的配置。

## 环境变量参考

| 变量 | 必需 | 默认值 | 说明 |
|------|------|--------|------|
| `COUCHDB_URL` | ✅ 首次 | — | CouchDB 服务地址 |
| `COUCHDB_USER` | 可选 | `""` | CouchDB 用户名 |
| `COUCHDB_PASSWORD` | 可选 | `""` | CouchDB 密码 |
| `COUCHDB_DBNAME` | 可选 | `obsidian-livesync` | 数据库名 |
| `SETUP_URI` | 可选 | — | Obsidian 导出 URI（优先级最高） |
| `ENCRYPT` | 可选 | `false` | 是否加密 |
| `ENCRYPT_PASSPHRASE` | 可选 | `""` | 加密密码（ENCRYPT=true 时需要） |
| `LIVESYNC_DB_PATH` | 可选 | `/data` | 数据库/配置文件目录 |
| `LIVESYNC_ENABLE` | 可选 | `true` | 是否启用 LiveSync |
| `SYNC_ON_SAVE` | 可选 | `true` | 保存时同步 |
| `SYNC_ON_START` | 可选 | `true` | 启动时同步 |

> 已有 `.livesync/settings.json` 后，环境变量被忽略，自动加载现有配置继续同步。

## 手动命令

如果不想用自动配置，仍然可以手动运行所有 CLI 命令：

```bash
# 单次同步
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker sync

# 初始化设置文件
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker init-settings

# 列出文件
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker ls

# 指定间隔轮询（替代 _changes 推送）
docker run --rm -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker daemon --interval 60
```

**未指定命令时默认运行 `daemon`**（持续双向同步）。

## 文件结构

```
livesync-sync-docker/
├── Dockerfile                       # 多阶段构建（source → builder → runtime-deps → runtime）
├── docker-entrypoint.sh             # 智能入口：自动配置 + 默认 daemon
├── init-settings.js                 # 从环境变量生成 settings.json
├── .github/workflows/
│   └── docker-build.yml             # CI：构建 + 推送 ghcr.io
├── docker-compose.yml               # 一键部署
├── .env.example                     # 环境变量说明
└── README.md                        # 本文档
```

## 构建上游版本

默认从 `main` 分支构建。要指定版本：

### GitHub Actions（手动触发）

在 Actions 页面选择 **workflow_dispatch**，填入 `upstream_ref`（如 `0.25.70`）。

### 本地构建

```bash
docker build --build-arg UPSTREAM_REF=0.25.70 -t livesync-sync .
```

## 镜像标签

| 标签 | 说明 |
|------|------|
| `latest` | main 分支最新构建 |
| `sha-<hash>` | 每次构建的短 SHA |
| `v*.*.*` | 手动打 tag 触发 |

## P2P 同步

```bash
# Linux 主机网络模式
docker run --rm --network host -v /path/to/vault:/data ghcr.io/starskyzheng/livesync-sync-docker p2p-host
```

详见[官方文档](https://github.com/vrtmrz/obsidian-livesync/tree/main/src/apps/cli#p2p-webrtc-and-docker-networking)。

## 许可证

Apache License 2.0 — 与上游 [vrtmrz/obsidian-livesync](https://github.com/vrtmrz/obsidian-livesync) 一致。
