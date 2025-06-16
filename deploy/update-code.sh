#!/bin/bash

# EtermAIWeb 代码更新脚本 (宝塔面板版本)
# 只负责同步代码，宝塔面板会自动管理Python项目

set -e

PROJECT_DIR="/www/wwwroot/etermaiweb"

echo "=== EtermAIWeb 代码同步脚本 (宝塔面板版本) ==="

# 检查项目目录
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ 项目目录不存在: $PROJECT_DIR"
    exit 1
fi

# 切换到项目目录
cd $PROJECT_DIR || { echo "❌ 无法进入项目目录"; exit 1; }

# 配置 Git 安全目录，避免权限问题
echo "🔐 配置 Git 安全设置..."
git config --global --add safe.directory $PROJECT_DIR

echo "📥 同步最新代码..."

# 保存当前分支和提交信息
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "当前提交: $CURRENT_COMMIT"

# 拉取最新代码
git fetch origin
git reset --hard origin/main

# 获取新的提交信息
NEW_COMMIT=$(git rev-parse HEAD)
echo "最新提交: $NEW_COMMIT"

# 检查是否有代码更新
if [ "$CURRENT_COMMIT" = "$NEW_COMMIT" ]; then
    echo "⏭️  代码无更新，跳过后续步骤"
    exit 0
fi

# 显示更新的文件
echo "📋 本次更新的文件:"
git diff --name-only $CURRENT_COMMIT $NEW_COMMIT | head -10

# 设置正确的文件权限 (宝塔面板使用www用户)
echo "🔐 设置文件权限..."
chown -R www:www $PROJECT_DIR
chmod +x $PROJECT_DIR/deploy/*.sh

echo ""
echo "✅ 代码同步完成！"
echo "📍 项目目录: $PROJECT_DIR"
echo "🎯 请在宝塔面板中重启Python项目以应用更新"
echo ""
echo "💡 宝塔面板操作提示:"
echo "1. 登录宝塔面板"
echo "2. 进入 网站 → Python项目"
echo "3. 找到 EtermAIWeb 项目"
echo "4. 点击 重启 按钮"
echo ""
echo "🌐 项目访问地址: http://47.111.119.238:5000" 