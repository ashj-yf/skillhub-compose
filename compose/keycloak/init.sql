-- Keycloak 初始化 SQL
-- 手动执行：docker exec -i postgres psql -U skillhub -d skillhub < init.sql

-- 创建数据库
CREATE DATABASE keycloak;

-- 创建专用用户
CREATE USER keycloak WITH PASSWORD 'keycloak_demo';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

-- 切换到 keycloak 数据库，授权 schema
\c keycloak
GRANT ALL ON SCHEMA public TO keycloak;
