#!/bin/bash

# EtermAIWeb 代码更新脚本
# 用于GitHub Actions自动同步代码并重启服务

set -e

PROJECT_DIR="/www/wwwroot/etermaiweb"
VENV_DIR="$PROJECT_DIR/venv"

echo "=== EtermAIWeb 代码更新脚本 ==="

# 切换到项目目录
cd $PROJECT_DIR || { echo "项目目录不存在"; exit 1; }

echo "📥 拉取最新代码..."
git fetch origin
git reset --hard origin/main

# 检查是否需要更新依赖
if git diff HEAD~1 HEAD --name-only | grep -q "requirements.txt"; then
    echo "📦 检测到依赖变化，更新Python包..."
    source $VENV_DIR/bin/activate
    pip install -r requirements.txt
    echo "✅ 依赖更新完成"
else
    echo "⏭️  依赖无变化，跳过更新"
fi

# 重启服务让新代码生效
echo "🔄 重启EtermAIWeb服务..."
systemctl restart etermaiweb

# 等待服务启动
echo "⏳ 等待服务重启..."
sleep 5

# 检查服务状态
if systemctl is-active --quiet etermaiweb; then
    echo "✅ 服务重启成功"
else
    echo "❌ 服务重启失败"
    echo "查看日志: journalctl -u etermaiweb -f"
    exit 1
fi

# 快速健康检查
echo "🏥 健康检查..."
sleep 5
if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
    echo "✅ 应用运行正常"
else
    echo "⚠️  健康检查失败，请手动检查"
fi

echo ""
echo "🎉 代码更新完成！"
echo "访问地址: http://47.111.119.238:5000" 