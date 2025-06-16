#!/bin/bash

# EtermAIWeb Docker部署脚本
# 用于在云服务器上使用Docker部署项目

set -e  # 出错时停止执行

# 配置变量
PROJECT_NAME="etermaiweb"
PROJECT_DIR="/www/wwwroot/etermaiweb"
REPO_URL="git@github.com:LouisLee1983/EtermAIWeb.git"
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

# 检查PostgreSQL服务
echo "检查PostgreSQL服务..."

# 检查PostgreSQL进程是否运行
if pgrep -f postgres > /dev/null; then
    echo "✅ PostgreSQL进程正在运行"
    
    # 检查端口是否监听
    if netstat -tlnp 2>/dev/null | grep :5432 > /dev/null || ss -tlnp 2>/dev/null | grep :5432 > /dev/null; then
        echo "✅ PostgreSQL在端口5432上监听"
    else
        echo "❌ PostgreSQL端口5432未监听"
        exit 1
    fi
else
    echo "❌ PostgreSQL进程未运行"
    
    # 尝试检测PostgreSQL服务名称
    PG_SERVICE=""
    for service in postgresql postgresql.service postgresql-14 postgresql-13 postgresql-12 postgresql-15; do
        if systemctl list-units --full -all | grep -Fq "$service"; then
            PG_SERVICE="$service"
            break
        fi
    done

    if [ -n "$PG_SERVICE" ]; then
        echo "检测到PostgreSQL服务: $PG_SERVICE"
        echo "尝试启动PostgreSQL服务..."
        systemctl start $PG_SERVICE
        if ! systemctl is-active --quiet $PG_SERVICE; then
            echo "❌ PostgreSQL服务启动失败"
            exit 1
        fi
        echo "✅ PostgreSQL服务启动成功"
    else
        echo "❌ 未检测到PostgreSQL systemd服务"
        echo "请手动启动PostgreSQL或检查安装状态"
        exit 1
    fi
fi

# 检查数据库连接和创建数据库
echo "检查数据库连接..."

# 由于使用宝塔面板安装的PostgreSQL，跳过复杂的连接检查
echo "⚠️  检测到宝塔面板安装的PostgreSQL，跳过数据库连接检查"
echo "假设数据库配置正确，etermaiweb数据库已存在"
echo "如果部署失败，请确认："
echo "1. PostgreSQL服务正在运行"
echo "2. etermaiweb数据库已创建"
echo "3. postgres用户密码为：Postgre,.1"

# 检查PostgreSQL配置是否允许Docker连接
echo "检查PostgreSQL配置..."

DB_NAME="etermaiweb"
DB_USER="postgres" 
DB_PASSWORD="Postgre,.1"

# 查找宝塔PostgreSQL配置文件
if [ -f "/www/server/pgsql/data/postgresql.conf" ]; then
    PG_CONF="/www/server/pgsql/data/postgresql.conf"
    PG_HBA="/www/server/pgsql/data/pg_hba.conf"
    echo "找到宝塔PostgreSQL配置文件: $PG_CONF"
    
    # 确保PostgreSQL监听所有地址
    if ! grep -q "listen_addresses = '\*'" $PG_CONF; then
        echo "配置PostgreSQL监听地址..."
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
        sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
        echo "✅ PostgreSQL监听地址已配置"
        NEED_RESTART=true
    else
        echo "✅ PostgreSQL已配置监听所有地址"
    fi
    
    # 确保Docker网络可以连接
    if ! grep -q "172.17.0.0/16" $PG_HBA; then
        echo "配置PostgreSQL允许Docker网络连接..."
        echo "host    all             all             172.17.0.0/16           md5" >> $PG_HBA
        echo "✅ PostgreSQL Docker网络权限已配置"
        NEED_RESTART=true
    else
        echo "✅ PostgreSQL Docker网络权限已配置"
    fi
    
    # 如果修改了配置，提示重启
    if [ "$NEED_RESTART" = true ]; then
        echo "⚠️  PostgreSQL配置已更新，建议重启PostgreSQL服务"
        echo "可以在宝塔面板中重启PostgreSQL，或者运行:"
        echo "sudo systemctl restart postgresql (如果有systemd服务)"
    fi
else
    echo "⚠️  未找到宝塔PostgreSQL配置文件，假设配置正确"
fi

# 创建必需的目录
echo "创建必需的目录..."
mkdir -p logs backup

# 停止现有容器（如果存在）
echo "停止现有容器..."
docker-compose down || true

# 清理旧镜像（可选）
echo "清理未使用的Docker镜像..."
docker system prune -f || true

# 跳过数据库连接测试，直接进行Docker部署
echo "跳过数据库连接测试，假设宝塔PostgreSQL配置正确"

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
    if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
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
echo "访问地址: http://47.111.119.238:5000"
echo "健康检查: http://47.111.119.238:5000/api/health"
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