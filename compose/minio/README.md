# MinIO 部署说明

## 服务信息

| 项目 | 值 |
|------|-----|
| 镜像 | `minio/minio:latest` |
| S3 API 端口 | 9000 |
| 控制台端口 | 9001 |
| 用户名 | minioadmin |
| 密码 | minioadmin |

## 启动服务

```bash
docker compose up -d
```

## 访问控制台

浏览器打开 `http://<HOST_IP>:9001`，使用 `minioadmin` / `minioadmin` 登录。

## 数据持久化

数据存储在 `./data` 目录。

## 常用操作

### 创建 Bucket

可通过控制台 UI 创建，也可使用 mc 客户端：

```bash
# 安装 mc 客户端
curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && chmod +x /usr/local/bin/mc

# 配置别名
mc alias set local http://<HOST_IP>:9000 minioadmin minioadmin

# 创建 bucket
mc mb local/skillhub
```

### SkillHub S3 配置

在 SkillHub 的 `.env` 中配置：

| 变量 | 值 |
|------|-----|
| `SKILLHUB_STORAGE_S3_ENDPOINT` | `http://<HOST_IP>:9000` |
| `SKILLHUB_STORAGE_S3_ACCESS_KEY` | minioadmin |
| `SKILLHUB_STORAGE_S3_SECRET_KEY` | minioadmin |
| `SKILLHUB_STORAGE_S3_BUCKET` | skillhub |
| `SKILLHUB_STORAGE_S3_FORCE_PATH_STYLE` | true |
| `SKILLHUB_STORAGE_S3_AUTO_CREATE_BUCKET` | true |

## 安全建议

- 修改默认密码：编辑 `compose.yml` 中的 `MINIO_ROOT_USER` 和 `MINIO_ROOT_PASSWORD`
- 同步更新 SkillHub `.env` 中的 `SKILLHUB_STORAGE_S3_ACCESS_KEY` 和 `SKILLHUB_STORAGE_S3_SECRET_KEY`
