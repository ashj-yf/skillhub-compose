# SkillHub Docker Compose

内网部署方案，各服务独立运行，通过宿主机 IP + 端口通信。

## 目录结构

```
compose/
├── postgres/
│   ├── compose.yml
│   └── data/
├── redis/
│   ├── compose.yml
│   └── data/
├── minio/            # S3 兼容对象存储
│   ├── compose.yml
│   └── data/
└── skillhub/
    ├── compose.yml
    ├── .env
    └── storage/
```

## 端口分配

| 服务 | 端口 | 说明 |
|------|------|------|
| postgres | 5432 | 数据库 |
| redis | 6379 | 缓存 |
| minio | 9000 | S3 API |
| minio | 9001 | MinIO 控制台 |
| skillhub-server | 8081 | API 服务 |
| skillhub-web | 8082 | Web 界面 |
| skill-scanner | 8083 | 安全扫描 |

## 部署步骤

### 1. 修改宿主机 IP

将所有配置中的 `172.16.0.1` 改为你的宿主机内网 IP：

```bash
# 查找宿主机 IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# 批量替换
find compose -type f \( -name "*.yml" -o -name "*.conf" \) -exec sed -i 's/172.16.0.1/你的 IP/g' {} \;
```

### 2. 启动服务

```bash
# 1. 数据库
cd compose/postgres && docker compose up -d

# 2. 缓存
cd compose/redis && docker compose up -d

# 3. 对象存储 (MinIO)
cd compose/minio && docker compose up -d

# 4. SkillHub 应用
cd compose/skillhub && docker compose up -d
```

### 3. 验证服务

```bash
# 检查所有容器
docker ps

# 测试端口连通性
nc -zv <HOST_IP> 5432
nc -zv <HOST_IP> 6379
nc -zv <HOST_IP> 9000
nc -zv <HOST_IP> 8081
```

## 访问方式

### 直接访问服务
- Web: `http://<HOST_IP>:8082`
- API: `http://<HOST_IP>:8081`
- Scanner: `http://<HOST_IP>:8083`
- MinIO 控制台：`http://<HOST_IP>:9001`

## 存储配置

### MinIO S3 存储 (默认)
SkillHub 使用 MinIO 作为对象存储后端。

**MinIO 配置：**
- 端点：`http://<HOST_IP>:9000`
- 用户名：`minioadmin`
- 密码：`minioadmin`
- Bucket：`skillhub` (自动创建)

**访问 MinIO 控制台：**
1. 打开 `http://<HOST_IP>:9001`
2. 登录：`minioadmin` / `minioadmin`
3. 查看 `skillhub` bucket 中的文件

## 常用命令

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 停止服务
docker compose down

# 重启服务
docker compose restart
```

## 数据持久化

| 目录 | 服务 | 说明 |
|------|------|------|
| `compose/postgres/data` | postgres | 数据库文件 |
| `compose/redis/data` | redis | Redis 数据 |
| `compose/minio/data` | minio | S3 对象存储 |
| `compose/skillhub/storage` | server | SkillHub 存储 |

## 默认凭证

| 服务 | 用户名 | 密码 |
|------|--------|------|
| PostgreSQL | skillhub | skillhub_demo |
| MinIO | minioadmin | minioadmin |
| SkillHub 管理员 | admin | ChangeMe!2026 |

## 安全建议

1. **修改默认密码**：
   - MinIO: 修改 `compose/minio/compose.yml` 中的 `MINIO_ROOT_USER` 和 `MINIO_ROOT_PASSWORD`
   - PostgreSQL: 修改 `compose/postgres/compose.yml` 中的 `POSTGRES_PASSWORD`
   - SkillHub: 登录后修改管理员密码

2. **防火墙配置**：
   ```bash
   # 只开放必要端口
   firewall-cmd --permanent --add-port=80/tcp
   firewall-cmd --reload
   ```

3. **使用 HTTPS**：
   - 配置 Nginx SSL 证书
   - 启用 `SESSION_COOKIE_SECURE: "true"`
