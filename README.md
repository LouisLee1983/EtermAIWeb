# EtermAIWeb - 机票代理自动化云平台

## 项目简介

EtermAIWeb是一个为机票代理行业提供基于Eterm白屏破解的自动化操作云平台。系统通过云端统一调度和管理全国各地的终端PC，实现机票业务的自动化处理、任务分发、权限管理和计费结算。

## 主要功能

- 🖥️ **终端管理** - 统一管理全国各地的终端PC，实时监控终端状态
- 📋 **任务调度** - 智能分配和调度Eterm自动化任务  
- 👥 **权限管理** - 多角色权限管理（超级管理员、普通管理员、普通用户）
- 💰 **计费系统** - 精确的使用计费和统计功能
- 🔌 **API接口** - 开放的RESTful API接口，支持第三方集成
- 💬 **实时交互** - 支持文字和语音输入的任务交互页面

## 技术栈

- **后端**: Python 3.10 + Flask
- **前端**: Vue3.js + Tailwind CSS (Apple Design风格)  
- **数据库**: PostgreSQL
- **架构**: 云端统一调度 + 分布式终端执行

## 支持的Eterm操作

- 查询航班 (AV)
- 预定PNR
- 提取PNR内容
- 取消PNR中的某个乘机人
- 取消某个PNR
- PNR出票
- 提取票号
- PNR授权

## 快速开始

### 🐳 Docker部署 (推荐)

```bash
# 克隆项目
git clone https://github.com/LouisLee1983/EtermAIWeb.git
cd EtermAIWeb

# 启动所有服务 (包含Nginx、Flask、PostgreSQL、Redis)
docker-compose up -d --build

# 访问应用
http://localhost:5000
```

### 🛠️ 传统部署

```bash
# 克隆项目
git clone https://github.com/LouisLee1983/EtermAIWeb.git
cd EtermAIWeb

# 安装依赖
pip install -r requirements.txt

# 配置数据库
createdb etermaiweb
python manage.py db upgrade

# 启动服务
python app.py
```

## 🚀 自动部署

本项目支持Docker容器化部署，已配置GitHub Actions自动部署到云服务器47.111.119.238：

- **Docker部署**: 查看 [Docker部署指南](docs/Docker部署指南.md) (推荐)
- **传统部署**: 查看 [快速部署指南](docs/快速部署指南.md)
- **详细配置**: 查看 [GitHub自动部署配置文档](docs/GitHub自动部署配置文档.md)

### 🐳 Docker优势
- ✅ 环境一致性 - 开发、测试、生产环境完全一致
- ✅ 快速部署 - 一键启动所有服务
- ✅ 服务隔离 - 每个服务运行在独立容器中
- ✅ 易于扩展 - 支持水平扩展和负载均衡
- ✅ 便于维护 - 统一的容器管理和监控

每当代码合并到main分支时，系统会自动使用Docker部署到生产服务器。

## 📚 项目文档

详细的项目文档位于 `docs/` 目录：

### 📋 产品文档
- [项目需求说明](docs/项目需求说明.md)
- [数据库设计概要](docs/数据库设计概要.md)
- [接口设计概要](docs/接口设计概要.md)
- [角色与权限设计](docs/角色与权限设计.md)

### 🚀 部署文档
- [Docker部署指南](docs/Docker部署指南.md) ⭐ 推荐
- [快速部署指南](docs/快速部署指南.md)
- [GitHub自动部署配置文档](docs/GitHub自动部署配置文档.md)

测试同步202506162115
测试同步2