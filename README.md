# SkillHub Docker Compose

SkillHub 平台的 Docker Compose 部署配置，每个服务独立，通过 `.env` 文件加载配置，数据卷挂载到本地目录。

## 目录结构

```
skillhub/
└── compose/
    ├── postgres/
    │   ├── compose.yml
    │   ├── .env
    │   └── data/              # PostgreSQL 数据目录
    ├── redis/
    │   ├── compose.yml
    │   ├── .env
    │   └── data/              # Redis 数据目录
    └── skillhub/
        ├── compose.yml
        ├── .env
        └── storage/           # 文件存储目录
```

## 启动方式

### 1. 启动 PostgreSQL

```bash
cd compose/postgres
docker compose up -d
```

### 2. 启动 Redis

```bash
cd compose/redis
docker compose up -d
```

### 3. 启动 SkillHub 应用

```bash
cd compose/skillhub
docker compose up -d
```

## 配置说明

### postgres/.env

| 变量 | 说明 |
|------|------|
| `POSTGRES_IMAGE` | PostgreSQL 镜像 |
| `POSTGRES_BIND_ADDRESS` | 绑定地址 |
| `POSTGRES_PORT` | 端口 |
| `POSTGRES_DB` | 数据库名 |
| `POSTGRES_USER` | 用户名 |
| `POSTGRES_PASSWORD` | 密码 |

### redis/.env

| 变量 | 说明 |
|------|------|
| `REDIS_IMAGE` | Redis 镜像 |
| `REDIS_BIND_ADDRESS` | 绑定地址 |
| `REDIS_PORT` | 端口 |

### skillhub/.env

| 变量 | 说明 |
|------|------|
| `SKILLHUB_VERSION` | 镜像版本 |
| `SKILLHUB_SERVER_IMAGE` | Server 镜像 |
| `SKILLHUB_WEB_IMAGE` | Web 镜像 |
| `SKILLHUB_SCANNER_IMAGE` | Scanner 镜像 |
| `API_PORT` | Server 端口 |
| `WEB_PORT` | Web 端口 |
| `SCANNER_PORT` | Scanner 端口 |
| `SKILLHUB_PUBLIC_BASE_URL` | 公共访问 URL |
| `POSTGRES_HOST` | PostgreSQL 主机 |
| `POSTGRES_PORT` | PostgreSQL 端口 |
| `POSTGRES_DB` | 数据库名 |
| `POSTGRES_USER` | 数据库用户 |
| `POSTGRES_PASSWORD` | 数据库密码 |
| `REDIS_HOST` | Redis 主机 |
| `REDIS_PORT` | Redis 端口 |

## 常用命令

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 停止服务
docker compose down

# 停止服务并删除容器 (保留本地数据)
docker compose rm -f
```

## 数据持久化

| 目录 | 服务 | 说明 |
|------|------|------|
| `compose/postgres/data` | postgres | PostgreSQL 数据 |
| `compose/redis/data` | redis | Redis 数据 |
| `compose/skillhub/storage` | server | 文件存储 |

数据直接挂载到 compose 同级目录，便于备份和管理。
