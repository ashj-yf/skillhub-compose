# Redis 部署说明

## 服务信息

| 项目 | 值 |
|------|-----|
| 镜像 | `redis:7-alpine` |
| 端口 | 6379 |
| 持久化 | AOF（appendonly yes） |

## 启动服务

```bash
docker compose up -d
```

## 数据持久化

数据存储在 `./data` 目录，启用 AOF 持久化模式。

## 常用操作

### 连接 Redis

```bash
docker exec -it redis redis-cli
```

### 查看内存使用

```bash
docker exec redis redis-cli info memory
```

### 清空数据

```bash
docker exec redis redis-cli FLUSHALL
```

## 安全建议

- 生产环境建议设置密码，在 `compose.yml` 的 `command` 中添加 `--requirepass your_password`
- 限制端口绑定地址，将 `0.0.0.0:6379` 改为 `127.0.0.1:6379`
