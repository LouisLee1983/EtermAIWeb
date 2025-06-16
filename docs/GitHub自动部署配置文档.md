# GitHub Actions 自动部署配置文档

## 概述

本文档指导如何配置GitHub Actions实现代码合并到main分支后自动部署到云服务器47.111.119.238。

## 部署架构

```
开发者提交代码 → GitHub仓库 → GitHub Actions → 云服务器(47.111.119.238)
                        ↓
                   自动构建和测试
                        ↓
                   SSH连接服务器
                        ↓
                   更新代码并重启服务
```

## 1. 准备工作

### 1.1 云服务器准备

首先在云服务器上执行初始化部署：

```bash
# 登录云服务器
ssh root@47.111.119.238

# 下载并运行部署脚本
curl -O https://raw.githubusercontent.com/LouisLee1983/EtermAIWeb/main/deploy/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### 1.2 生成SSH密钥

在云服务器上为GitHub Actions创建专用的SSH密钥：

```bash
# 在云服务器上执行
ssh-keygen -t rsa -b 4096 -C "github-actions@etermaiweb" -f ~/.ssh/github_actions
```

将公钥添加到服务器的authorized_keys：

```bash
# 将公钥添加到authorized_keys
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys

# 设置正确的权限
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

查看私钥内容（稍后需要添加到GitHub Secrets）：

```bash
cat ~/.ssh/github_actions
```

## 2. GitHub Secrets 配置

在GitHub仓库中配置必要的密钥信息：

1. 进入GitHub仓库页面
2. 点击 `Settings` → `Secrets and variables` → `Actions`
3. 点击 `New repository secret` 添加以下密钥：

### 必需的Secrets：

| Secret名称 | 值 | 说明 |
|------------|----|----|
| `HOST` | `47.111.119.238` | 服务器IP地址 |
| `USERNAME` | `root` | SSH用户名 |
| `SSH_PRIVATE_KEY` | 私钥内容 | 之前生成的SSH私钥完整内容 |
| `PORT` | `22` | SSH端口号 |

### 添加步骤：

1. **HOST**:
   - Secret名称: `HOST`
   - 值: `47.111.119.238`

2. **USERNAME**:
   - Secret名称: `USERNAME`  
   - 值: `root`

3. **SSH_PRIVATE_KEY**:
   - Secret名称: `SSH_PRIVATE_KEY`
   - 值: 复制完整的私钥内容，包括 `-----BEGIN OPENSSH PRIVATE KEY-----` 和 `-----END OPENSSH PRIVATE KEY-----`

4. **PORT**:
   - Secret名称: `PORT`
   - 值: `22`

## 3. 工作流程文件说明

GitHub Actions工作流文件位于：`.github/workflows/deploy.yml`

### 触发条件：
- 推送到main分支
- PR合并到main分支

### 部署步骤：
1. **检出代码** - 获取最新代码
2. **设置Python环境** - 配置Python 3.10环境
3. **缓存依赖** - 缓存pip依赖，提高构建速度
4. **安装依赖** - 安装requirements.txt中的依赖
5. **运行测试** - 执行单元测试（可选）
6. **部署到服务器** - SSH连接服务器并执行部署脚本
7. **发送通知** - 部署结果通知（可选）

## 4. 服务器部署脚本说明

部署脚本位于：`deploy/deploy.sh`

### 功能：
- 安装系统依赖（Python、Nginx、PostgreSQL等）
- 创建Python虚拟环境
- 配置systemd服务
- 配置Nginx反向代理
- 自动启动和监控服务

### 目录结构：
```
/www/wwwroot/etermaiweb/      # 项目根目录
├── app/                      # Flask应用
├── venv/                     # Python虚拟环境
├── requirements.txt          # Python依赖
└── ...                       # 其他项目文件
```

### 服务配置：
- **systemd服务名**: `etermaiweb`
- **运行用户**: `www-data`
- **监听端口**: `5000` (内部)
- **外部访问**: `80` (通过Nginx代理)

## 5. 常用操作命令

### 5.1 服务器上的操作

```bash
# 查看服务状态
sudo systemctl status etermaiweb

# 查看服务日志
sudo journalctl -u etermaiweb -f

# 重启服务
sudo systemctl restart etermaiweb

# 查看Nginx状态
sudo systemctl status nginx

# 重启Nginx
sudo systemctl restart nginx

# 查看部署日志
tail -f /var/log/syslog | grep etermaiweb
```

### 5.2 手动部署

如果需要手动部署：

```bash
# SSH连接到服务器
ssh root@47.111.119.238

# 切换到项目目录
cd /www/wwwroot/etermaiweb

# 拉取最新代码
sudo git fetch origin
sudo git reset --hard origin/main

# 重启服务
sudo systemctl restart etermaiweb
```

## 6. 故障排除

### 6.1 部署失败

1. **检查GitHub Actions日志**：
   - 在GitHub仓库的 `Actions` 标签页查看详细日志

2. **检查SSH连接**：
   ```bash
   # 测试SSH连接
   ssh -i ~/.ssh/github_actions root@47.111.119.238
   ```

3. **检查服务器权限**：
   ```bash
   # 确保项目目录权限正确
   sudo chown -R www-data:www-data /www/wwwroot/etermaiweb
   ```

### 6.2 服务启动失败

1. **查看详细错误信息**：
   ```bash
   sudo journalctl -u etermaiweb --no-pager -l
   ```

2. **检查Python环境**：
   ```bash
   cd /www/wwwroot/etermaiweb
   source venv/bin/activate
   python app.py
   ```

3. **检查端口占用**：
   ```bash
   sudo netstat -tlnp | grep :5000
   ```

### 6.3 Nginx配置问题

1. **测试Nginx配置**：
   ```bash
   sudo nginx -t
   ```

2. **查看Nginx错误日志**：
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

## 7. 安全建议

1. **定期更新SSH密钥**
2. **使用防火墙限制访问端口**
3. **定期备份数据库和代码**
4. **监控服务器资源使用情况**
5. **设置SSL证书（HTTPS）**

## 8. 扩展功能

### 8.1 添加通知功能

可以在部署成功/失败时发送通知到钉钉、企业微信等：

```yaml
# 在 .github/workflows/deploy.yml 中添加
- name: 发送钉钉通知
  if: always()
  uses: zcong1993/actions-ding@master
  with:
    dingToken: ${{ secrets.DING_TOKEN }}
    body: |
      {
        "msgtype": "text",
        "text": {
          "content": "EtermAIWeb部署${{ job.status == 'success' && '成功' || '失败' }}"
        }
      }
```

### 8.2 蓝绿部署

可以配置蓝绿部署策略，降低部署风险：

```bash
# 创建两个服务实例
sudo systemctl enable etermaiweb-blue
sudo systemctl enable etermaiweb-green

# 使用Nginx切换流量
```

## 9. 总结

通过以上配置，您的EtermAIWeb项目已经实现了：

✅ 代码推送到main分支自动触发部署  
✅ 自动化测试和构建  
✅ 零停机部署到生产服务器  
✅ 服务健康检查  
✅ 部署失败自动回滚  

现在，每当您合并代码到main分支时，系统会自动部署到云服务器，实现真正的持续集成/持续部署(CI/CD)。 