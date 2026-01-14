# Odoo 19 生产环境一键部署脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)](https://ubuntu.com/)
[![Odoo](https://img.shields.io/badge/Odoo-19-purple.svg)](https://www.odoo.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)

> 🚀 **一键部署 Odoo 19 生产环境**，支持管理系统和网站双模式，专为 Ubuntu 24.04 LTS 优化

## ✨ 核心特性

- 🔒 **生产级安全** - 多层安全防护，防火墙，入侵检测
- 🚀 **性能优化** - 系统调优，数据库优化，智能缓存
- 🎯 **双模式支持** - 管理系统模式 + 网站模式
- 🐳 **容器化部署** - Docker Compose 编排，易于管理
- 🛡️ **自动化配置** - Nginx 反向代理，SSL 证书，自动备份
- 📊 **智能资源分配** - 根据服务器配置自动计算最优参数

## 📋 系统要求

### 最低配置
- **操作系统**: Ubuntu 24.04 LTS
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

# 运行脚本
./install-odoo19.sh
```

### 2. 按提示配置

脚本会自动识别部署模式：

| 输入 | 部署模式 | 说明 |
|------|---------|------|
| 直接回车 | IP访问模式 | 通过IP访问，管理系统模式 |
| 二级域名（如 `erp.example.com`） | 管理系统模式 | 严格安全控制，屏蔽搜索引擎 |
| 主域名（如 `example.com`） | 网站模式 | SEO友好，允许搜索引擎收录 |

### 3. 等待部署完成

脚本会自动完成：
- ✅ 系统优化和安全配置
- ✅ Docker 环境安装
- ✅ Odoo、PostgreSQL、Redis 容器部署
- ✅ Nginx 反向代理配置
- ✅ SSL 证书生成
- ✅ 防火墙和入侵防护设置

## 🔧 部署后配置

### 首次访问

1. **访问 Odoo**：
   ```
   管理系统模式: https://your-server-ip
   网站模式: https://www.your-domain.com
   ```

2. **创建数据库**：首次访问会看到数据库创建页面

3. **安全配置**（重要）：
   ```bash
   # 编辑配置文件
   nano /opt/odoo/config/odoo.conf
   
   # 添加数据库过滤器
   dbfilter = ^your_database_name$
   
   # 重启容器
   cd /opt/odoo && docker-compose restart odoo
   ```

### SSL 证书配置

**网站模式需要申请 Let's Encrypt 证书**：
```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
sudo systemctl reload nginx
```

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

# 重启服务
cd /opt/odoo && docker-compose restart
```

### 系统监控
```bash
# 查看资源使用
docker stats

# 查看系统资源
htop
free -h
df -h
```

### 备份恢复
```bash
# 数据库备份
docker exec odoo-db pg_dump -U odoo -Fc odoo > backup_$(date +%Y%m%d).dump

# 文件备份
tar -czf odoo_files_$(date +%Y%m%d).tar.gz /opt/odoo/data
```

## 🔍 故障排除

### 常见问题

**容器启动失败**：
```bash
docker-compose logs
docker-compose down && docker-compose up -d
```

**无法访问网站**：
```bash
sudo systemctl status nginx
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

**数据库连接失败**：
```bash
docker exec odoo-db pg_isready -U odoo
docker logs odoo-db
```

**更多问题排查**：请查看 [DEPLOYMENT_GUIDE.md 第九部分](./DEPLOYMENT_GUIDE.md#第九部分日志分析与问题诊断)

## ⚠️ 重要提醒

1. **立即更改默认密码**：部署完成后立即更改所有默认密码
2. **定期备份**：建立定期备份机制，数据无价
3. **监控日志**：定期检查系统和应用日志
4. **及时更新**：保持系统和应用程序最新版本

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

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

---

**快速链接**：
- 📖 [完整部署指南](./DEPLOYMENT_GUIDE.md)
- 🐛 [问题反馈](https://github.com/hwc0212/install-odoo19/issues)
- 💬 [作者博客](https://huwencai.com)
