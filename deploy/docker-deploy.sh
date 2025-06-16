#!/bin/bash

# EtermAIWeb Docker部署脚本
# 用于在云服务器上使用Docker部署项目

set -e  # 出错时停止执行

# 配置变量
PROJECT_NAME="etermaiweb"
PROJECT_DIR="/www/wwwroot/etermaiweb"
REPO_URL="https://github.com/LouisLee1983/EtermAIWeb.git"
DOCKER_COMPOSE_VERSION="2.29.2"

echo "=== EtermAIWeb Docker部署脚本 ==="
echo "项目目录: $PROJECT_DIR"
echo "使用Docker Compose进行部署"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "安装Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

echo "✅ Docker版本: $(docker --version)"
echo "✅ Docker Compose版本: $(docker-compose --version)"

# 创建项目目录
if [ ! -d "$PROJECT_DIR" ]; then
    echo "创建项目目录..."
    mkdir -p $PROJECT_DIR
fi

# 克隆或更新代码
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "克隆项目代码..."
    git clone $REPO_URL $PROJECT_DIR
else
    echo "更新项目代码..."
    cd $PROJECT_DIR
    git fetch origin
    git reset --hard origin/main
fi

cd $PROJECT_DIR

# 创建必需的目录
echo "创建必需的目录..."
mkdir -p logs logs/nginx

# 停止现有容器（如果存在）
echo "停止现有容器..."
docker-compose down || true

# 清理旧镜像（可选）
echo "清理未使用的Docker镜像..."
docker system prune -f || true

# 构建并启动服务
echo "构建并启动Docker服务..."
docker-compose up -d --build

# 等待服务启动
echo "等待服务启动..."
sleep 30

# 检查服务状态
echo "检查服务状态..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Docker服务启动成功"
else
    echo "❌ Docker服务启动失败"
    docker-compose logs
    exit 1
fi

# 检查应用健康状态
echo "检查应用健康状态..."
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost/api/health > /dev/null 2>&1; then
        echo "✅ 应用健康检查通过"
        break
    else
        echo "⏳ 等待应用启动... (尝试 $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ 应用健康检查失败"
    docker-compose logs app
    exit 1
fi

# 显示运行状态
echo ""
echo "🎉 部署完成！"
echo "============================================"
echo "访问地址: http://47.111.119.238"
echo "健康检查: http://47.111.119.238/api/health"
echo "============================================"
echo ""
echo "📋 容器状态:"
docker-compose ps

echo ""
echo "🔧 常用命令:"
echo "查看日志: docker-compose logs -f"
echo "重启服务: docker-compose restart"
echo "停止服务: docker-compose down"
echo "更新服务: docker-compose pull && docker-compose up -d"

echo ""
echo "📊 系统资源使用情况:"
docker stats --no-stream 