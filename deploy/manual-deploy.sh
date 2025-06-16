#!/bin/bash

# EtermAIWeb 手工部署脚本
# 传统Python虚拟环境部署方式

set -e

PROJECT_DIR="/www/wwwroot/etermaiweb"
PYTHON_VERSION="python3.10"
VENV_DIR="$PROJECT_DIR/venv"
APP_USER="www-data"  # 或者 nginx，根据您的web服务器用户

echo "=== EtermAIWeb 手工部署脚本 ==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 检查Python是否安装
if ! command -v $PYTHON_VERSION &> /dev/null; then
    echo "❌ $PYTHON_VERSION 未安装"
    echo "请先安装: sudo apt-get install python3.10 python3.10-venv python3.10-dev"
    exit 1
fi

# 检查PostgreSQL是否运行
if ! pgrep -f postgres > /dev/null; then
    echo "❌ PostgreSQL服务未运行"
    exit 1
fi

echo "✅ 环境检查通过"

# 创建项目目录
if [ ! -d "$PROJECT_DIR" ]; then
    echo "创建项目目录..."
    mkdir -p $PROJECT_DIR
fi

cd $PROJECT_DIR

# 克隆或更新代码
if [ ! -d ".git" ]; then
    echo "克隆项目代码..."
    git clone https://github.com/LouisLee1983/EtermAIWeb.git .
else
    echo "更新项目代码..."
    git fetch origin
    git reset --hard origin/main
fi

# 创建Python虚拟环境
if [ ! -d "$VENV_DIR" ]; then
    echo "创建Python虚拟环境..."
    $PYTHON_VERSION -m venv $VENV_DIR
fi

# 激活虚拟环境并安装依赖
echo "安装Python依赖..."
source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 创建必要的目录
echo "创建必要目录..."
mkdir -p logs backup static/uploads

# 设置权限
echo "设置文件权限..."
chown -R $APP_USER:$APP_USER $PROJECT_DIR
chmod +x $PROJECT_DIR/deploy/*.sh

# 创建systemd服务文件
echo "创建systemd服务..."
cat > /etc/systemd/system/etermaiweb.service << EOF
[Unit]
Description=EtermAIWeb Flask Application
After=network.target postgresql.service

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$VENV_DIR/bin
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production
Environment=DATABASE_URL=postgresql://postgres:Postgre,.1@localhost:5432/etermaiweb
ExecStart=$VENV_DIR/bin/gunicorn --bind 0.0.0.0:5000 --workers 4 --timeout 120 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd并启动服务
echo "启动EtermAIWeb服务..."
systemctl daemon-reload
systemctl enable etermaiweb
systemctl restart etermaiweb

# 等待服务启动
echo "等待服务启动..."
sleep 10

# 检查服务状态
if systemctl is-active --quiet etermaiweb; then
    echo "✅ EtermAIWeb服务启动成功"
else
    echo "❌ EtermAIWeb服务启动失败"
    echo "查看日志: journalctl -u etermaiweb -f"
    exit 1
fi

# 健康检查
echo "执行健康检查..."
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
    echo "查看日志: journalctl -u etermaiweb -f"
    exit 1
fi

echo ""
echo "🎉 手工部署完成！"
echo "============================================"
echo "访问地址: http://47.111.119.238:5000"
echo "健康检查: http://47.111.119.238:5000/api/health"
echo "============================================"
echo ""
echo "📋 服务管理命令:"
echo "查看状态: systemctl status etermaiweb"
echo "查看日志: journalctl -u etermaiweb -f"
echo "重启服务: systemctl restart etermaiweb"
echo "停止服务: systemctl stop etermaiweb" 