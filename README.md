# Odoo 19 生产环境一键部署脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)](https://ubuntu.com/)
[![Odoo](https://img.shields.io/badge/Odoo-19-purple.svg)](https://www.odoo.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)

> 🚀 **一键部署 Odoo 19 生产环境**，支持管理系统和网站双模式，专为 Ubuntu 24.04 LTS 优化

## ✨ 特性

- 🔒 **生产级安全配置** - 多层安全防护，符合企业安全标准
- 🚀 **性能优化** - 系统级调优，数据库优化，缓存策略
- 🎯 **双模式支持** - 管理系统模式 + 网站模式，灵活选择
- 🐳 **容器化部署** - Docker Compose 编排，易于管理和扩展
- 🛡️ **自动化配置** - Nginx 反向代理，SSL 证书，防火墙设置
- 📊 **资源智能分配** - 根据服务器配置自动计算最优参数
- 🔧 **一键部署** - 全自动化安装，小白也能轻松部署

## 🏗️ 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    网络边界层（可选）                          │
│                     Cloudflare CDN                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────────┐
│                    宿主机层                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Nginx     │  │    UFW      │  │     Fail2Ban        │  │
│  │ 反向代理     │  │   防火墙     │  │   入侵防护          │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────────┐
│                   容器层                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    Odoo     │  │ PostgreSQL  │  │       Redis         │  │
│  │   业务逻辑   │  │  数据存储    │  │   会话/缓存         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 📋 系统要求

### 最低配置
- **操作系统**: Ubuntu 24.04 LTS
- **CPU**: 2 核心
- **内存**: 4GB RAM
- **存储**: 20GB 可用空间
- **网络**: 公网 IP（如需域名访问）

### 推荐配置
- **CPU**: 4 核心或更多
- **内存**: 8GB RAM 或更多
- **存储**: SSD 硬盘，50GB+ 可用空间

## 🚀 快速开始

### 1. 准备工作

确保您有一个 Ubuntu 24.04 LTS 服务器，并且：

- ✅ 已创建非 root 用户并配置 sudo 权限
- ✅ 已配置 SSH 密钥登录（推荐）
- ✅ 服务器可以访问互联网
- ✅ 如需域名访问，请提前配置 DNS 解析

### 2. 下载并运行脚本

```bash
# 下载脚本
wget https://raw.githubusercontent.com/hwc0212/install-odoo19/main/install-odoo19.sh

# 添加执行权限
chmod +x install-odoo19.sh

# 运行脚本
./install-odoo19.sh
```

### 3. 按提示配置

脚本会引导您完成以下配置：

1. **域名配置**（智能模式识别）：
   - 直接回车 → IP访问模式（管理系统）
   - 输入二级域名（如 `erp.example.com`）→ 管理系统模式
   - 输入主域名（如 `example.com` 或 `www.example.com`）→ 网站模式

2. **设置数据库密码和管理员密码**

3. **自动检测并配置系统资源**

### 4. 等待部署完成

脚本会自动完成：
- 系统优化和安全配置
- Docker 环境安装
- Odoo、PostgreSQL、Redis 容器部署
- Nginx 反向代理配置
- SSL 证书生成
- 防火墙和入侵防护设置

## 🎯 部署模式说明

### 智能模式识别

脚本会根据您输入的域名自动识别部署模式：

#### IP访问模式（管理系统）
- **输入**: 直接回车，不输入域名
- **访问方式**: 通过服务器IP地址访问
- **特性**: 管理系统模式，严格安全控制，屏蔽搜索引擎
- **适用场景**: 内部管理，注重安全性

#### 管理系统模式
- **输入**: 二级域名（如 `erp.example.com`、`crm.example.com`）
- **访问方式**: 通过管理专用域名访问
- **特性**: 管理系统模式，严格安全控制，屏蔽搜索引擎
- **适用场景**: 企业内部管理系统

#### 网站模式
- **输入**: 主域名（如 `example.com` 或 `www.example.com`）
- **访问方式**: 通过公开域名访问，智能处理域名跳转
- **特性**: SEO友好，允许搜索引擎收录
- **域名处理**: 
  - 输入 `example.com` → 默认访问 `example.com`，`www.example.com` 跳转到 `example.com`
  - 输入 `www.example.com` → 默认访问 `www.example.com`，`example.com` 跳转到 `www.example.com`
- **适用场景**: 企业官网，电商网站

## 🔧 部署后配置

### 首次访问设置

1. **访问 Odoo**：
   ```bash
   # 管理系统模式
   https://your-server-ip
   
   # 网站模式  
   https://www.your-domain.com
   ```

2. **创建数据库**：
   - 首次访问会看到数据库创建页面
   - 设置数据库名称和管理员信息
   - **重要**: 创建完成后立即进行安全配置

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

**管理系统模式**: 脚本已自动生成自签名证书

**网站模式**: 需要申请 Let's Encrypt 证书
```bash
# 申请免费 SSL 证书
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# 重启 Nginx
sudo systemctl reload nginx
```

## 📊 性能优化

### 自动优化项目

脚本已自动完成以下优化：

- ✅ **系统级优化**: 文件句柄限制，网络参数，BBR 拥塞控制
- ✅ **数据库优化**: 连接池，缓冲区，查询优化
- ✅ **缓存策略**: Redis 会话管理，Nginx 静态资源缓存
- ✅ **资源分配**: 根据服务器配置自动计算最优参数

### 手动优化建议

1. **监控资源使用**：
   ```bash
   # 查看容器资源使用
   docker stats
   
   # 查看系统资源
   htop
   ```

2. **数据库维护**：
   ```bash
   # 数据库性能分析
   docker exec odoo-db psql -U odoo -c "SELECT * FROM pg_stat_activity;"
   
   # 重建索引（定期执行）
   docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"
   ```

## 🛡️ 安全配置

### 自动安全配置

- ✅ **防火墙**: 只开放必要端口（80, 443, SSH）
- ✅ **入侵防护**: Fail2Ban 防暴力破解
- ✅ **访问控制**: 数据库管理界面限制
- ✅ **SSL 加密**: 强制 HTTPS 访问
- ✅ **安全头**: 防 XSS，点击劫持等攻击

### 额外安全建议

1. **定期更新**：
   ```bash
   # 更新系统
   sudo apt update && sudo apt upgrade
   
   # 更新容器镜像
   cd /opt/odoo && docker-compose pull && docker-compose up -d
   ```

2. **备份策略**：
   ```bash
   # 数据库备份
   docker exec odoo-db pg_dump -U odoo > backup_$(date +%Y%m%d).sql
   
   # 文件备份
   tar -czf odoo_files_$(date +%Y%m%d).tar.gz /opt/odoo/data
   ```

3. **监控日志**：
   ```bash
   # 查看 Odoo 日志
   docker logs odoo --tail 100
   
   # 查看 Nginx 日志
   sudo tail -f /var/log/nginx/access.log
   
   # 查看 Fail2Ban 日志
   sudo fail2ban-client status
   ```

## 🔧 高级优化配置

脚本已经完成了基础的生产环境配置，以下是一些高级优化选项，需要根据实际需求手动配置。

### 数据库高级优化

#### PostgreSQL 查询优化

```bash
# 进入数据库容器
docker exec -it odoo-db psql -U odoo

# 创建常用索引（提升查询性能）
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_res_partner_name ON res_partner(name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_res_partner_email ON res_partner(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_template_name ON product_template(name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_move_date ON account_move(date);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sale_order_date_order ON sale_order(date_order);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_purchase_order_date_order ON purchase_order(date_order);

# 启用查询统计扩展
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

# 分析数据库统计信息
ANALYZE;
```

#### 数据库维护脚本

创建定期维护脚本：

```bash
# 创建维护脚本
sudo nano /opt/odoo/scripts/db_maintenance.sh
```

```bash
#!/bin/bash
# 数据库维护脚本

echo "开始数据库维护 - $(date)"

# 重建索引
docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"

# 更新统计信息
docker exec odoo-db psql -U odoo -c "ANALYZE;"

# 清理死元组
docker exec odoo-db psql -U odoo -c "VACUUM ANALYZE;"

# 检查数据库大小
docker exec odoo-db psql -U odoo -c "
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
WHERE datname = 'odoo';"

echo "数据库维护完成 - $(date)"
```

```bash
# 设置执行权限
chmod +x /opt/odoo/scripts/db_maintenance.sh

# 添加到定时任务（每周执行）
echo "0 2 * * 0 /opt/odoo/scripts/db_maintenance.sh >> /var/log/odoo_maintenance.log 2>&1" | sudo crontab -
```

### Nginx 高级优化

#### 根据部署模式选择优化策略

**管理系统模式优化**：

```bash
# 编辑管理系统配置
sudo nano /etc/nginx/sites-available/odoo-admin.conf
```

在 `server` 块中添加：

```nginx
server {
    listen 443 ssl http2;
    server_name your-admin-domain;
    
    # 管理系统：只缓存静态文件
    location ~* ^/web/static/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 管理系统：禁止缓存动态内容
    location / {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }
    
    # 管理系统：严格的安全头
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
}
```

**网站模式优化**：

```bash
# 编辑网站配置
sudo nano /etc/nginx/sites-available/odoo-site.conf
```

在 `server` 块中添加：

```nginx
server {
    listen 443 ssl http2;
    server_name www.example.com;
    
    # 网站：缓存静态资源
    location ~* ^/(web|website)/static/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
        access_log off;
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 网站：缓存前端页面（短期）
    location ~* ^/(shop|blog|contactus|aboutus)$ {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
        add_header Vary "Accept-Encoding";
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
        
        # 启用 Nginx 缓存
        proxy_cache odoo_cache;
        proxy_cache_valid 200 5m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_bypass $cookie_session_id;
    }
    
    # 网站：后台和用户相关页面不缓存
    location ~* ^/(web|my|shop/checkout|shop/cart) {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }
    
    # 网站：默认位置
    location / {
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }
    
    # 网站：SEO友好的安全头
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Robots-Tag "index, follow" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

#### 启用 Brotli 压缩

```bash
# 安装 Brotli 模块
sudo apt install -y nginx-module-brotli

# 编辑 Nginx 主配置
sudo nano /etc/nginx/nginx.conf
```

在 `http` 块中添加：

```nginx
# 加载 Brotli 模块
load_module modules/ngx_http_brotli_filter_module.so;
load_module modules/ngx_http_brotli_static_module.so;

http {
    # Brotli 压缩配置
    brotli on;
    brotli_comp_level 6;
    brotli_types
        text/plain
        text/css
        application/json
        application/javascript
        text/xml
        application/xml
        application/xml+rss
        text/javascript
        image/svg+xml;
}
```

#### 启用 HTTP/3 (QUIC)

```bash
# 检查 Nginx 是否支持 HTTP/3
nginx -V 2>&1 | grep -o with-http_v3_module

# 如果支持，在站点配置中添加
sudo nano /etc/nginx/sites-available/odoo-site.conf
```

在 `server` 块中添加：

```nginx
listen 443 quic reuseport;
listen 443 ssl http2;

# 添加 HTTP/3 头部
add_header Alt-Svc 'h3=":443"; ma=86400';
```

#### Nginx 缓存优化

```bash
# 创建缓存目录
sudo mkdir -p /var/cache/nginx/odoo
sudo chown -R www-data:www-data /var/cache/nginx/odoo

# 编辑 Nginx 主配置
sudo nano /etc/nginx/nginx.conf
```

在 `http` 块中添加：

```nginx
# 缓存配置
proxy_cache_path /var/cache/nginx/odoo 
    levels=1:2 
    keys_zone=odoo_cache:100m 
    max_size=1g 
    inactive=60m 
    use_temp_path=off;

# 限流配置
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
```

### Redis 高级配置

#### Redis 持久化优化

```bash
# 编辑 Redis 配置
nano /opt/odoo/config/redis.conf
```

添加以下优化配置：

```ini
# 内存优化
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64

# 持久化优化
save 900 1
save 300 10
save 60 10000

# AOF 配置
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# 慢查询日志
slowlog-log-slower-than 10000
slowlog-max-len 128
```

### 系统监控配置

#### 安装监控工具

```bash
# 安装系统监控工具
sudo apt install -y htop iotop nethogs

# 安装 Docker 监控
sudo apt install -y docker-compose-plugin
```

#### 创建监控脚本

```bash
# 创建监控脚本
sudo nano /opt/odoo/scripts/monitor.sh
```

```bash
#!/bin/bash
# 系统监控脚本

echo "=== Odoo 系统监控报告 $(date) ==="

# 系统资源
echo "1. 系统资源使用:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "内存: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "磁盘: $(df -h / | awk 'NR==2 {print $5}')"

# Docker 容器状态
echo -e "\n2. 容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 容器资源使用
echo -e "\n3. 容器资源使用:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# 数据库连接数
echo -e "\n4. 数据库连接:"
docker exec odoo-db psql -U odoo -c "SELECT count(*) as connections FROM pg_stat_activity;" 2>/dev/null || echo "无法连接数据库"

# Redis 状态
echo -e "\n5. Redis 状态:"
docker exec odoo-redis redis-cli info stats | grep -E "keyspace_hits|keyspace_misses|used_memory_human" 2>/dev/null || echo "无法连接Redis"

# 磁盘空间检查
echo -e "\n6. 磁盘空间:"
du -sh /opt/odoo/* | sort -hr

echo -e "\n监控完成 - $(date)"
```

```bash
# 设置执行权限
chmod +x /opt/odoo/scripts/monitor.sh

# 添加到定时任务（每小时执行）
echo "0 * * * * /opt/odoo/scripts/monitor.sh >> /var/log/odoo_monitor.log 2>&1" | sudo crontab -
```

### 备份自动化

#### 创建自动备份脚本

```bash
# 创建备份目录
sudo mkdir -p /opt/odoo/backups
sudo chown $USER:$USER /opt/odoo/backups

# 创建备份脚本
nano /opt/odoo/scripts/backup.sh
```

```bash
#!/bin/bash
# Odoo 自动备份脚本

BACKUP_DIR="/opt/odoo/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

echo "开始备份 - $(date)"

# 数据库备份
echo "备份数据库..."
docker exec odoo-db pg_dump -U odoo -Fc odoo > "$BACKUP_DIR/odoo_db_$DATE.dump"

# 文件存储备份
echo "备份文件存储..."
tar -czf "$BACKUP_DIR/odoo_files_$DATE.tar.gz" -C /opt/odoo data addons

# 配置文件备份
echo "备份配置文件..."
tar -czf "$BACKUP_DIR/odoo_config_$DATE.tar.gz" -C /opt/odoo config

# 清理旧备份
echo "清理旧备份..."
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# 备份大小统计
echo "备份完成，文件大小:"
ls -lh "$BACKUP_DIR"/*_$DATE.*

echo "备份完成 - $(date)"
```

```bash
# 设置执行权限
chmod +x /opt/odoo/scripts/backup.sh

# 添加到定时任务（每天凌晨2点执行）
echo "0 2 * * * /opt/odoo/scripts/backup.sh >> /var/log/odoo_backup.log 2>&1" | sudo crontab -
```

### SSL 证书自动续期

#### 配置 Certbot 自动续期

```bash
# 测试续期
sudo certbot renew --dry-run

# 创建续期钩子脚本
sudo nano /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

```bash
#!/bin/bash
# SSL 证书续期后重载 Nginx
systemctl reload nginx
echo "$(date): SSL证书已更新，Nginx已重载" >> /var/log/certbot-renewal.log
```

```bash
# 设置执行权限
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

### 安全加固

#### 启用 Fail2Ban 高级规则

```bash
# 创建 Nginx 4xx 错误过滤器
sudo nano /etc/fail2ban/filter.d/nginx-4xx.conf
```

```ini
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*" (404|403|400|401) .*$
ignoreregex =
```

```bash
# 添加 Jail 配置
sudo nano /etc/fail2ban/jail.d/nginx-4xx.conf
```

```ini
[nginx-4xx]
enabled = true
filter = nginx-4xx
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 600
bantime = 3600
action = iptables[name=nginx-4xx, port=http, protocol=tcp]
```

#### 配置日志轮转

```bash
# 创建 Odoo 日志轮转配置
sudo nano /etc/logrotate.d/odoo
```

```
/opt/odoo/data/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker restart odoo > /dev/null 2>&1 || true
    endscript
}
```

### 性能调优

#### Odoo 配置优化

根据实际使用情况调整 `/opt/odoo/config/odoo.conf`：

```ini
# 高并发优化
workers = 17  # CPU核心数 * 2 + 1
max_cron_threads = 2
limit_time_cpu = 60
limit_time_real = 120

# 数据库连接池
db_maxconn = 64

# 内存优化
limit_memory_soft = 2147483648  # 2GB
limit_memory_hard = 2684354560  # 2.5GB

# 会话优化
session_redis = True
redis_host = redis
redis_port = 6379
redis_dbindex = 1

# 文件上传优化
max_file_upload_size = 134217728  # 128MB

# 日志优化
log_level = info
log_rotate = True
log_max_size = 100000000  # 100MB
```

#### 系统内核参数调优

```bash
# 编辑系统参数
sudo nano /etc/sysctl.conf
```

添加以下参数：

```
# 网络优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 文件系统优化
fs.file-max = 2097152
fs.nr_open = 2097152

# 内存管理优化
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
```

```bash
# 应用配置
sudo sysctl -p
```

这些高级配置可以根据实际需求选择性实施，建议在生产环境中逐步测试和部署。

### Cloudflare 集成优化

#### Cloudflare 集成策略

根据部署模式选择不同的Cloudflare策略：

| 部署模式 | 是否使用Cloudflare | 配置重点 |
|----------|-------------------|----------|
| IP访问模式 | ❌ 不适用 | Cloudflare不支持IP代理 |
| 管理系统模式 | ⚠️ 可选 | 安全优先，严格配置 |
| 网站模式 | ✅ 推荐 | 性能和SEO优化 |

#### 网站模式 Cloudflare 配置

**1. DNS 设置**

在 Cloudflare DNS 管理界面配置：

```
类型    名称              内容              代理状态
A      example.com       your-server-ip    🟠 已代理
A      www.example.com   your-server-ip    � 已代理
```

**2. SSL/TLS 配置**

- 加密模式：选择 `完全(严格)`
- 边缘证书：启用 `始终使用HTTPS`
- 源服务器证书：确保服务器有有效的Let's Encrypt证书

**3. 性能优化设置**

```bash
# 在 Cloudflare 仪表板中配置以下设置：

# 速度 > 优化
Auto Minify: ✅ HTML, CSS, JS
Brotli: ✅ 启用
Early Hints: ✅ 启用

# 速度 > 缓存
缓存级别: 标准
浏览器缓存TTL: 4小时
```

**4. 页面规则配置**

创建以下页面规则（按优先级排序）：

```
优先级 1: *.example.com/web/static/*
- 缓存级别: 缓存所有内容
- 边缘缓存TTL: 1个月
- 浏览器缓存TTL: 1年

优先级 2: *.example.com/website/static/*
- 缓存级别: 缓存所有内容
- 边缘缓存TTL: 1个月
- 浏览器缓存TTL: 1年

优先级 3: *.example.com/web/*
- 缓存级别: 绕过缓存
- 禁用性能功能: 关闭

优先级 4: *.example.com/*
- 缓存级别: 标准
- 边缘缓存TTL: 2小时
- 浏览器缓存TTL: 4小时
```

**5. 重要：禁用的功能**

⚠️ **必须禁用以下功能，否则会破坏Odoo：**

```bash
# 速度 > 优化
Rocket Loader: ❌ 关闭 (会破坏Odoo的JavaScript)
Auto Minify JavaScript: ❌ 关闭 (可能破坏Odoo JS)

# 速度 > 缓存
开发模式: ❌ 关闭 (生产环境)
```

#### 管理系统模式 Cloudflare 配置

**1. 安全优先配置**

```bash
# 安全 > WAF
创建自定义规则:
- 规则名称: "限制管理系统访问"
- 表达式: (http.host eq "erp.example.com") and (ip.geoip.country ne "CN")
- 操作: 阻止

# 安全 > 访问
启用 Cloudflare Access:
- 应用程序: erp.example.com
- 策略: 仅允许特定邮箱域名
```

**2. 缓存策略**

```bash
# 页面规则
优先级 1: erp.example.com/*
- 缓存级别: 绕过缓存
- 安全级别: 高
- 禁用性能功能: 开启
```

#### Cloudflare 与真实 IP 传递

**1. 服务器端配置**

编辑 Nginx 主配置文件：

```bash
sudo nano /etc/nginx/nginx.conf
```

在 `http` 块中添加 Cloudflare IP 范围：

```nginx
http {
    # Cloudflare IP 范围 (定期更新)
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 2400:cb00::/32;
    set_real_ip_from 2606:4700::/32;
    set_real_ip_from 2803:f800::/32;
    set_real_ip_from 2405:b500::/32;
    set_real_ip_from 2405:8100::/32;
    set_real_ip_from 2c0f:f248::/32;
    set_real_ip_from 2a06:98c0::/29;

    # 使用 Cloudflare 提供的真实 IP 头部
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;
}
```

**2. 验证真实IP传递**

```bash
# 重启 Nginx
sudo systemctl reload nginx

# 检查日志中的IP地址
sudo tail -f /var/log/nginx/access.log

# 在 Odoo 中验证
# 登录 Odoo 后台 > 设置 > 技术 > 日志记录
# 查看登录日志中显示的IP是否为真实访问者IP
```

**3. 自动更新 Cloudflare IP 脚本**

```bash
# 创建更新脚本
sudo nano /opt/odoo/scripts/update_cloudflare_ips.sh
```

```bash
#!/bin/bash
# 自动更新 Cloudflare IP 范围

NGINX_CONF="/etc/nginx/nginx.conf"
TEMP_FILE="/tmp/cloudflare_ips.conf"

echo "更新 Cloudflare IP 范围..."

# 获取最新的 Cloudflare IP 范围
{
    echo "    # Cloudflare IP 范围 (自动更新 $(date))"
    curl -s https://www.cloudflare.com/ips-v4 | sed 's/^/    set_real_ip_from /'
    curl -s https://www.cloudflare.com/ips-v6 | sed 's/^/    set_real_ip_from /'
    echo "    real_ip_header CF-Connecting-IP;"
    echo "    real_ip_recursive on;"
} > "$TEMP_FILE"

# 备份原配置
cp "$NGINX_CONF" "$NGINX_CONF.backup.$(date +%Y%m%d)"

# 更新配置文件
sed -i '/# Cloudflare IP 范围/,/real_ip_recursive on;/d' "$NGINX_CONF"
sed -i '/http {/r '"$TEMP_FILE" "$NGINX_CONF"

# 测试配置
if nginx -t; then
    systemctl reload nginx
    echo "Cloudflare IP 范围更新成功"
else
    echo "配置文件错误，恢复备份"
    cp "$NGINX_CONF.backup.$(date +%Y%m%d)" "$NGINX_CONF"
fi

rm -f "$TEMP_FILE"
```

```bash
# 设置执行权限
sudo chmod +x /opt/odoo/scripts/update_cloudflare_ips.sh

# 添加到定时任务（每月更新）
echo "0 3 1 * * /opt/odoo/scripts/update_cloudflare_ips.sh >> /var/log/cloudflare_update.log 2>&1" | sudo crontab -
```

### CDN 和边缘优化

#### Cloudflare Workers 高级优化

**1. 创建 Workers 脚本**

在 Cloudflare 仪表板中创建 Worker：

```javascript
// Odoo 智能缓存 Worker
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  const cache = caches.default
  
  // 静态资源长期缓存
  if (url.pathname.match(/\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$/)) {
    const cacheKey = new Request(url.toString(), request)
    let response = await cache.match(cacheKey)
    
    if (!response) {
      response = await fetch(request)
      if (response.status === 200) {
        const newResponse = new Response(response.body, response)
        newResponse.headers.set('Cache-Control', 'public, max-age=31536000, immutable')
        newResponse.headers.set('Vary', 'Accept-Encoding')
        event.waitUntil(cache.put(cacheKey, newResponse.clone()))
        return newResponse
      }
    }
    return response
  }
  
  // API 请求智能缓存
  if (url.pathname.startsWith('/web/dataset/call_kw/') && request.method === 'POST') {
    const cacheKey = new Request(url.toString() + await request.clone().text(), {
      method: 'GET',
      headers: request.headers
    })
    
    let response = await cache.match(cacheKey)
    if (!response) {
      response = await fetch(request)
      if (response.status === 200 && response.headers.get('content-type')?.includes('application/json')) {
        const newResponse = new Response(response.body, response)
        newResponse.headers.set('Cache-Control', 'public, max-age=300')
        event.waitUntil(cache.put(cacheKey, newResponse.clone()))
        return newResponse
      }
    }
    return response
  }
  
  // 动态页面不缓存
  if (url.pathname.startsWith('/web/') || 
      url.pathname.startsWith('/my/') || 
      url.pathname.startsWith('/shop/checkout')) {
    const response = await fetch(request)
    const newResponse = new Response(response.body, response)
    newResponse.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate')
    return newResponse
  }
  
  // 其他请求正常处理
  return fetch(request)
}
```

**2. 配置 Worker 路由**

```
路由: example.com/*
Worker: odoo-cache-worker
```

#### 其他 CDN 服务配置

**1. AWS CloudFront 配置**

如果使用 AWS CloudFront：

```json
{
  "Origins": [{
    "DomainName": "your-server-ip",
    "Id": "odoo-origin",
    "CustomOriginConfig": {
      "HTTPPort": 443,
      "OriginProtocolPolicy": "https-only"
    }
  }],
  "DefaultCacheBehavior": {
    "TargetOriginId": "odoo-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "CachePolicyId": "custom-odoo-policy"
  },
  "CacheBehaviors": [{
    "PathPattern": "/web/static/*",
    "CachePolicyId": "managed-caching-optimized",
    "TTL": 31536000
  }]
}
```

**2. 阿里云 CDN 配置**

```bash
# 缓存规则配置
路径: /web/static/*
缓存时间: 1年
忽略参数: 是

路径: /website/static/*
缓存时间: 1年
忽略参数: 是

路径: /web/*
缓存时间: 不缓存
```

### Odoo Website 性能优化

#### 后台设置优化

**1. 网站性能设置**

登录 Odoo 后台，进行以下配置：

```bash
# 导航路径: 网站 > 配置 > 设置

✅ 启用以下选项:
- 压缩 HTML: 是
- 压缩 CSS: 是  
- 压缩 JavaScript: 是
- 合并资源: 是
- 启用 CDN: 是 (如果使用CDN)

# 高级设置
- 缓存策略: 积极缓存
- 图片优化: 启用 WebP
- 延迟加载: 启用
```

**2. SEO 优化设置**

```bash
# 导航路径: 网站 > 配置 > 设置 > SEO

✅ 启用以下选项:
- 网站地图: 是
- 结构化数据: 是
- 社交媒体优化: 是
- 页面速度优化: 是

# 配置 robots.txt
# 导航路径: 网站 > 配置 > 网站地图
# 确保 robots.txt 允许搜索引擎访问
```

**3. 图片优化配置**

```bash
# 在 Odoo 后台执行以下 Python 代码
# 导航路径: 设置 > 技术 > 服务器操作

# 批量优化图片
import base64
from PIL import Image
import io

def optimize_images():
    attachments = env['ir.attachment'].search([
        ('mimetype', 'like', 'image/%'),
        ('res_model', '=', 'website')
    ])
    
    for attachment in attachments:
        if attachment.datas:
            image_data = base64.b64decode(attachment.datas)
            image = Image.open(io.BytesIO(image_data))
            
            # 优化图片
            if image.mode in ('RGBA', 'LA'):
                image = image.convert('RGB')
            
            output = io.BytesIO()
            image.save(output, format='JPEG', quality=85, optimize=True)
            
            attachment.datas = base64.b64encode(output.getvalue())
            
optimize_images()
```

#### 前端性能优化

**1. 自定义 CSS/JS 优化**

```bash
# 创建自定义模块进行前端优化
mkdir -p /opt/odoo/addons/website_performance
```

创建模块文件：

```xml
<!-- /opt/odoo/addons/website_performance/__manifest__.py -->
{
    'name': 'Website Performance',
    'version': '1.0',
    'depends': ['website'],
    'data': ['views/templates.xml'],
    'assets': {
        'web.assets_frontend': [
            'website_performance/static/src/js/performance.js',
            'website_performance/static/src/css/performance.css',
        ],
    },
}
```

```xml
<!-- /opt/odoo/addons/website_performance/views/templates.xml -->
<odoo>
    <template id="performance_head" inherit_id="website.layout" name="Performance Head">
        <xpath expr="//head" position="inside">
            <!-- DNS 预解析 -->
            <link rel="dns-prefetch" href="//fonts.googleapis.com"/>
            <link rel="dns-prefetch" href="//cdnjs.cloudflare.com"/>
            
            <!-- 关键资源预加载 -->
            <link rel="preload" href="/web/static/src/css/bootstrap.css" as="style"/>
            <link rel="preload" href="/web/static/src/js/boot.js" as="script"/>
            
            <!-- 字体预加载 -->
            <link rel="preload" href="/web/static/fonts/lato/lato-regular.woff2" as="font" type="font/woff2" crossorigin=""/>
            
            <!-- 性能监控 -->
            <script>
                // 页面加载性能监控
                window.addEventListener('load', function() {
                    setTimeout(function() {
                        var perfData = performance.getEntriesByType('navigation')[0];
                        console.log('页面加载时间:', perfData.loadEventEnd - perfData.fetchStart, 'ms');
                    }, 0);
                });
            </script>
        </xpath>
    </template>
</odoo>
```

**2. 图片懒加载实现**

```javascript
// /opt/odoo/addons/website_performance/static/src/js/performance.js
odoo.define('website_performance.lazy_loading', function (require) {
    'use strict';
    
    var publicWidget = require('web.public.widget');
    
    publicWidget.registry.LazyLoading = publicWidget.Widget.extend({
        selector: '.s_website_form, .s_text_image, .s_image_gallery',
        
        start: function () {
            this._super.apply(this, arguments);
            this._setupLazyLoading();
        },
        
        _setupLazyLoading: function () {
            var images = this.$el.find('img[data-src]');
            
            if ('IntersectionObserver' in window) {
                var imageObserver = new IntersectionObserver(function(entries, observer) {
                    entries.forEach(function(entry) {
                        if (entry.isIntersecting) {
                            var img = entry.target;
                            img.src = img.dataset.src;
                            img.classList.remove('lazy');
                            imageObserver.unobserve(img);
                        }
                    });
                });
                
                images.each(function() {
                    imageObserver.observe(this);
                });
            } else {
                // 降级处理
                images.each(function() {
                    this.src = this.dataset.src;
                });
            }
        }
    });
});
```

**3. 安装自定义模块**

```bash
# 重启 Odoo 容器
docker restart odoo

# 在 Odoo 后台安装模块
# 导航路径: 应用 > 更新应用列表 > 搜索 "Website Performance" > 安装
```

#### 第三方性能工具集成

**1. Google Analytics 4 集成**

```bash
# 在 Odoo 后台配置
# 导航路径: 网站 > 配置 > 设置 > SEO

Google Analytics Key: G-XXXXXXXXXX
Google Tag Manager Key: GTM-XXXXXXX
```

**2. Google PageSpeed 优化**

定期检查网站性能：

```bash
# 创建性能检查脚本
nano /opt/odoo/scripts/pagespeed_check.sh
```

```bash
#!/bin/bash
# PageSpeed 性能检查

DOMAIN="https://www.example.com"
API_KEY="your-pagespeed-api-key"

echo "检查网站性能: $DOMAIN"

# 移动端性能
MOBILE_SCORE=$(curl -s "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$DOMAIN&strategy=mobile&key=$API_KEY" | jq '.lighthouseResult.categories.performance.score * 100')

# 桌面端性能
DESKTOP_SCORE=$(curl -s "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$DOMAIN&strategy=desktop&key=$API_KEY" | jq '.lighthouseResult.categories.performance.score * 100')

echo "移动端性能评分: $MOBILE_SCORE"
echo "桌面端性能评分: $DESKTOP_SCORE"

# 如果评分低于80，发送警告
if (( $(echo "$MOBILE_SCORE < 80" | bc -l) )); then
    echo "警告: 移动端性能评分过低"
fi
```

这些配置涵盖了脚本无法自动实现的高级优化功能，用户可以根据实际需求选择性配置。

## 🔍 故障排除

### 常见问题

**Q: 容器启动失败**
```bash
# 查看详细错误
docker-compose logs

# 检查配置文件
docker-compose config

# 重新启动
docker-compose down && docker-compose up -d
```

**Q: 无法访问网站**
```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 检查 Nginx 配置
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

**Q: 数据库连接失败**
```bash
# 检查数据库状态
docker exec odoo-db pg_isready -U odoo

# 测试连接
docker exec odoo ping db

# 查看数据库日志
docker logs odoo-db
```

**Q: 内存不足**
```bash
# 检查内存使用
free -h

# 调整容器内存限制
nano /opt/odoo/docker-compose.yml

# 重启容器
docker-compose restart
```

### 获取帮助

- 📖 **详细文档**: [完整部署指南](https://github.com/hwc0212/install-odoo19/blob/main/odoo_deployment_guide_revised.md)
- 🐛 **问题反馈**: [GitHub Issues](https://github.com/hwc0212/install-odoo19/issues)
- 💬 **技术交流**: [作者博客](https://huwencai.com)

## 📝 常用命令

### 容器管理
```bash
# 查看容器状态
docker ps

# 查看容器日志
docker logs odoo
docker logs odoo-db
docker logs odoo-redis

# 重启服务
cd /opt/odoo
docker-compose restart

# 停止服务
docker-compose down

# 启动服务
docker-compose up -d
```

### 系统维护
```bash
# 查看系统资源
htop
df -h
free -h

# 查看网络连接
ss -tlnp

# 查看防火墙状态
sudo ufw status

# 查看 Fail2Ban 状态
sudo fail2ban-client status
```

### 备份恢复
```bash
# 备份数据库
docker exec odoo-db pg_dump -U odoo > backup.sql

# 恢复数据库
docker exec -i odoo-db psql -U odoo < backup.sql

# 备份文件
tar -czf odoo_backup.tar.gz /opt/odoo/data /opt/odoo/addons

# 恢复文件
tar -xzf odoo_backup.tar.gz -C /
```

## ⚠️ 重要提醒

### 安全注意事项

1. **立即更改默认密码**: 部署完成后立即更改所有默认密码
2. **定期备份**: 建立定期备份机制，数据无价
3. **监控日志**: 定期检查系统和应用日志
4. **及时更新**: 保持系统和应用程序最新版本
5. **网络安全**: 如果可能，使用 VPN 访问管理系统

### 性能注意事项

1. **资源监控**: 定期监控 CPU、内存、磁盘使用情况
2. **数据库维护**: 定期清理和优化数据库
3. **日志轮转**: 避免日志文件过大占用磁盘空间
4. **缓存清理**: 定期清理 Redis 缓存

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

### 贡献指南

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