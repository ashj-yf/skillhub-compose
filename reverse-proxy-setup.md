# SkillHub 反向代理配置方案

> 基于当前项目部署架构  
> 文档版本：1.0  
> 更新日期：2026-04-22

---

## 一、当前部署架构分析

### 1.1 项目结构

```
/Users/yf/Desktop/skillhub/
├── compose/
│   ├── skillhub/          # 主应用（Server + Web + Scanner）
│   │   └── compose.yml
│   ├── postgres/          # PostgreSQL 数据库
│   │   └── compose.yml
│   ├── redis/             # Redis 缓存
│   │   └── compose.yml
│   ├── minio/             # MinIO 对象存储（可选）
│   │   └── compose.yml
│   └── rustfs/            # RustFS 存储（可选）
│       └── compose.yml
```

### 1.2 服务端口映射

| 服务 | 容器端口 | 主机端口 | 说明 |
|------|---------|---------|------|
| **skillhub-web** | 80 | `${WEB_PORT}` | 前端 Nginx |
| **skillhub-server** | 8080 | `${API_PORT}` | 后端 Spring Boot |
| **skill-scanner** | 8000 | `${SCANNER_PORT}` | 安全扫描器 |
| **postgres** | 5432 | 5432 | PostgreSQL |
| **redis** | 6379 | 6379 | Redis |
| **minio** | 9000/9001 | 9000/9001 | MinIO 控制台 |

### 1.3 环境变量（.env）

当前 `compose/skillhub/.env` 需要配置的关键变量：

```bash
# 端口配置
WEB_PORT=80
API_PORT=8080
SCANNER_PORT=8000

# 域名配置
SKILLHUB_PUBLIC_BASE_URL=https://skillhub.your-company.com

# API 上游地址
SKILLHUB_API_UPSTREAM=http://server:8080

# 数据库配置
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=skillhub
POSTGRES_USER=skillhub
POSTGRES_PASSWORD=skillhub_demo

# Redis 配置
REDIS_HOST=redis
REDIS_PORT=6379

# MinIO/S3 配置
SKILLHUB_STORAGE_S3_ENDPOINT=http://minio:9000
SKILLHUB_STORAGE_S3_PUBLIC_ENDPOINT=https://minio.your-company.com
SKILLHUB_STORAGE_S3_BUCKET=skillhub
SKILLHUB_STORAGE_S3_ACCESS_KEY=minioadmin
SKILLHUB_STORAGE_S3_SECRET_KEY=minioadmin
SKILLHUB_STORAGE_S3_REGION=us-east-1
SKILLHUB_STORAGE_S3_FORCE_PATH_STYLE=true
SKILLHUB_STORAGE_S3_AUTO_CREATE_BUCKET=true

# 扫描器配置
SKILLHUB_SECURITY_SCANNER_URL=http://skill-scanner:8000

# 管理员账号
BOOTSTRAP_ADMIN_USER_ID=admin
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=ChangeMe!2026
BOOTSTRAP_ADMIN_DISPLAY_NAME=管理员
BOOTSTRAP_ADMIN_EMAIL=admin@your-company.com
```

---

## 二、反向代理方案

### 方案一：单域名统一代理（推荐）

**架构**：所有服务通过一个域名访问，路径区分

```
skillhub.your-company.com/
├── /              → Web 容器
├── /api/**        → Server 容器
├── /actuator/**   → Server 容器
└── /minio/**      → MinIO 容器（可选）
```

### 方案二：多域名分别代理

**架构**：每个服务独立域名

```
skillhub.your-company.com      → Web 容器
api-skillhub.your-company.com  → Server 容器
minio.your-company.com         → MinIO 容器
```

---

## 三、方案一配置（单域名统一代理）

### 3.1 DNS 配置

```
类型：A
主机记录：skillhub
记录值：你的服务器公网 IP
```

### 3.2 安装 Nginx

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install nginx -y

# 启动
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 3.3 获取 SSL 证书

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 获取证书
sudo certbot certonly --standalone -d skillhub.your-company.com
```

### 3.4 创建 Nginx 配置

```bash
sudo nano /etc/nginx/sites-available/skillhub
```

```nginx
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name skillhub.your-company.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS 主服务器
server {
    listen 443 ssl http2;
    server_name skillhub.your-company.com;

    # SSL 证书
    ssl_certificate /etc/letsencrypt/live/skillhub.your-company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/skillhub.your-company.com/privkey.pem;

    # SSL 优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_session_cache shared:SSL:10m;

    # 日志
    access_log /var/log/nginx/skillhub-access.log;
    error_log /var/log/nginx/skillhub-error.log;

    # 上传文件大小限制（技能包上传）
    client_max_body_size 20M;

    # ========== 后端 API 代理（优先级高）==========
    location /api/ {
        proxy_pass http://localhost:8080;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    # Actuator 健康检查
    location /actuator/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }

    # MinIO 控制台（可选）
    location /minio/ {
        proxy_pass http://localhost:9001/;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # WebSocket 支持（MinIO 控制台需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # MinIO API（可选）
    location /minio-api/ {
        rewrite ^/minio-api/(.*) /$1 break;
        proxy_pass http://localhost:9000;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # 大文件上传
        client_max_body_size 1G;
        proxy_request_buffering off;
    }

    # ========== 前端 Web（默认）==========
    location / {
        proxy_pass http://localhost:80;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

### 3.5 启用配置

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/skillhub /etc/nginx/sites-enabled/

# 删除默认配置
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
```

### 3.6 修改 .env 文件

编辑 `compose/skillhub/.env`：

```bash
# 端口配置（绑定到本地，通过外部 Nginx 暴露）
WEB_PORT=127.0.0.1:80
API_PORT=127.0.0.1:8080
SCANNER_PORT=127.0.0.1:8000

# 域名配置
SKILLHUB_PUBLIC_BASE_URL=https://skillhub.your-company.com

# API 上游地址（web 容器内部使用）
SKILLHUB_API_UPSTREAM=http://server:8080

# MinIO 配置
SKILLHUB_STORAGE_S3_ENDPOINT=http://minio:9000
SKILLHUB_STORAGE_S3_PUBLIC_ENDPOINT=https://skillhub.your-company.com/minio-api
```

### 3.7 启动服务

```bash
# 进入项目目录
cd /Users/yf/Desktop/skillhub/compose

# 启动所有服务
docker compose -f postgres/compose.yml up -d
docker compose -f redis/compose.yml up -d
docker compose -f minio/compose.yml up -d
docker compose -f skillhub/compose.yml up -d

# 或使用 Docker Compose 插件
docker compose -f postgres/compose.yml -f redis/compose.yml -f minio/compose.yml -f skillhub/compose.yml up -d
```

---

## 四、方案二配置（多域名分别代理）

### 4.1 DNS 配置

```
类型：A
主机记录：skillhub         → 服务器 IP
主机记录：api-skillhub     → 服务器 IP
主机记录：minio            → 服务器 IP
```

### 4.2 Nginx 配置

```bash
sudo nano /etc/nginx/sites-available/skillhub-main
```

```nginx
# ========== 主应用（Web 前端）==========
server {
    listen 80;
    server_name skillhub.your-company.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name skillhub.your-company.com;

    ssl_certificate /etc/letsencrypt/live/skillhub.your-company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/skillhub.your-company.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/skillhub-access.log;
    error_log /var/log/nginx/skillhub-error.log;

    location / {
        proxy_pass http://localhost:80;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

```bash
sudo nano /etc/nginx/sites-available/skillhub-api
```

```nginx
# ========== API 服务 ==========
server {
    listen 80;
    server_name api-skillhub.your-company.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api-skillhub.your-company.com;

    ssl_certificate /etc/letsencrypt/live/api-skillhub.your-company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api-skillhub.your-company.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/skillhub-api-access.log;
    error_log /var/log/nginx/skillhub-api-error.log;

    location / {
        proxy_pass http://localhost:8080;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    location /actuator/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

```bash
sudo nano /etc/nginx/sites-available/minio
```

```nginx
# ========== MinIO 服务 ==========
server {
    listen 80;
    server_name minio.your-company.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name minio.your-company.com;

    ssl_certificate /etc/letsencrypt/live/minio.your-company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/minio.your-company.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/minio-access.log;
    error_log /var/log/nginx/minio-error.log;

    # 控制台
    location / {
        proxy_pass http://localhost:9001;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # API 端点
    location /minio-api/ {
        rewrite ^/minio-api/(.*) /$1 break;
        proxy_pass http://localhost:9000;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        client_max_body_size 1G;
        proxy_request_buffering off;
    }
}
```

### 4.3 启用配置

```bash
# 启用所有站点
sudo ln -s /etc/nginx/sites-available/skillhub-main /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/skillhub-api /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/minio /etc/nginx/sites-enabled/

# 删除默认配置
sudo rm -f /etc/nginx/sites-enabled/default

# 测试并重载
sudo nginx -t && sudo systemctl reload nginx
```

### 4.4 获取所有证书

```bash
sudo certbot certonly --standalone -d skillhub.your-company.com
sudo certbot certonly --standalone -d api-skillhub.your-company.com
sudo certbot certonly --standalone -d minio.your-company.com
```

### 4.5 修改 .env 文件

编辑 `compose/skillhub/.env`：

```bash
# 端口配置（绑定到本地）
WEB_PORT=127.0.0.1:80
API_PORT=127.0.0.1:8080
SCANNER_PORT=127.0.0.1:8000

# 域名配置
SKILLHUB_PUBLIC_BASE_URL=https://skillhub.your-company.com

# API 上游地址
SKILLHUB_API_UPSTREAM=http://server:8080

# MinIO 公共地址（使用独立域名）
SKILLHUB_STORAGE_S3_PUBLIC_ENDPOINT=https://minio.your-company.com
```

---

## 五、验证配置

### 5.1 检查服务状态

```bash
# 检查所有容器
docker compose -f /Users/yf/Desktop/skillhub/compose/postgres/compose.yml ps
docker compose -f /Users/yf/Desktop/skillhub/compose/redis/compose.yml ps
docker compose -f /Users/yf/Desktop/skillhub/compose/minio/compose.yml ps
docker compose -f /Users/yf/Desktop/skillhub/compose/skillhub/compose.yml ps

# 检查 Nginx
sudo systemctl status nginx

# 检查端口
sudo netstat -tlnp | grep -E ':80|:443|:80|:8080|:9000|:9001'
```

### 5.2 测试访问

```bash
# 测试主应用
curl -I https://skillhub.your-company.com/

# 测试 API
curl -I https://skillhub.your-company.com/api/actuator/health

# 测试 MinIO 控制台（方案一）
curl -I https://skillhub.your-company.com/minio/

# 测试独立域名 API（方案二）
curl -I https://api-skillhub.your-company.com/actuator/health

# 测试独立域名 MinIO（方案二）
curl -I https://minio.your-company.com/
```

### 5.3 查看日志

```bash
# Nginx 日志
sudo tail -f /var/log/nginx/skillhub-access.log
sudo tail -f /var/log/nginx/skillhub-error.log

# Docker 日志
docker compose -f /Users/yf/Desktop/skillhub/compose/skillhub/compose.yml logs -f web
docker compose -f /Users/yf/Desktop/skillhub/compose/skillhub/compose.yml logs -f server
```

---

## 六、架构对比

| 特性 | 方案一（单域名） | 方案二（多域名） |
|------|-----------------|-----------------|
| **证书管理** | 1 个证书 | 3 个证书 |
| **Nginx 配置** | 1 个文件 | 3 个文件 |
| **跨域问题** | 无 | 需配置 CORS |
| **Cookie 共享** | 自动共享 | 需特殊配置 |
| **灵活性** | 较低 | 高 |
| **维护成本** | 低 | 中 |
| **推荐场景** | 内部系统、个人项目 | 生产环境、多团队协作 |

---

## 七、自动化脚本

### 7.1 一键部署脚本

创建 `deploy.sh`：

```bash
#!/bin/bash

set -e

DOMAIN=${1:-skillhub.your-company.com}
EMAIL=${2:-admin@your-company.com}

echo "=== SkillHub 一键部署 ==="
echo "域名：$DOMAIN"
echo "邮箱：$EMAIL"

# 1. 安装 Nginx
echo "[1/6] 安装 Nginx..."
sudo apt update
sudo apt install nginx -y

# 2. 安装 Certbot
echo "[2/6] 安装 Certbot..."
sudo apt install certbot python3-certbot-nginx -y

# 3. 获取证书
echo "[3/6] 获取 SSL 证书..."
sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

# 4. 创建 Nginx 配置
echo "[4/6] 创建 Nginx 配置..."
sudo tee /etc/nginx/sites-available/skillhub > /dev/null << 'NGINX_EOF'
server {
    listen 80;
    server_name skillhub.your-company.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name skillhub.your-company.com;

    ssl_certificate /etc/letsencrypt/live/skillhub.your-company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/skillhub.your-company.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    access_log /var/log/nginx/skillhub-access.log;
    error_log /var/log/nginx/skillhub-error.log;

    client_max_body_size 20M;

    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    location /actuator/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX_EOF

# 替换域名占位符
sudo sed -i "s/skillhub.your-company.com/$DOMAIN/g" /etc/nginx/sites-available/skillhub

# 5. 启用配置
echo "[5/6] 启用 Nginx 配置..."
sudo ln -s /etc/nginx/sites-available/skillhub /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

# 6. 提示
echo "[6/6] 部署完成！"
echo ""
echo "下一步："
echo "1. 编辑 compose/skillhub/.env 文件，配置 SKILLHUB_PUBLIC_BASE_URL=$DOMAIN"
echo "2. 启动服务：docker compose -f compose/skillhub/compose.yml up -d"
echo "3. 访问：https://$DOMAIN"
```

使用：

```bash
chmod +x deploy.sh
./deploy.sh skillhub.your-company.com admin@your-company.com
```

### 7.2 健康检查脚本

创建 `health-check.sh`：

```bash
#!/bin/bash

DOMAIN=${1:-skillhub.your-company.com}

echo "=== SkillHub 健康检查 ==="
echo "域名：$DOMAIN"
echo ""

# 检查前端
echo "检查前端..."
if curl -sf https://$DOMAIN/ > /dev/null; then
    echo "✅ 前端正常"
else
    echo "❌ 前端异常"
fi

# 检查 API
echo "检查 API..."
if curl -sf https://$DOMAIN/api/actuator/health > /dev/null; then
    echo "✅ API 正常"
else
    echo "❌ API 异常"
fi

# 检查证书
echo "检查 SSL 证书..."
CERT_INFO=$(echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ -n "$CERT_INFO" ]; then
    echo "✅ 证书有效"
    echo "$CERT_INFO"
else
    echo "❌ 证书无效"
fi

# 检查 Docker 容器
echo "检查 Docker 容器..."
docker compose -f /Users/yf/Desktop/skillhub/compose/skillhub/compose.yml ps
```

---

## 八、故障排查

### 8.1 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 502 Bad Gateway | 容器未启动 | `docker compose ps` 检查状态 |
| 504 Gateway Timeout | 后端响应慢 | 增加 proxy_read_timeout |
| 413 Request Entity Too Large | 文件太大 | 增加 client_max_body_size |
| 跨域错误 | CORS 未配置 | 检查 SKILLHUB_PUBLIC_BASE_URL |
| WebSocket 断开 | Upgrade 头缺失 | 检查 proxy_set_header Upgrade |

### 8.2 排查命令

```bash
# 检查 Nginx 配置
sudo nginx -t

# 检查容器日志
docker compose -f compose/skillhub/compose.yml logs server

# 检查网络连接
docker network inspect skillhub_default

# 测试容器间通信
docker exec -it <web-container-id> curl http://server:8080/actuator/health
```

---

## 九、安全建议

### 9.1 防火墙配置

```bash
# 只开放必要端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### 9.2 限制数据库访问

编辑 `compose/postgres/compose.yml`：

```yaml
ports:
  - "127.0.0.1:5432:5432"  # 只允许本地访问
```

### 9.3 使用强密码

```bash
# 生成强密码
openssl rand -base64 32
```

---

## 十、备份策略

### 10.1 数据库备份

```bash
#!/bin/bash
# backup-db.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/Users/yf/Desktop/skillhub/backups

mkdir -p $BACKUP_DIR

docker exec -t skillhub-postgres pg_dump -U skillhub skillhub > $BACKUP_DIR/db_$DATE.sql

# 保留最近 7 天的备份
find $BACKUP_DIR -name "db_*.sql" -mtime +7 -delete
```

### 10.2 配置文件备份

```bash
# 备份 .env 文件
cp compose/skillhub/.env /Users/yf/Desktop/skillhub/backups/env_$(date +%Y%m%d).bak

# 备份 Nginx 配置
sudo cp /etc/nginx/sites-available/skillhub /Users/yf/Desktop/skillhub/backups/nginx_$(date +%Y%m%d).bak
```

---

**文档结束**
