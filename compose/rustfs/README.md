# RustFS 部署说明

## 服务信息

| 项目 | 值 |
|------|-----|
| 镜像 | `rustfs/rustfs:latest` |
| 端口 | 8000 |
| 工作线程 | 4 |
| 最大上传 | 100MB |

## 启动服务

```bash
docker compose up -d
```

## 配置说明

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `RUSTFS_WORKERS` | 4 | 工作线程数 |
| `RUSTFS_MAX_UPLOAD_SIZE` | 104857600 | 最大上传大小（字节），默认 100MB |
| `RUSTFS_ALLOWED_EXTENSIONS` | 空（允许所有） | 允许的文件扩展名，逗号分隔 |
| `RUSTFS_STORAGE_PATH` | /data | 容器内存储路径 |
| `RUSTFS_PUBLIC_URL` | `http://172.16.0.1:8000` | 对外访问地址 |
| `RUSTFS_AUTH_TOKEN` | 空（无鉴权） | 上传鉴权 Token |

## 数据持久化

数据存储在 `./storage` 目录。

## 常用操作

### 健康检查

```bash
curl http://<HOST_IP>:8000/health
```

### 上传文件

```bash
curl -X POST http://<HOST_IP>:8000/upload -F "file=@test.txt"
```

## 安全建议

- 设置 `RUSTFS_AUTH_TOKEN` 防止未授权上传
- 修改 `RUSTFS_PUBLIC_URL` 为实际宿主机 IP
- 限制 `RUSTFS_ALLOWED_EXTENSIONS` 只允许需要的文件类型
