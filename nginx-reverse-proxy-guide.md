# SkillHub 域名反向代理完整配置方案

> 文档版本：1.0  
> 更新日期：2026-04-22  
> 适用版本：SkillHub latest

---

## 一、架构分析

根据官方 `runtime.sh` 脚本和 `compose.release.yml` 分析，系统包含以下服务：

| 服务 | 容器端口 | 默认主机端口 | 说明 |
|------|---------|-------------|------|
| **web** | 80 | 80 | 前端 Nginx（内置 API 代理） |
| **server** | 8080 | 8080 | 后端 Spring Boot API |
| **postgres** | 5432 | 5432 | 数据库（仅本地） |
| **redis** | 6379 | 6379 | 缓存（仅本地） |
| **skill-scanner** | 8000 | - | 安全扫描器（内部） |

### 官方启动命令

```bash
curl -fsSL https://imageless.oss-cn-beijing.aliyuncs.com/runtime.sh | sh -s -- up --aliyun --public-url https://skillhub.your-company.com --version latest
```

### 关键参数说明

| 参数 | 说明 |
|------|------|
| `--public-url` | 对外公开的访问地址，用于生成回调 URL、重定向等 |
| `--aliyun` | 从阿里云镜像源下载资源（国内加速） |
| `--version` | SkillHub 版本，支持 `latest` 或具体版本号如 `1.0.0` |

---

## 二、方案选择

### 方案 A：仅使用 Web 容器的 Nginx（快速部署）

**优点**：
- 配置简单，一条命令启动
- 无需额外安装 Nginx
- 适合测试环境或个人使用

**缺点**：
- SSL 证书管理不便
- 端口暴露较多
- 不适合生产环境

### 方案 B：独立 Nginx 反向代理（生产环境推荐）

**优点**：
- 统一 SSL 终止
- 灵活的路由规则
- 更好的安全性和可维护性
- 支持多域名、多服务

**缺点**：
- 需要额外配置 Nginx

---

## 三、方案 A 配置（快速部署）

### 3.1 DNS 配置

在域名服务商添加 A 记录：

```
类型：A
主机记录：skillhub
记录值：你的服务器公网 IP
示例：skillhub.your-company.com → 1.2.3.4
TTL：10 分钟
```

### 3.2 创建环境文件

```bash
# 运行目录
cd /opt/docker-compose/skillhub

# 创建环境文件
cat > .env.release << 'EOF'
# 版本配置
SKILLHUB_VERSION=latest

# 公共访问地址（重要！）
SKILLHUB_PUBLIC_BASE_URL=https://skillhub.your-company.com

# 前端 API 地址
SKILLHUB_WEB_API_BASE_URL=https://skillhub.your-company.com

# 端口配置
WEB_PORT=443
API_PORT=127.0.0.1:8080

# 数据库配置
POSTGRES_PORT=127.0.0.1:5432
POSTGRES_DB=skillhub
POSTGRES_USER=skillhub
POSTGRES_PASSWORD=你的强密码

# Redis 配置
REDIS_PORT=127.0.0.1:6379

# 管理员账号
BOOTSTRAP_ADMIN_ENABLED=true
BOOTSTRAP_ADMIN_USER_ID=admin
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=你的强密码
BOOTSTRAP_ADMIN_DISPLAY_NAME=管理员
BOOTSTRAP_ADMIN_EMAIL=admin@your-company.com

# 存储配置（本地存储）
SKILLHUB_STORAGE_PROVIDER=local
STORAGE_BASE_PATH=/var/lib/skillhub/storage

# 安全扫描器
SKILLHUB_SECURITY_SCANNER_ENABLED=true
SKILLHUB_SECURITY_SCANNER_URL=http://skill-scanner:8000
EOF
```

### 3.3 运行

```bash
curl -fsSL https://imageless.oss-cn-beijing.aliyuncs.com/runtime.sh | sh -s -- up --aliyun --public-url https://skillhub.your-company.com --version latest
```

---

## 四、方案 B 配置（生产环境，完整 HTTPS）

### 步骤 1：DNS 配置

```
类型：A
主机记录：skillhub
记录值：你的服务器公网 IP
TTL：10 分钟
```

### 步骤 2：安装 Nginx

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx -y

# CentOS/RHEL
sudo yum install nginx -y

# 启动
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 步骤 3：获取 SSL 证书

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 获取证书（ standalone 模式，无需 Nginx 运行）
sudo certbot certonly --standalone -d skillhub.your-company.com

# 证书位置：
# /etc/letsencrypt/live/skillhub.your-company.com/fullchain.pem
# /etc/letsencrypt/live/skillhub.your-company.com/privkey.pem

# 验证证书
sudo certbot certificates
```

### 步骤 4：创建 Nginx 配置文件

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
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

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
        
        # 超时设置
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

### 步骤 5：启用配置

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/skillhub /etc/nginx/sites-enabled/

# 删除默认配置（避免 80 端口冲突）
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
```

### 步骤 6：创建 .env.release 文件

```bash
cat > /opt/docker-compose/skillhub/.env.release << 'EOF'
# 版本配置
SKILLHUB_VERSION=latest

# 公共访问地址（必须与域名一致）
SKILLHUB_PUBLIC_BASE_URL=https://skillhub.your-company.com

# 前端 API 地址（web 容器内部使用）
SKILLHUB_WEB_API_BASE_URL=http://server:8080

# API 上游地址（web 容器内的 Nginx 使用）
SKILLHUB_API_UPSTREAM=http://server:8080

# 端口配置（绑定到本地，通过外部 Nginx 暴露）
WEB_PORT=127.0.0.1:80
API_PORT=127.0.0.1:8080

# 数据库配置（仅本地访问）
POSTGRES_BIND_ADDRESS=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_DB=skillhub
POSTGRES_USER=skillhub
POSTGRES_PASSWORD=你的强密码

# Redis 配置（仅本地访问）
REDIS_BIND_ADDRESS=127.0.0.1
REDIS_PORT=6379

# 管理员账号
BOOTSTRAP_ADMIN_ENABLED=true
BOOTSTRAP_ADMIN_USER_ID=admin
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=你的强密码
BOOTSTRAP_ADMIN_DISPLAY_NAME=管理员
BOOTSTRAP_ADMIN_EMAIL=admin@your-company.com

# 存储配置（本地存储）
SKILLHUB_STORAGE_PROVIDER=local
STORAGE_BASE_PATH=/var/lib/skillhub/storage

# 安全扫描器
SKILLHUB_SECURITY_SCANNER_ENABLED=true
SKILLHUB_SECURITY_SCANNER_URL=http://skill-scanner:8000

# 可选：GitHub OAuth 登录
# OAUTH2_GITHUB_CLIENT_ID=your_client_id
# OAUTH2_GITHUB_CLIENT_SECRET=your_client_secret
EOF
```

### 步骤 7：运行 SkillHub

```bash
curl -fsSL https://imageless.oss-cn-beijing.aliyuncs.com/runtime.sh | sh -s -- up --aliyun --public-url https://skillhub.your-company.com --version latest
```

---

## 五、验证配置

### 5.1 检查服务状态

```bash
# 检查 Docker 容器
docker compose -f /opt/docker-compose/skillhub/compose.release.yml ps

# 检查 Nginx 状态
sudo systemctl status nginx

# 检查端口监听
sudo netstat -tlnp | grep -E ':80|:443|:8080'
```

### 5.2 测试访问

```bash
# 测试前端访问
curl -I https://skillhub.your-company.com/

# 测试后端 API 健康检查
curl -I https://skillhub.your-company.com/api/actuator/health

# 测试 API 接口
curl https://skillhub.your-company.com/api/skills

# 测试 WebSocket（如果有）
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" https://skillhub.your-company.com/
```

### 5.3 查看日志

```bash
# Nginx 日志
sudo tail -f /var/log/nginx/skillhub-access.log
sudo tail -f /var/log/nginx/skillhub-error.log

# Docker 容器日志
docker compose -f /opt/docker-compose/skillhub/compose.release.yml logs -f web
docker compose -f /opt/docker-compose/skillhub/compose.release.yml logs -f server
```

---

## 六、架构示意

```
┌─────────────────────────────────────────────────────────┐
│  用户浏览器                                              │
│  https://skillhub.your-company.com                       │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS (443)
                     ▼
┌─────────────────────────────────────────────────────────┐
│  服务器 Nginx（反向代理）                                │
│  - SSL 终止                                              │
│  - /api/* → localhost:8080                              │
│  - /* → localhost:80                                    │
└───────────────┬──────────────────────┬──────────────────┘
                │                      │
        HTTP (80)              HTTP (8080)
                │                      │
                ▼                      ▼
        ┌──────────────┐      ┌──────────────┐
        │ web 容器      │      │ server 容器   │
        │ (Nginx:80)   │      │ (Spring:8080)│
        │ - 静态文件    │      │ - REST API   │
        │ - API 代理    │      │ - 数据库连接  │
        └──────────────┘      └──────────────┘
                                      │
                                      ▼
                              ┌──────────────┐
                              │ postgres 容器 │
                              │   (5432)     │
                              └──────────────┘
```

---

## 七、自动续期证书

Let's Encrypt 证书有效期 90 天，需要自动续期：

```bash
# 添加定时任务
sudo crontab -e

# 添加以下内容（每月 1 号凌晨 3 点续期并重载 Nginx）
0 3 1 * * certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

### 手动测试续期

```bash
# 测试续期（不实际执行）
sudo certbot renew --dry-run

# 强制续期
sudo certbot renew --force-renewal
```

---

## 八、故障排查

### 8.1 常见问题速查表

| 问题 | 检查命令 | 解决方案 |
|------|---------|---------|
| 前端能访问，API 404 | `curl https://skillhub.your-company.com/api/actuator/health` | 检查 Nginx location /api/ 配置 |
| API 502 Bad Gateway | `docker compose ps` | 检查 server 容器是否启动 |
| SSL 证书错误 | `sudo certbot certificates` | 重新获取证书 |
| 跨域错误 | 浏览器控制台 | 检查 SKILLHUB_PUBLIC_BASE_URL 配置 |
| 上传失败 | Nginx error.log | 增加 client_max_body_size |
| WebSocket 断开 | 浏览器控制台 | 检查 Upgrade 头配置 |

### 8.2 详细排查步骤

```bash
# 1. 检查 DNS 解析
nslookup skillhub.your-company.com
dig skillhub.your-company.com

# 2. 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 3. 检查端口占用
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :8080

# 4. 检查 Docker 网络
docker network ls
docker network inspect skillhub_default

# 5. 测试容器间通信
docker exec -it <web-container> curl http://server:8080/actuator/health

# 6. 检查环境变量
docker exec -it <web-container> env | grep SKILLHUB
docker exec -it <server-container> env | grep SKILLHUB
```

---

## 九、安全加固建议

### 9.1 防火墙配置

```bash
# 只开放必要端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (用于证书续期)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### 9.2 Docker 安全

```bash
# 限制容器资源
# 在 compose.release.yml 中添加：
services:
  server:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### 9.3 数据库安全

```bash
# .env.release 中使用强密码
POSTGRES_PASSWORD=使用强密码生成器生成

# 限制数据库端口只监听本地
POSTGRES_BIND_ADDRESS=127.0.0.1
```

### 9.4 Nginx 安全头

```nginx
# 在 server 块中添加
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' https: data:; connect-src 'self' https:; frame-ancestors 'self';" always;
```

---

## 十、备份与恢复

### 10.1 备份数据

```bash
# 创建备份目录
mkdir -p ~/skillhub-backup

# 备份数据库
docker exec -t skillhub-postgres pg_dump -U skillhub skillhub > ~/skillhub-backup/db-$(date +%Y%m%d).sql

# 备份环境变量
cp /opt/docker-compose/skillhub/.env.release ~/skillhub-backup/

# 备份 SSL 证书
sudo tar -czf ~/skillhub-backup/ssl-$(date +%Y%m%d).tar.gz /etc/letsencrypt/live/skillhub.your-company.com/
```

### 10.2 恢复数据

```bash
# 恢复数据库
cat ~/skillhub-backup/db-20260422.sql | docker exec -i skillhub-postgres psql -U skillhub -d skillhub

# 恢复环境变量
cp ~/skillhub-backup/.env.release /opt/docker-compose/skillhub/

# 恢复 SSL 证书
sudo tar -xzf ~/skillhub-backup/ssl-20260422.tar.gz -C /
```

---

## 十一、性能优化

### 11.1 Nginx 优化

```nginx
# 在 http 块中添加
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    use epoll;
    worker_connections 4096;
    multi_accept on;
}

http {
    # 开启 gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript;
    
    # 缓存优化
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m use_temp_path=off;
}
```

### 11.2 Docker 优化

```yaml
# 在 compose.release.yml 中添加
services:
  server:
    environment:
      - SPRING_JPA_OPEN_IN_VIEW=false
      - SERVER_TOMCAT_THREADS_MAX=200
```

---

## 十二、参考链接

- [SkillHub 官方文档](https://iflytek.github.io/skillhub/)
- [SkillHub GitHub](https://github.com/iflytek/skillhub)
- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

---

## 附录：完整配置文件

### A.1 Nginx 完整配置

文件位置：`/etc/nginx/sites-available/skillhub`

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
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # 日志
    access_log /var/log/nginx/skillhub-access.log;
    error_log /var/log/nginx/skillhub-error.log;

    # 上传文件大小限制
    client_max_body_size 20M;

    # 后端 API 代理
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

    # 前端 Web
    location / {
        proxy_pass http://localhost:80;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
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

### A.2 .env.release 完整模板

文件位置：`/opt/docker-compose/skillhub/.env.release`

```bash
# ==================== 版本配置 ====================
SKILLHUB_VERSION=latest

# ==================== 域名配置 ====================
SKILLHUB_PUBLIC_BASE_URL=https://skillhub.your-company.com
SKILLHUB_WEB_API_BASE_URL=http://server:8080
SKILLHUB_API_UPSTREAM=http://server:8080

# ==================== 端口配置 ====================
WEB_PORT=127.0.0.1:80
API_PORT=127.0.0.1:8080
POSTGRES_BIND_ADDRESS=127.0.0.1
POSTGRES_PORT=5432
REDIS_BIND_ADDRESS=127.0.0.1
REDIS_PORT=6379

# ==================== 数据库配置 ====================
POSTGRES_DB=skillhub
POSTGRES_USER=skillhub
POSTGRES_PASSWORD=你的强密码

# ==================== Redis 配置 ====================
# 使用默认配置即可

# ==================== 管理员账号 ====================
BOOTSTRAP_ADMIN_ENABLED=true
BOOTSTRAP_ADMIN_USER_ID=admin
BOOTSTRAP_ADMIN_USERNAME=admin
BOOTSTRAP_ADMIN_PASSWORD=你的强密码
BOOTSTRAP_ADMIN_DISPLAY_NAME=管理员
BOOTSTRAP_ADMIN_EMAIL=admin@your-company.com

# ==================== 存储配置 ====================
SKILLHUB_STORAGE_PROVIDER=local
STORAGE_BASE_PATH=/var/lib/skillhub/storage

# ==================== 安全扫描器 ====================
SKILLHUB_SECURITY_SCANNER_ENABLED=true
SKILLHUB_SECURITY_SCANNER_URL=http://skill-scanner:8000

# ==================== GitHub OAuth（可选） ====================
# OAUTH2_GITHUB_CLIENT_ID=your_client_id
# OAUTH2_GITHUB_CLIENT_SECRET=your_client_secret

# ==================== 其他配置 ====================
SESSION_COOKIE_SECURE=false
SKILLHUB_STORAGE_S3_REGION=us-east-1
SKILLHUB_STORAGE_S3_FORCE_PATH_STYLE=false
SKILLHUB_STORAGE_S3_AUTO_CREATE_BUCKET=false
SKILLHUB_STORAGE_S3_PRESIGN_EXPIRY=PT10M
```

---

**文档结束**
