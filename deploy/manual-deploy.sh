#!/bin/bash

# EtermAIWeb 手工部署脚本 (宝塔面板版本)
# 适配宝塔面板Python网站部署

set -e

PROJECT_DIR="/www/wwwroot/etermaiweb"
PYTHON_VERSION="python3"
VENV_DIR="$PROJECT_DIR/venv"
APP_USER="www"  # 宝塔面板默认用户
BT_PYTHON_PATH="/www/server/panel/pyenv/bin/python3"  # 宝塔Python路径

echo "=== EtermAIWeb 手工部署脚本 (宝塔面板版本) ==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 或 root 用户运行此脚本"
    exit 1
fi

# 检查宝塔Python环境
if [ -f "$BT_PYTHON_PATH" ]; then
    PYTHON_VERSION="$BT_PYTHON_PATH"
    echo "✅ 使用宝塔Python: $PYTHON_VERSION"
elif command -v python3.10 &> /dev/null; then
    PYTHON_VERSION="python3.10"
    echo "✅ 使用系统Python: $PYTHON_VERSION"
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION="python3"
    echo "✅ 使用系统Python: $PYTHON_VERSION"
else
    echo "❌ 未找到Python环境"
    exit 1
fi

# 检查PostgreSQL是否运行
if ! pgrep -f postgres > /dev/null; then
    echo "❌ PostgreSQL服务未运行，请在宝塔面板中启动PostgreSQL"
    exit 1
fi

echo "✅ 环境检查通过"

# 确保项目目录存在
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

# 安装gunicorn (如果还没有)
pip install gunicorn

# 创建必要的目录
echo "创建必要目录..."
mkdir -p logs backup static/uploads

# 设置权限 (宝塔面板使用www用户)
echo "设置文件权限..."
chown -R $APP_USER:$APP_USER $PROJECT_DIR
chmod +x $PROJECT_DIR/deploy/*.sh

# 检查数据库连接
echo "检查数据库连接..."
source $VENV_DIR/bin/activate
python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='etermaiweb',
        user='postgres',
        password='Postgre,.1'
    )
    print('✅ 数据库连接成功')
    conn.close()
except Exception as e:
    print(f'❌ 数据库连接失败: {e}')
    exit(1)
"

# 创建启动脚本 (宝塔面板可以使用这个)
echo "创建启动脚本..."
cat > $PROJECT_DIR/start.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os

# 添加项目路径到sys.path
project_path = '/www/wwwroot/etermaiweb'
if project_path not in sys.path:
    sys.path.insert(0, project_path)

# 激活虚拟环境
activate_this = '/www/wwwroot/etermaiweb/venv/bin/activate_this.py'
if os.path.exists(activate_this):
    exec(open(activate_this).read(), {'__file__': activate_this})

# 导入Flask应用
from app import app

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

chmod +x $PROJECT_DIR/start.py

# 创建gunicorn配置文件
echo "创建Gunicorn配置..."
cat > $PROJECT_DIR/gunicorn.conf.py << 'EOF'
# Gunicorn配置文件

# 服务器绑定
bind = "0.0.0.0:5000"

# 工作进程数
workers = 4

# 工作类型
worker_class = "sync"

# 超时时间
timeout = 120

# 保持连接时间
keepalive = 10

# 日志配置
errorlog = "/www/wwwroot/etermaiweb/logs/gunicorn_error.log"
accesslog = "/www/wwwroot/etermaiweb/logs/gunicorn_access.log"
loglevel = "info"

# 进程PID文件
pidfile = "/www/wwwroot/etermaiweb/logs/gunicorn.pid"

# 重载应用
reload = False

# 预加载应用
preload_app = True
EOF

# 创建systemd服务文件
echo "创建systemd服务..."
cat > /etc/systemd/system/etermaiweb.service << EOF
[Unit]
Description=EtermAIWeb Flask Application
After=network.target postgresql.service

[Service]
Type=forking
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$VENV_DIR/bin:\$PATH
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production
Environment=DATABASE_URL=postgresql://postgres:Postgre,.1@localhost:5432/etermaiweb
ExecStart=$VENV_DIR/bin/gunicorn -c gunicorn.conf.py app:app --daemon
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID
PIDFile=$PROJECT_DIR/logs/gunicorn.pid
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
    echo "或查看: tail -f $PROJECT_DIR/logs/gunicorn_error.log"
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
    echo "查看系统日志: journalctl -u etermaiweb -f"
    echo "查看应用日志: tail -f $PROJECT_DIR/logs/gunicorn_error.log"
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
echo "查看系统日志: journalctl -u etermaiweb -f"
echo "查看应用日志: tail -f /www/wwwroot/etermaiweb/logs/gunicorn_error.log"
echo "重启服务: systemctl restart etermaiweb"
echo "停止服务: systemctl stop etermaiweb"
echo ""
echo "🎯 宝塔面板配置提示:"
echo "1. 在宝塔面板中创建Python项目，指向 /www/wwwroot/etermaiweb/"
echo "2. 启动文件设置为: start.py"
echo "3. 模块名称: app:app"
echo "4. 端口设置: 5000" 