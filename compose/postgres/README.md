# PostgreSQL 部署说明

## 服务信息

| 项目 | 值 |
|------|-----|
| 镜像 | `postgres:16-alpine` |
| 端口 | 5432 |
| 数据库 | skillhub |
| 用户名 | skillhub |
| 密码 | skillhub_demo |

## 启动服务

```bash
docker compose up -d
```

## 数据持久化

数据存储在 `./data` 目录，删除容器不会丢失数据。

## 常用操作

### 连接数据库

```bash
docker exec -it postgres psql -U skillhub -d skillhub
```

### 创建新数据库

为其他服务（如 Keycloak）创建数据库：

```bash
docker exec -i postgres psql -U skillhub -d skillhub -c "CREATE DATABASE keycloak;"
```

### 备份

```bash
docker exec postgres pg_dump -U skillhub skillhub > backup.sql
```

### 恢复

```bash
docker exec -i postgres psql -U skillhub skillhub < backup.sql
```

## 安全建议

- 修改默认密码：编辑 `compose.yml` 中的 `POSTGRES_PASSWORD`
- 生产环境限制端口绑定地址，将 `0.0.0.0:5432` 改为 `127.0.0.1:5432`
