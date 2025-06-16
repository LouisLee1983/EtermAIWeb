#!/bin/bash

# EtermAIWeb 项目部署脚本
# 用于在云服务器上初始化和更新项目

set -e  # 出错时停止执行

# 配置变量
PROJECT_NAME="etermaiweb"
PROJECT_DIR="/www/wwwroot/etermaiweb"
SERVICE_NAME="etermaiweb"
PYTHON_VERSION="3.10"
USER="www-data"
REPO_URL="https://github.com/LouisLee1983/EtermAIWeb.git"

echo "=== EtermAIWeb 部署脚本 ==="
echo "项目目录: $PROJECT_DIR"
echo "服务名称: $SERVICE_NAME"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 创建项目目录
if [ ! -d "$PROJECT_DIR" ]; then
    echo "创建项目目录..."
    mkdir -p $PROJECT_DIR
    chown $USER:$USER $PROJECT_DIR
fi

# 安装系统依赖
echo "安装系统依赖..."
apt-get update
apt-get install -y python3 python3-pip python3-venv git nginx supervisor redis-server postgresql postgresql-contrib

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
chown -R $USER:$USER $PROJECT_DIR

# 创建Python虚拟环境
if [ ! -d "$PROJECT_DIR/venv" ]; then
    echo "创建Python虚拟环境..."
    sudo -u $USER python3 -m venv venv
fi

# 激活虚拟环境并安装依赖
echo "安装Python依赖..."
sudo -u $USER bash -c "
    source venv/bin/activate
    pip install --upgrade pip
    if [ -f requirements.txt ]; then
        pip install -r requirements.txt
    fi
"

# 创建systemd服务文件
echo "创建systemd服务文件..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=EtermAIWeb Flask Application
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
ExecStart=$PROJECT_DIR/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 创建Nginx配置
echo "创建Nginx配置..."
cat > /etc/nginx/sites-available/$PROJECT_NAME << EOF
server {
    listen 80;
    server_name 47.111.119.238;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static {
        alias $PROJECT_DIR/app/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# 启用Nginx站点
if [ ! -L "/etc/nginx/sites-enabled/$PROJECT_NAME" ]; then
    ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
fi

# 删除默认Nginx配置
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi

# 重载systemd配置
systemctl daemon-reload

# 启动并启用服务
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

# 重启Nginx
systemctl restart nginx
systemctl enable nginx

# 检查服务状态
echo "检查服务状态..."
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ $SERVICE_NAME 服务正在运行"
else
    echo "❌ $SERVICE_NAME 服务未能启动"
    systemctl status $SERVICE_NAME
    exit 1
fi

if systemctl is-active --quiet nginx; then
    echo "✅ Nginx 服务正在运行"
else
    echo "❌ Nginx 服务未能启动"
    systemctl status nginx
    exit 1
fi

echo "🎉 部署完成！"
echo "访问地址: http://47.111.119.238"
echo "日志查看: journalctl -u $SERVICE_NAME -f" 