# SkillHub Docker Compose

内网部署方案，各服务独立运行，通过宿主机 IP + 端口通信，Nginx 统一反向代理。

## 目录结构

```
compose/
├── postgres/
│   ├── compose.yml
│   └── data/          # 数据库文件
├── redis/
│   ├── compose.yml
│   └── data/          # Redis 数据
├── rustfs/
│   ├── compose.yml
│   └── storage/       # 文件存储
├── skillhub/
│   ├── compose.yml
│   └── storage/       # SkillHub 存储
└── nginx/
    ├── compose.yml
    ├── nginx.conf
    ├── conf.d/
    └── logs/          # 日志目录
```

## 端口分配

| 服务 | 端口 | 说明 |
|------|------|------|
| postgres | 5432 | 数据库 |
| redis | 6379 | 缓存 |
| rustfs | 8000 | 文件存储 |
| skillhub-server | 8081 | API 服务 |
| skillhub-web | 8082 | Web 界面 |
| skill-scanner | 8083 | 安全扫描 |
| nginx | 80 | 反向代理 |

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

# 3. 文件存储
cd compose/rustfs && docker compose up -d

# 4. SkillHub 应用
cd compose/skillhub && docker compose up -d

# 5. Nginx 反向代理
cd compose/nginx && docker compose up -d
```

### 3. 验证服务

```bash
# 检查所有容器
docker ps

# 测试端口连通性
nc -zv <HOST_IP> 5432
nc -zv <HOST_IP> 6379
nc -zv <HOST_IP> 8000
nc -zv <HOST_IP> 8081
nc -zv <HOST_IP> 8082
nc -zv <HOST_IP> 8083
```

## 访问方式

### 直接访问
- Web: `http://<HOST_IP>:8082`
- API: `http://<HOST_IP>:8081`
- Scanner: `http://<HOST_IP>:8083`
- RustFS: `http://<HOST_IP>:8000`

### 通过 Nginx 访问
- Web: `http://<HOST_IP>/`
- API: `http://<HOST_IP>/api/`
- Files: `http://<HOST_IP>/files/`
- Scanner: `http://<HOST_IP>/scanner/`

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

## 防火墙配置

如果启用了防火墙，建议只开放 Nginx 端口：

```bash
# firewalld
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload
```

## 数据持久化

| 目录 | 服务 | 说明 |
|------|------|------|
| `compose/postgres/data` | postgres | 数据库文件 |
| `compose/redis/data` | redis | Redis 数据 |
| `compose/rustfs/storage` | rustfs | 文件存储 |
| `compose/skillhub/storage` | server | SkillHub 存储 |
| `compose/nginx/logs` | nginx | 访问日志 |

## 配置说明

所有配置已硬编码在 compose.yml 文件中，无需 .env 文件。

**默认配置：**
- PostgreSQL: 用户 `skillhub`, 密码 `skillhub_demo`
- Redis: 无密码
- 管理员：用户名 `admin`, 密码 `ChangeMe!2026`
