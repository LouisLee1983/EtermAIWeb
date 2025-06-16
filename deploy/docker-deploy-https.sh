#!/bin/bash

# EtermAIWeb Docker部署脚本 (HTTPS版本)
# 用于在云服务器上使用Docker部署项目

set -e  # 出错时停止执行

# 配置变量
PROJECT_NAME="etermaiweb"
PROJECT_DIR="/www/wwwroot/etermaiweb"
REPO_URL="https://github.com/LouisLee1983/EtermAIWeb.git"
DOCKER_COMPOSE_VERSION="2.29.2"

echo "=== EtermAIWeb Docker部署脚本 (HTTPS版本) ==="
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

# 配置Git缓冲区（解决网络问题）
echo "配置Git网络优化..."
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# 创建项目目录
if [ ! -d "$PROJECT_DIR" ]; then
    echo "创建项目目录..."
    mkdir -p $PROJECT_DIR
fi

# 克隆或更新代码
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "克隆项目代码..."
    # 尝试多次克隆，增加重试机制
    for i in {1..3}; do
        echo "尝试克隆 (第${i}次)..."
        if git clone --depth 1 $REPO_URL $PROJECT_DIR; then
            echo "✅ 克隆成功"
            break
        else
            echo "❌ 克隆失败，等待重试..."
            sleep 5
            if [ $i -eq 3 ]; then
                echo "❌ 克隆失败，请检查网络连接或使用SSH方式"
                exit 1
            fi
        fi
    done
else
    echo "更新项目代码..."
    cd $PROJECT_DIR
    git fetch origin --depth 1
    git reset --hard origin/main
fi

cd $PROJECT_DIR

# 检查PostgreSQL服务
echo "检查PostgreSQL服务..."

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
    if ! systemctl is-active --quiet $PG_SERVICE; then
        echo "❌ PostgreSQL服务未运行，尝试启动..."
        systemctl start $PG_SERVICE
        if ! systemctl is-active --quiet $PG_SERVICE; then
            echo "❌ PostgreSQL服务启动失败"
            exit 1
        fi
    fi
    echo "✅ PostgreSQL服务正在运行"
else
    echo "⚠️  未检测到PostgreSQL systemd服务，尝试直接连接数据库..."
    # 直接测试数据库连接，而不依赖systemd服务
fi

# 检查数据库连接和创建数据库
echo "检查数据库连接..."
DB_NAME="etermaiweb"
DB_USER="postgres" 
DB_PASSWORD="Postgre,.1"

# 检查数据库是否存在，如果不存在则创建
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "数据库 $DB_NAME 不存在，正在创建..."
    sudo -u postgres createdb $DB_NAME
    echo "✅ 数据库 $DB_NAME 创建成功"
else
    echo "✅ 数据库 $DB_NAME 已存在"
fi

# 检查PostgreSQL配置是否允许Docker连接
echo "检查PostgreSQL配置..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP 'PostgreSQL \K[0-9]+')
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# 确保PostgreSQL监听所有地址
if ! grep -q "listen_addresses = '\*'" $PG_CONF; then
    echo "配置PostgreSQL监听地址..."
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
    echo "✅ PostgreSQL监听地址已配置"
fi

# 确保Docker网络可以连接
if ! grep -q "172.17.0.0/16" $PG_HBA; then
    echo "配置PostgreSQL允许Docker网络连接..."
    echo "host    all             all             172.17.0.0/16           md5" >> $PG_HBA
    echo "✅ PostgreSQL Docker网络权限已配置"
    
    # 重启PostgreSQL使配置生效
    echo "重启PostgreSQL服务..."
    systemctl restart postgresql
    sleep 5
    echo "✅ PostgreSQL服务重启完成"
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

# 测试数据库连接
echo "测试数据库连接..."
if PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ 数据库连接测试成功"
else
    echo "❌ 数据库连接测试失败，请检查数据库配置"
    echo "提示：可能需要为postgres用户设置密码："
    echo "sudo -u postgres psql -c \"ALTER USER postgres PASSWORD '$DB_PASSWORD';\""
    exit 1
fi

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