# Keycloak 部署说明

## 前置条件

### 1. 创建数据库

Keycloak 需要独立的 PostgreSQL 数据库，需手动创建：

```bash
docker exec -i postgres psql -U skillhub -d skillhub -c "CREATE DATABASE keycloak;"
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

修改 `.env` 中的 `POSTGRES_HOST` 为实际宿主机 IP，以及数据库密码等。

## 启动服务

```bash
docker compose up -d
```

## 访问控制台

- 地址：`http://<HOST_IP>:8180`
- 用户名：`.env` 中的 `KEYCLOAK_ADMIN_USERNAME`
- 密码：`.env` 中的 `KEYCLOAK_ADMIN_PASSWORD`

## 配置 SkillHub OIDC 登录

### 1. 创建 Realm

1. 登录 Keycloak 控制台
2. 左上角下拉菜单 → Create Realm → 名称填 `skillhub`

### 2. 创建 Client

1. 进入 `skillhub` Realm → Clients → Create client
2. Client ID: `skillhub`
3. Client authentication: 开启
4. Valid redirect URIs: `http://<HOST_IP>:8082/login/oauth2/code/oidc`
5. 创建后在 Credentials 页复制 Client Secret

### 3. 配置 SkillHub

在 SkillHub 的 `.env` 中填入：

```bash
SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_OIDC_CLIENT_ID=skillhub
SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_OIDC_CLIENT_SECRET=<复制的 Client Secret>
SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_OIDC_ISSUER_URI=http://<HOST_IP>:8180/realms/skillhub
```

重启 SkillHub 服务生效。

### 4. 配置 LDAP（可选）

1. 进入 `skillhub` Realm → User Federation → Add provider → ldap
2. 填写 LDAP 连接信息（Connection URL、Bind DN、Users DN 等）
3. 保存后点击 Sync all users

用户即可通过 LDAP 账号登录 SkillHub。
