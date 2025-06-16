# Docker部署指南

## 概述

本文档指导如何使用Docker部署EtermAIWeb项目到云服务器47.111.119.238。

## 部署架构

```
GitHub仓库 → GitHub Actions → 云服务器Docker环境
                ↓
          Docker Compose编排
                ↓
    ┌─────────────────────────────────────┐
    │         Docker容器环境              │
    │  ┌─────────┐  ┌─────────┐          │
    │  │  Nginx  │  │  Flask  │          │
    │  │ 容器:80 │  │ 容器:5000│          │
    │  └─────────┘  └─────────┘          │
    │  ┌─────────┐  ┌─────────┐          │
    │  │PostgreSQL│ │  Redis  │          │
    │  │ 容器:5432│  │ 容器:6379│          │
    │  └─────────┘  └─────────┘          │
    └─────────────────────────────────────┘
```

## 🚀 快速部署

### 前置条件
- 云服务器已安装Docker (您当前版本: 28.2.2)
- 云服务器已安装Docker Compose
- 已配置GitHub SSH密钥

### 一键部署
```bash
# 登录云服务器
ssh root@47.111.119.238

# 下载并运行Docker部署脚本
curl -O https://raw.githubusercontent.com/LouisLee1983/EtermAIWeb/main/deploy/docker-deploy.sh
chmod +x docker-deploy.sh
sudo ./docker-deploy.sh
```

## 🏗️ 手动部署步骤

### 1. 准备环境
```bash
# 检查Docker版本
docker --version

# 安装Docker Compose (如果未安装)
curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 2. 克隆项目代码
```bash
cd /www/wwwroot
git clone https://github.com/LouisLee1983/EtermAIWeb.git etermaiweb
cd etermaiweb
```

### 3. 启动服务
```bash
# 创建必需目录
mkdir -p logs logs/nginx backup

# 启动所有服务
docker-compose up -d --build

# 查看启动状态
docker-compose ps
```

### 4. 验证部署
```bash
# 检查容器状态
docker-compose ps

# 检查应用健康状态
curl http://localhost/api/health

# 查看日志
docker-compose logs -f
```

## 📦 容器服务说明

### 1. Flask应用容器 (etermaiweb-app)
- **端口**: 5000
- **功能**: 主要业务逻辑处理
- **依赖**: PostgreSQL、Redis
- **健康检查**: `/api/health`

### 2. Nginx代理容器 (etermaiweb-nginx)
- **端口**: 80, 443
- **功能**: 反向代理、负载均衡、静态文件服务
- **配置文件**: `nginx/conf.d/default.conf`

### 3. PostgreSQL数据库容器 (etermaiweb-db)
- **端口**: 5432
- **功能**: 数据存储
- **数据卷**: `postgres_data`
- **默认配置**: 
  - 数据库: `etermaiweb`
  - 用户: `postgres`
  - 密码: `password`

### 4. Redis缓存容器 (etermaiweb-redis)
- **端口**: 6379
- **功能**: 缓存、会话存储
- **数据卷**: `redis_data`

## 🔧 常用管理命令

### 服务管理
```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启特定服务
docker-compose restart app

# 重新构建并启动
docker-compose up -d --build

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f [服务名]
```

### 数据管理
```bash
# 备份数据库
docker exec etermaiweb-db pg_dump -U postgres etermaiweb > backup/db_backup_$(date +%Y%m%d_%H%M%S).sql

# 恢复数据库
docker exec -i etermaiweb-db psql -U postgres etermaiweb < backup/db_backup.sql

# 备份数据卷
docker run --rm -v etermaiweb_postgres_data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/postgres_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

### 容器管理
```bash
# 进入容器
docker exec -it etermaiweb-app bash
docker exec -it etermaiweb-db psql -U postgres etermaiweb

# 查看容器资源使用
docker stats

# 清理未使用资源
docker system prune -f

# 查看镜像
docker images
```

## 🔄 更新部署

### 自动更新 (通过GitHub Actions)
代码推送到main分支后会自动触发部署。

### 手动更新
```bash
cd /www/wwwroot/etermaiweb

# 拉取最新代码
git pull origin main

# 重新构建并启动
docker-compose down
docker-compose up -d --build
```

## 📊 监控和日志

### 日志查看
```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f app
docker-compose logs -f nginx
docker-compose logs -f db

# 查看实时日志
tail -f logs/nginx/access.log
tail -f logs/nginx/error.log
```

### 性能监控
```bash
# 容器资源使用情况
docker stats

# 系统资源使用
htop
df -h
free -h
```

## 🛠️ 故障排除

### 1. 容器启动失败
```bash
# 查看详细错误信息
docker-compose logs [容器名]

# 检查端口占用
netstat -tlnp | grep :80
netstat -tlnp | grep :5000

# 重新构建镜像
docker-compose build --no-cache
docker-compose up -d
```

### 2. 应用无法访问
```bash
# 检查防火墙
ufw status
iptables -L

# 检查Nginx配置
docker exec etermaiweb-nginx nginx -t

# 检查网络连接
docker network ls
docker network inspect etermaiweb_etermaiweb-network
```

### 3. 数据库连接问题
```bash
# 检查数据库状态
docker exec etermaiweb-db pg_isready -U postgres

# 检查数据库连接
docker exec -it etermaiweb-db psql -U postgres -c "\l"

# 重启数据库
docker-compose restart db
```

## 🔐 安全配置

### 1. 环境变量配置
创建 `.env` 文件：
```bash
# 数据库配置
POSTGRES_DB=etermaiweb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password

# Flask配置
FLASK_SECRET_KEY=your_secret_key
FLASK_ENV=production

# Redis配置
REDIS_PASSWORD=your_redis_password
```

### 2. 防火墙配置
```bash
# 只开放必要端口
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable
```

### 3. SSL证书配置
```bash
# 使用Let's Encrypt
apt install certbot
certbot --nginx -d 47.111.119.238
```

## 📈 扩展配置

### 1. 多副本部署
修改 `docker-compose.yml`：
```yaml
app:
  build: .
  deploy:
    replicas: 3
  # ... 其他配置
```

### 2. 负载均衡
配置Nginx upstream：
```nginx
upstream app_servers {
    server app_1:5000;
    server app_2:5000;
    server app_3:5000;
}
```

## 🎯 最佳实践

1. **定期备份数据**
2. **监控容器资源使用**
3. **及时更新Docker镜像**
4. **使用专用网络隔离容器**
5. **配置日志轮转**
6. **设置健康检查**
7. **使用非root用户运行容器**

## 📞 技术支持

如有问题，请检查：
1. Docker和Docker Compose版本兼容性
2. 系统资源是否充足
3. 网络端口是否被占用
4. 日志文件中的错误信息

更多问题可以查看项目GitHub Issues或联系维护人员。 