# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Docker Compose deployment repository** for SkillHub, not a source code repository. It contains docker compose configurations for deploying all SkillHub infrastructure services independently.

## Architecture

SkillHub uses a microservices deployment pattern with each service running in its own container and communicating via host IP + ports:

| Service | Port | Purpose | Dependency |
|---------|------|---------|------------|
| PostgreSQL | 5432 | Primary database | Required |
| Redis | 6379 | Cache/session storage | Required |
| MinIO | 9000/9001 | S3-compatible object storage | Required |
| Keycloak | 8180 | OIDC Provider (for LDAP bridging) | Optional |
| skillhub-server | 8081 | Backend API | Depends on postgres/redis/minio |
| skillhub-web | 8082 | Web frontend | Depends on server |
| skill-scanner | 8083 | Security scanning service | Optional |

## Directory Structure

```
compose/
├── postgres/      # Database service
├── redis/         # Cache service
├── minio/         # Object storage
├── keycloak/      # OIDC Provider (optional)
├── rustfs/        # Alternative storage (experimental)
└── skillhub/      # Main application (server/web/scanner)
```

Each service directory contains its own `compose.yml` and optional `.env` file.

## Common Commands

### Service Management

```bash
# Start a specific service (run from service directory)
cd compose/postgres && docker compose up -d
cd compose/redis && docker compose up -d
cd compose/minio && docker compose up -d
cd compose/skillhub && docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f server  # specific service

# Stop/restart
docker compose down
docker compose restart
docker compose restart server   # specific service
```

### Initial Setup

```bash
# 1. Find host IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# 2. Replace 172.16.0.1 with your host IP in all configs
find compose -type f \( -name "*.yml" -o -name "*.conf" \) -exec sed -i 's/172.16.0.1/YOUR_IP/g' {} \;

# 3. Copy and edit .env for skillhub
cd compose/skillhub
cp .env.example .env
# Edit HOST_IP, passwords, etc.
```

### Verification

```bash
# Check running containers
docker ps

# Test port connectivity
nc -zv <HOST_IP> 5432  # postgres
nc -zv <HOST_IP> 6379  # redis
nc -zv <HOST_IP> 9000  # minio
nc -zv <HOST_IP> 8081  # skillhub api
```

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| PostgreSQL | skillhub | skillhub_demo |
| MinIO | minioadmin | minioadmin |
| Keycloak | admin | ChangeMe!2026 |
| SkillHub Admin | admin | ChangeMe!2026 |

## Important Configurations

### SkillHub compose.yml Fixes

The `compose/skillhub/compose.yml` requires explicit OAuth2 disable flags to prevent Spring Boot from failing with "Client id must not be empty" error:

```yaml
SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_GITHUB_ENABLED: "false"
SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_GITLAB_ENABLED: "false"
SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_OIDC_ENABLED: "false"
```

**Remove the corresponding line only when actually enabling that OAuth provider.**

### Keycloak OIDC Setup

When enabling OIDC:
1. Deploy Keycloak first (requires its own postgres database - run `init.sql` in postgres)
2. Create `skillhub` realm in Keycloak
3. Create OIDC client with redirect URI: `http://<HOST_IP>:8082/login/oauth2/code/oidc`
4. Update SkillHub `.env` with client credentials and issuer URI

## Data Persistence Locations

| Path | Service |
|------|---------|
| `compose/postgres/data` | PostgreSQL database |
| `compose/redis/data` | Redis data |
| `compose/minio/data` | MinIO S3 objects |
| `compose/skillhub/storage` | SkillHub local storage |

## One-click Deployment Script

There is an official runtime script that dynamically fetches and deploys compose configurations:

```bash
# Quick deploy with Aliyun mirror (recommended for China)
curl -fsSL https://imageless.oss-cn-beijing.aliyuncs.com/runtime.sh | sh -s -- up --aliyun --public-url https://skillhub.your-company.com --version latest

# View script help
curl -fsSL https://imageless.oss-cn-beijing.aliyuncs.com/runtime.sh | sh -s -- --help
```

**Key options:**
- `--aliyun` - Use Aliyun Container Registry mirror (faster for China mainland
- `--public-url <url>` - Set public base URL
- `--version <tag>` - Specify image version
- `--no-scanner` - Disable scanner service
- `--home <dir>` - Specify runtime files directory

**Troubleshooting Tip:** If services fail to start, first check if there are compose file updates by re-running the deployment script - it always fetches the latest compose configurations.

