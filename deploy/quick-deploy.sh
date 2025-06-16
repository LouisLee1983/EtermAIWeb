#!/bin/bash

# EtermAIWeb 快速部署脚本
# 使用优化策略加速初始部署

set -e

PROJECT_DIR="/www/wwwroot/etermaiweb"
echo "=== EtermAIWeb 快速部署脚本 ==="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装"
    exit 1
fi

cd $PROJECT_DIR

echo "🚀 开始快速部署..."

# 1. 并行拉取基础镜像（加速构建）
echo "📦 预拉取基础镜像..."
docker pull python:3.10-alpine &
docker pull redis:7-alpine &
wait

echo "✅ 基础镜像拉取完成"

# 2. 构建应用镜像（使用优化的Dockerfile）
echo "🔨 构建应用镜像..."
docker-compose build --parallel

# 3. 启动服务
echo "🚀 启动服务..."
docker-compose up -d

# 4. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 20

# 5. 健康检查
echo "🏥 执行健康检查..."
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
        echo "✅ 应用启动成功！"
        break
    else
        echo "⏳ 等待应用启动... (尝试 $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ 应用启动失败"
    docker-compose logs app
    exit 1
fi

# 6. 显示状态
echo ""
echo "🎉 快速部署完成！"
echo "============================================"
echo "访问地址: http://47.111.119.238:5000"
echo "健康检查: http://47.111.119.238:5000/api/health"
echo "============================================"
echo ""
echo "📋 容器状态:"
docker-compose ps

echo ""
echo "📊 镜像大小:"
docker images | grep etermaiweb 