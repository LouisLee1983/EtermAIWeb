#!/bin/bash

echo "=== PostgreSQL检测和配置脚本 ==="

# 检查PostgreSQL是否安装
if command -v psql > /dev/null 2>&1; then
    echo "✅ PostgreSQL客户端已安装"
else
    echo "❌ PostgreSQL客户端未安装"
    echo "安装命令: sudo apt-get install postgresql-client"
    exit 1
fi

# 检查PostgreSQL服务
echo "检查PostgreSQL服务状态..."
systemctl list-units --type=service | grep postgres

# 检查PostgreSQL进程
echo "检查PostgreSQL进程..."
ps aux | grep postgres | grep -v grep

# 检查PostgreSQL端口
echo "检查PostgreSQL端口..."
netstat -tlnp | grep :5432 || ss -tlnp | grep :5432

# 尝试连接数据库
echo "尝试连接PostgreSQL数据库..."

DB_USER="postgres"
DB_PASSWORD="Postgre,.1"
DB_NAME="etermaiweb"

echo "方式1: 使用postgres用户直接连接"
if sudo -u postgres psql -c "\l"; then
    echo "✅ postgres用户连接成功"
    
    # 创建数据库
    echo "创建数据库 $DB_NAME（如果不存在）..."
    sudo -u postgres createdb $DB_NAME 2>/dev/null && echo "数据库创建成功" || echo "数据库可能已存在"
    
    # 设置密码
    echo "设置postgres用户密码..."
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$DB_PASSWORD';"
    
else
    echo "❌ postgres用户连接失败"
fi

echo ""
echo "方式2: 使用密码连接"
if PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -c "\l"; then
    echo "✅ 密码连接成功"
else
    echo "❌ 密码连接失败"
fi

# 检查配置文件
echo ""
echo "查找PostgreSQL配置文件..."
find /etc -name "postgresql.conf" 2>/dev/null
find /etc -name "pg_hba.conf" 2>/dev/null

echo ""
echo "=== 检测完成 ===" 