# SkillHub 部署说明

## 服务信息

| 服务 | 容器名 | 端口 | 说明 |
|------|--------|------|------|
| server | skillhub-server | 8081 | API 后端服务 |
| web | skillhub-web | 8082 | Web 前端界面 |
| scanner | skillhub-scanner | 8083 | 安全扫描服务 |

## 前置条件

确保以下服务已启动：

1. **PostgreSQL** — 端口 5432
2. **Redis** — 端口 6379
3. **MinIO** — 端口 9000

## 启动服务

```bash
# 1. 配置环境变量
cp .env.example .env
# 修改 .env 中的 HOST_IP 和密码等

# 2. 启动
docker compose up -d
```

## 配置说明

### 必要配置

编辑 `.env` 文件，至少修改以下项：

| 变量 | 说明 |
|------|------|
| `HOST_IP` | 宿主机内网 IP |
| `POSTGRES_PASSWORD` | 数据库密码（需与 PostgreSQL 一致） |
| `BOOTSTRAP_ADMIN_PASSWORD` | 管理员初始密码 |

### 存储配置

默认使用 MinIO S3 存储，相关配置：

| 变量 | 说明 |
|------|------|
| `SKILLHUB_STORAGE_PROVIDER` | 存储类型，默认 `s3` |
| `SKILLHUB_STORAGE_S3_ENDPOINT` | S3 端点地址 |
| `SKILLHUB_STORAGE_S3_ACCESS_KEY` | S3 访问密钥 |
| `SKILLHUB_STORAGE_S3_SECRET_KEY` | S3 密钥 |

### 安全扫描

安全扫描默认启用，可选配置 LLM 增强：

| 变量 | 说明 |
|------|------|
| `SKILLHUB_SECURITY_SCANNER_ENABLED` | 是否启用，默认 `true` |
| `SKILL_SCANNER_LLM_API_KEY` | LLM API Key（可选） |
| `SKILL_SCANNER_LLM_BASE_URL` | LLM API 地址（可选） |
| `SKILL_SCANNER_LLM_MODEL` | LLM 模型名（可选） |

### OAuth2 登录（可选）

支持 GitHub、GitLab、OIDC 三种方式，详见 `.env.example` 中 OAuth2 配置区块。

OIDC 对接 Keycloak 的步骤参见 `compose/keycloak/README.md`。

### SMTP 邮件（可选）

配置后支持密码重置邮件，详见 `.env.example` 中 SMTP 配置区块。

## 访问服务

- Web 界面：`http://<HOST_IP>:8082`
- API：`http://<HOST_IP>:8081`
- Scanner：`http://<HOST_IP>:8083`

## 数据持久化

| 目录 | 说明 |
|------|------|
| `./storage` | SkillHub 本地存储 |

## 常用操作

### 查看服务日志

```bash
# 所有服务
docker compose logs -f

# 仅后端
docker compose logs -f server
```

### 重启单个服务

```bash
docker compose restart server
```

## 安全建议

- 修改 `BOOTSTRAP_ADMIN_PASSWORD`，首次登录后立即更换
- 生产环境启用 HTTPS，设置 `SESSION_COOKIE_SECURE=true`
- 修改 PostgreSQL、MinIO 默认密码，同步更新 `.env`
