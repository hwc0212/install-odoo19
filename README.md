# Odoo 19 生产环境一键部署脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)](https://ubuntu.com/)
[![Odoo](https://img.shields.io/badge/Odoo-19-purple.svg)](https://www.odoo.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)

> 🚀 **一键部署 Odoo 19 生产环境**，支持管理系统和网站双模式，专为 Ubuntu 24.04 LTS 优化，完美支持 WSL 环境

## ✨ 核心特性

- 🔒 **生产级安全** - 多层安全防护，防火墙，入侵检测
- 🚀 **性能优化** - 系统调优，数据库优化，智能缓存
- 🎯 **双模式支持** - 管理系统模式 + 网站模式
- 🐳 **容器化部署** - Docker Compose 编排，易于管理
- 🛡️ **自动化配置** - Nginx 反向代理，SSL 证书，自动备份
- 📊 **智能资源分配** - 根据服务器配置自动计算最优参数
- 💻 **WSL 完美支持** - 自动检测并适配 WSL 环境

## 📋 系统要求

### 支持的操作系统
- **Ubuntu 24.04 LTS** (推荐)
- **Ubuntu 22.04 LTS**
- **Ubuntu 20.04 LTS**
- **WSL2 (Ubuntu 24.04/22.04/20.04)**

### 最低配置
- **CPU**: 2 核心
- **内存**: 4GB RAM
- **存储**: 20GB 可用空间

### 推荐配置
- **CPU**: 4 核心或更多
- **内存**: 8GB RAM 或更多
- **存储**: SSD 硬盘，50GB+ 可用空间

## 🚀 快速开始

### 1. 下载并运行脚本

```bash
# 下载脚本
wget https://raw.githubusercontent.com/hwc0212/install-odoo19/main/install-odoo19.sh

# 添加执行权限
chmod +x install-odoo19.sh

# 运行脚本（不要使用 root 用户）
./install-odoo19.sh
```

### 2. 按提示配置

脚本会自动识别部署模式：

| 输入 | 部署模式 | 说明 |
|------|---------|------|
| 直接回车 | IP访问模式 | 通过IP访问，管理系统模式 |
| 二级域名（如 `erp.example.com`） | 管理系统模式 | 严格安全控制，屏蔽搜索引擎 |
| 主域名（如 `example.com`） | 网站模式 | SEO友好，允许搜索引擎收录 |

**配置示例**：
```
请输入域名（直接回车使用IP访问）: [直接回车或输入域名]
请输入数据库密码: [输入强密码]
请输入Odoo管理员密码: [输入强密码]
```

### 3. 等待部署完成

脚本会自动完成：
- ✅ 系统优化和安全配置
- ✅ Docker 环境安装
- ✅ Odoo、PostgreSQL、Redis 容器部署
- ✅ Nginx 反向代理配置
- ✅ SSL 证书生成
- ✅ 防火墙和入侵防护设置（非WSL环境）
- ✅ 自动备份任务配置

## 🔧 部署后配置

### 首次访问

1. **访问 Odoo**：
   ```
   IP访问模式: https://your-server-ip
   管理系统模式: https://erp.your-domain.com
   网站模式: https://www.your-domain.com
   ```

2. **创建数据库**：
   - 首次访问会看到数据库创建页面
   - 输入数据库名称（建议使用字母和数字，避免特殊字符）
   - 输入管理员邮箱和密码
   - 选择语言和国家
   - 点击"创建数据库"

3. **安全配置**（重要）：
   
   创建数据库后，**立即**执行以下步骤锁定数据库：
   
   ```bash
   # 编辑配置文件
   sudo nano /opt/odoo/config/odoo.conf
   
   # 找到 list_db = True 这一行，修改为：
   list_db = False
   
   # 添加数据库过滤器（替换 your_database_name 为你的数据库名）
   dbfilter = ^your_database_name$
   
   # 保存并退出（Ctrl+O, Enter, Ctrl+X）
   
   # 重启 Odoo 容器
   cd /opt/odoo && docker compose restart odoo
   ```

### SSL 证书配置

**IP访问模式和管理系统模式**：
- 脚本已自动生成自签名证书
- 浏览器会提示"不安全"，点击"高级" → "继续访问"即可
- 这对于内网或开发环境是正常的

**网站模式需要申请 Let's Encrypt 证书**：
```bash
# 确保域名已解析到服务器IP
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# WSL 环境重启 Nginx
sudo service nginx reload

# 非 WSL 环境重启 Nginx
sudo systemctl reload nginx
```

## 💻 WSL 特别说明

脚本已完美适配 WSL 环境，自动处理以下差异：

### WSL 自动适配
- ✅ 使用 `service` 命令替代 `systemctl`
- ✅ 跳过不支持的内核参数优化
- ✅ 跳过 UFW 防火墙配置（使用 Windows 防火墙）
- ✅ 跳过 Fail2Ban 配置
- ✅ 正确处理文件权限

### WSL 使用建议
1. **Windows 防火墙**：在 Windows 中配置防火墙规则
2. **Docker Desktop**：确保 Docker Desktop 已启动
3. **访问地址**：使用 WSL IP 地址访问（脚本会自动显示）

## 📚 详细文档

本 README 提供快速入门指南。更多详细信息，请查看：

📖 **[完整部署指南 (DEPLOYMENT_GUIDE.md)](./DEPLOYMENT_GUIDE.md)**

包含以下详细内容：
- 系统初始化与安全配置
- Docker 环境安装与优化
- Odoo 服务部署与资源配置
- Nginx 反向代理与性能优化
- SSL 证书配置与自动更新
- 安全加固与防护策略
- Cloudflare 集成与 CDN 优化
- Odoo 系统内优化（20+ 项）
- 数据备份与恢复
- 日志分析与问题诊断
- 常用运维命令速查

## 📝 常用命令

### 容器管理
```bash
# 查看容器状态
docker ps

# 查看日志
docker logs -f odoo
docker logs -f odoo-db
docker logs -f odoo-redis

# 重启服务
cd /opt/odoo && docker compose restart odoo

# 停止所有服务
cd /opt/odoo && docker compose down

# 启动所有服务
cd /opt/odoo && docker compose up -d
```

### 系统监控
```bash
# 查看容器资源使用
docker stats

# 查看系统资源
htop
free -h
df -h

# 查看 Nginx 日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 备份恢复
```bash
# 手动执行备份
/opt/odoo/scripts/backup.sh

# 查看备份文件
ls -lh /opt/odoo/backups/

# 数据库恢复
docker exec odoo-db pg_restore -U odoo -d odoo < backup.dump

# 文件恢复
tar -xzf odoo_filestore_backup.tar.gz -C /opt/odoo/
```

### 配置修改
```bash
# 编辑 Odoo 配置
sudo nano /opt/odoo/config/odoo.conf

# 编辑 Nginx 配置
sudo nano /etc/nginx/sites-enabled/odoo-admin.conf  # 或 odoo-site.conf

# 重启服务使配置生效
cd /opt/odoo && docker compose restart odoo

# WSL 重启 Nginx
sudo service nginx restart

# 非 WSL 重启 Nginx
sudo systemctl restart nginx
```

## 🔍 故障排除

### 常见问题

**1. 容器启动失败**：
```bash
# 查看详细日志
docker compose -f /opt/odoo/docker-compose.yml logs

# 重新创建容器
cd /opt/odoo
docker compose down
docker compose up -d
```

**2. 无法访问网站（502/503错误）**：
```bash
# 检查容器状态
docker ps

# 检查 Odoo 日志
docker logs odoo --tail 50

# 检查端口监听
ss -tlnp | grep 8069

# 重启 Nginx
sudo service nginx restart  # WSL
sudo systemctl restart nginx  # 非 WSL
```

**3. 数据库连接失败**：
```bash
# 检查数据库容器
docker logs odoo-db

# 测试数据库连接
docker exec odoo-db pg_isready -U odoo

# 检查配置文件中的密码
cat /opt/odoo/config/odoo.conf | grep db_password
```

**4. 权限错误（Permission denied）**：
```bash
# 修复目录权限
sudo chown -R 101:101 /opt/odoo/data
sudo chmod -R 755 /opt/odoo/data

# 重启容器
cd /opt/odoo && docker compose restart odoo
```

**5. SSL 证书警告**：
- IP访问模式使用自签名证书是正常的
- 点击浏览器的"高级" → "继续访问"
- 或者为域名申请 Let's Encrypt 证书

**更多问题排查**：请查看 [DEPLOYMENT_GUIDE.md 第九部分](./DEPLOYMENT_GUIDE.md#第九部分日志分析与问题诊断)

## ⚠️ 重要提醒

### 安全建议
1. **立即更改默认密码**：部署完成后立即更改所有默认密码
2. **锁定数据库**：创建数据库后立即配置 `dbfilter`
3. **定期备份**：建立定期备份机制，数据无价
4. **监控日志**：定期检查系统和应用日志
5. **及时更新**：保持系统和应用程序最新版本

### 生产环境检查清单
- [ ] 已更改所有默认密码
- [ ] 已配置 `dbfilter` 锁定数据库
- [ ] 已设置 `list_db = False`
- [ ] 已配置 SSL 证书（网站模式）
- [ ] 已测试自动备份功能
- [ ] 已配置防火墙规则
- [ ] 已设置监控告警

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

### 如何贡献
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 👨‍💻 作者

**huwencai.com**
- 网站: [huwencai.com](https://huwencai.com)
- GitHub: [@hwc0212](https://github.com/hwc0212)

## 🙏 致谢

感谢以下开源项目：
- [Odoo](https://www.odoo.com/) - 优秀的开源 ERP 系统
- [PostgreSQL](https://www.postgresql.org/) - 强大的开源数据库
- [Redis](https://redis.io/) - 高性能缓存系统
- [Nginx](https://nginx.org/) - 高性能 Web 服务器
- [Docker](https://www.docker.com/) - 容器化平台

## 📊 更新日志

### v2.0.0 (2026-02-02)
- ✨ 新增 WSL 环境完美支持
- ✨ 移除 docker-compose.yml 中过时的 version 字段
- 🔧 优化数据库管理界面访问控制
- 🔧 改进爬虫检测规则，避免误拦截
- 🐛 修复目录权限问题
- 🐛 修复端口映射配置
- 📝 更新文档，增加 WSL 使用说明

### v1.0.0 (2026-01-14)
- 🎉 首次发布
- ✨ 支持 Ubuntu 24.04 LTS
- ✨ 双模式部署（管理系统/网站）
- ✨ 自动化配置和优化

---

**快速链接**：
- 📖 [完整部署指南](./DEPLOYMENT_GUIDE.md)
- 🐛 [问题反馈](https://github.com/hwc0212/install-odoo19/issues)
- 💬 [作者博客](https://huwencai.com)
