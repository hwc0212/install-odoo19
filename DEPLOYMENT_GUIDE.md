# Odoo 19 生产环境部署操作手册

> 作者: huwencai.com | 更新日期: 2026-01-13

本手册提供 Odoo 19 在 Ubuntu 24.04 上的完整部署步骤，包括系统优化、Docker 环境配置、Nginx 反向代理、SSL 证书、安全加固和性能优化。

---

## 第一部分：系统初始化与安全配置

### 1.1 创建非 Root 用户

```bash
# 添加新用户
sudo adduser odooadmin

# 添加到 sudo 组
sudo usermod -aG sudo odooadmin

# 切换到新用户
sudo su - odooadmin
```

### 1.2 配置 SSH 密钥登录

**在本地机器上生成密钥：**
```bash
ssh-keygen -t ed25519 -C "odoo-production"
```

**将公钥复制到服务器：**
```bash
ssh-copy-id odooadmin@your-server-ip
```

**禁用密码登录：**
```bash
sudo nano /etc/ssh/sshd_config
```

修改以下内容：
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

重启 SSH 服务：
```bash
sudo systemctl restart sshd
```

### 1.3 系统更新与软件安装

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git ufw fail2ban build-essential \
    libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
    libssl-dev nginx certbot python3-certbot-nginx htop
```

### 1.4 配置防火墙

```bash
# 设置默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许必要端口
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443

# 拒绝内部服务端口
sudo ufw deny 8069
sudo ufw deny 5432
sudo ufw deny 6379

# 启用防火墙
sudo ufw enable

# 检查状态
sudo ufw status
```

### 1.5 系统性能优化

**优化文件句柄限制：**
```bash
sudo nano /etc/security/limits.conf
```

添加以下内容：
```
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
```

**优化内核参数：**
```bash
sudo nano /etc/sysctl.conf
```

添加以下内容：
```
# 文件系统优化
fs.file-max = 2097152
fs.nr_open = 2097152

# 网络性能优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 65535

# BBR 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 内存管理优化
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
```

应用配置：
```bash
sudo sysctl -p
```

**禁用透明大页面：**
```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
```

---

## 第二部分：Docker 环境安装与配置

### 2.1 安装 Docker

```bash
# 安装 Docker
sudo apt install -y docker.io docker-compose

# 启动并设置开机自启
sudo systemctl enable docker
sudo systemctl start docker

# 验证安装
docker --version
```

### 2.2 配置 Docker 权限

```bash
# 将当前用户加入 docker 组
sudo usermod -aG docker $USER

# 重新登录 SSH 使权限生效
exit
```

### 2.3 Docker 守护进程优化

```bash
sudo nano /etc/docker/daemon.json
```

写入以下内容：
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
```

重启 Docker：
```bash
sudo systemctl restart docker
```

### 2.4 清理冲突服务

```bash
# 停止并卸载可能冲突的服务
sudo systemctl stop redis-server 2>/dev/null || true
sudo apt purge -y redis-server redis postgresql*

# 验证端口无监听
ss -lntp | grep -E '6379|5432|8069' || echo "端口检查通过"
```

---

## 第三部分：Odoo 服务部署

### 3.1 创建目录结构

```bash
sudo mkdir -p /opt/odoo/{data,addons,pgdata,redis,config}
sudo chown -R $USER:$USER /opt/odoo
cd /opt/odoo
```

### 3.2 VPS 资源配置计算指南

在创建配置文件之前，先根据您的 VPS 资源计算合适的参数。

#### 📊 第一步：查看 VPS 资源

```bash
# 查看 CPU 核心数
nproc

# 查看内存大小（GB）
free -h | grep Mem | awk '{print $2}'

# 查看可用磁盘空间
df -h /
```

#### 🧮 第二步：计算配置参数

根据查询结果，使用以下公式计算：

| 参数 | 计算公式 | 说明 |
|------|---------|------|
| **Odoo Workers** | CPU 核心数 × 2 + 1 | 例如：4核 = 9 workers |
| **Odoo 内存限制** | 总内存 × 50-75% | 例如：8GB × 60% = 4.8GB |
| **PostgreSQL shared_buffers** | 总内存 × 25% | 例如：8GB × 25% = 2GB |
| **PostgreSQL effective_cache_size** | 总内存 × 75% | 例如：8GB × 75% = 6GB |
| **Redis 内存** | 512MB - 2GB | 根据并发用户数 |

#### 📋 常见 VPS 配置参考表

| VPS 配置 | Workers | Odoo 内存 (soft/hard) | PG shared_buffers | PG effective_cache | Redis 内存 |
|----------|---------|----------------------|-------------------|-------------------|-----------|
| **1核2GB** | 3 | 1GB / 1.2GB | 512MB | 1.5GB | 256MB |
| **2核4GB** | 5 | 2GB / 2.5GB | 1GB | 3GB | 512MB |
| **4核8GB** | 9 | 4GB / 5GB | 2GB | 6GB | 1GB |
| **6核16GB** | 13 | 8GB / 10GB | 4GB | 12GB | 2GB |
| **8核32GB** | 17 | 16GB / 20GB | 8GB | 24GB | 4GB |

#### 💡 配置示例

**示例 1：2核4GB VPS**
```ini
# Odoo 配置
workers = 5
limit_memory_soft = 2147483648    # 2GB
limit_memory_hard = 2684354560    # 2.5GB

# PostgreSQL 配置
shared_buffers = 1GB
effective_cache_size = 3GB
work_mem = 32MB

# Redis 配置
maxmemory 512mb
```

**示例 2：4核8GB VPS**
```ini
# Odoo 配置
workers = 9
limit_memory_soft = 4294967296    # 4GB
limit_memory_hard = 5368709120    # 5GB

# PostgreSQL 配置
shared_buffers = 2GB
effective_cache_size = 6GB
work_mem = 64MB

# Redis 配置
maxmemory 1gb
```

**示例 3：8核16GB VPS**
```ini
# Odoo 配置
workers = 17
limit_memory_soft = 8589934592    # 8GB
limit_memory_hard = 10737418240   # 10GB

# PostgreSQL 配置
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 128MB

# Redis 配置
maxmemory 2gb
```

#### ⚠️ 重要注意事项

1. **不要分配所有内存**
   - 必须为系统预留至少 25% 的内存
   - 避免 OOM (Out of Memory) 导致系统崩溃

2. **Workers 数量限制**
   - 不要超过 `CPU 核心数 × 2 + 1`
   - 过多 workers 会导致上下文切换开销

3. **内存单位转换**
   ```
   1GB = 1024MB = 1073741824 字节
   2GB = 2048MB = 2147483648 字节
   4GB = 4096MB = 4294967296 字节
   8GB = 8192MB = 8589934592 字节
   ```

4. **监控和调整**
   - 部署后使用 `docker stats` 监控资源使用
   - 如果内存使用率超过 90%，需要减少分配
   - 如果 CPU 使用率持续 100%，需要减少 workers

#### 🔧 快速计算工具

```bash
# 自动计算脚本
cat > /tmp/calc_odoo_resources.sh << 'EOF'
#!/bin/bash
CPU=$(nproc)
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')

echo "=== VPS 资源检测 ==="
echo "CPU 核心数: $CPU"
echo "内存大小: ${MEM_GB}GB"
echo ""
echo "=== 推荐配置参数 ==="
echo "Odoo Workers: $((CPU * 2 + 1))"
echo "Odoo 内存 (soft): $((MEM_GB * 50 / 100))GB"
echo "Odoo 内存 (hard): $((MEM_GB * 60 / 100))GB"
echo "PostgreSQL shared_buffers: $((MEM_GB * 25 / 100))GB"
echo "PostgreSQL effective_cache_size: $((MEM_GB * 75 / 100))GB"
echo "Redis 内存: 建议 512MB-2GB"
EOF

chmod +x /tmp/calc_odoo_resources.sh
/tmp/calc_odoo_resources.sh
```

### 3.3 创建 Odoo 配置文件

> **💡 提示**：请根据上一节计算的参数修改以下配置文件

```bash
nano /opt/odoo/config/odoo.conf
```

写入以下内容（**请根据您的 VPS 配置调整参数**）：
```ini
[options]
# 数据库配置
db_host = db
db_port = 5432
db_user = odoo
db_password = your_strong_password_here

# 基础配置
addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons
data_dir = /var/lib/odoo

# 安全配置
proxy_mode = True
list_db = False
admin_passwd = your_admin_password_here

# 性能配置（⚠️ 请根据 3.2 节计算的参数修改）
workers = 9                      # 修改为：CPU核心数 × 2 + 1
max_cron_threads = 2
limit_time_cpu = 60
limit_time_real = 120
limit_memory_soft = 2147483648   # 修改为：总内存 × 50% (字节)
limit_memory_hard = 2684354560   # 修改为：总内存 × 60% (字节)

# Redis 会话管理
session_redis = True
redis_host = redis
redis_port = 6379
redis_dbindex = 1

# 日志配置
log_level = info
logfile = /var/lib/odoo/odoo.log
log_rotate = True
log_max_size = 100000000

# 网络配置
xmlrpc_port = 8069
longpolling_port = 8072
```

### 3.4 创建 PostgreSQL 配置文件

> **💡 提示**：请根据 3.2 节计算的参数修改以下配置文件

```bash
nano /opt/odoo/config/postgresql.conf
```

写入以下内容（**请根据您的 VPS 配置调整参数**）：
```ini
# PostgreSQL 15 优化配置（⚠️ 请根据 3.2 节计算的参数修改）
max_connections = 200
shared_buffers = 2GB              # 修改为：总内存 × 25%
effective_cache_size = 6GB        # 修改为：总内存 × 75%
work_mem = 64MB                   # 2核=32MB, 4核=64MB, 8核=128MB
maintenance_work_mem = 128MB
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
shared_preload_libraries = 'pg_stat_statements'
track_activities = on
track_counts = on
autovacuum = on
```

### 3.5 创建 Redis 配置文件

> **💡 提示**：请根据 3.2 节计算的参数修改以下配置文件

```bash
nano /opt/odoo/config/redis.conf
```

写入以下内容（**请根据您的 VPS 配置调整参数**）：
```ini
bind 0.0.0.0
port 6379
timeout 300
maxmemory 1gb                    # ⚠️ 修改为：512mb-2gb（根据并发用户数）
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
loglevel notice
maxclients 10000
protected-mode no
```

**Redis 内存配置建议：**
- 1核2GB VPS: `maxmemory 256mb`
- 2核4GB VPS: `maxmemory 512mb`
- 4核8GB VPS: `maxmemory 1gb`
- 8核16GB VPS: `maxmemory 2gb`

### 3.6 创建 Docker Compose 文件

> **💡 提示**：请根据 3.2 节计算的参数修改以下配置文件中的资源限制

```bash
nano /opt/odoo/docker-compose.yml
```

写入以下内容（**请根据您的 VPS 配置调整资源限制**）：
```yaml
version: '3.8'

services:
  odoo:
    image: odoo:19
    container_name: odoo
    restart: unless-stopped
    depends_on:
      - db
      - redis
    environment:
      - HOST=db
      - USER=odoo
      - PASSWORD=your_strong_password_here
    volumes:
      - ./data:/var/lib/odoo
      - ./addons:/mnt/extra-addons
      - ./config/odoo.conf:/etc/odoo/odoo.conf:ro
    networks:
      - odoo-net
    deploy:
      resources:
        limits:
          cpus: "2"              # ⚠️ 修改为：CPU核心数 × 50-80%
          memory: "4G"           # ⚠️ 修改为：总内存 × 50-75%
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8069/web/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:15-alpine
    container_name: odoo-db
    restart: unless-stopped
    environment:
      - POSTGRES_PASSWORD=your_postgres_password_here
      - POSTGRES_USER=odoo
      - POSTGRES_DB=postgres
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    networks:
      - odoo-net
    deploy:
      resources:
        limits:
          cpus: "1"              # ⚠️ 修改为：CPU核心数 × 25-50%
          memory: "2G"           # ⚠️ 修改为：总内存 × 25-30%
    command: >
      postgres
      -c shared_buffers=2GB      # ⚠️ 修改为：总内存 × 25%
      -c effective_cache_size=6GB # ⚠️ 修改为：总内存 × 75%
      -c work_mem=64MB           # ⚠️ 根据CPU核心数调整
      -c maintenance_work_mem=128MB
      -c max_connections=200

  redis:
    image: redis:7-alpine
    container_name: odoo-redis
    restart: unless-stopped
    volumes:
      - ./redis:/data
      - ./config/redis.conf:/usr/local/etc/redis/redis.conf:ro
    networks:
      - odoo-net
    deploy:
      resources:
        limits:
          cpus: "0.5"            # ⚠️ Redis 通常不需要太多CPU
          memory: "512M"         # ⚠️ 修改为：512MB-2GB
    command: redis-server /usr/local/etc/redis/redis.conf

networks:
  odoo-net:
    driver: bridge
```

**📋 Docker Compose 资源配置参考表：**

| VPS 配置 | Odoo CPU/内存 | PostgreSQL CPU/内存 | Redis CPU/内存 |
|----------|---------------|---------------------|----------------|
| 1核2GB   | 0.5核/1G      | 0.3核/512M          | 0.2核/256M     |
| 2核4GB   | 1核/2G        | 0.5核/1G            | 0.5核/512M     |
| 4核8GB   | 2核/4G        | 1核/2G              | 0.5核/1G       |
| 8核16GB  | 4核/8G        | 2核/4G              | 1核/2G         |

### 3.7 启动服务

```bash
cd /opt/odoo
docker-compose up -d
```

### 3.8 验证部署和资源使用

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs odoo
docker logs odoo-db
docker logs odoo-redis

# 验证端口未暴露
ss -tlnp | grep -E '8069|5432|6379' && echo "警告：发现暴露端口" || echo "正常"
```

### 3.8 初始化数据库

**临时允许数据库管理界面：**
```bash
nano /opt/odoo/config/odoo.conf
```

修改：
```ini
list_db = True  # 临时改为 True
```

重启容器：
```bash
docker restart odoo
```

访问 `http://your-server-ip:8069/web/database/manager` 创建数据库。

**完成后立即禁用：**
```bash
nano /opt/odoo/config/odoo.conf
```

改回：
```ini
list_db = False
dbfilter = ^your_database_name$
```

重启容器：
```bash
docker restart odoo
```

---

## 第四部分：Nginx 反向代理配置

### ⚠️ 重要：部署模式选择说明

在配置 Nginx 之前，请先明确您的使用场景，**选择一种模式配置，不要混用**：

#### 📋 模式选择指南

| 使用场景 | 选择模式 | 配置文件 | 说明 |
|---------|---------|---------|------|
| 只做内部管理系统 | **管理系统模式** | odoo-admin.conf | 推荐新手使用 |
| 只做对外网站 | **网站模式** | odoo-site.conf | 需要域名和 SEO |
| 既要管理又要网站 | **双模式** | 两个配置都要 | 高级用户，需要两个域名 |

#### ❌ 常见错误配置

**错误 1：混用两种模式的配置**
```bash
# ❌ 错误：同时配置了管理系统和网站模式在同一个域名
# 这会导致缓存策略冲突、安全头部冲突、SEO 问题
```

**错误 2：管理系统使用网站模式配置**
```bash
# ❌ 错误：管理系统使用了网站模式的配置
# 问题：
# - 搜索引擎会收录管理后台（安全风险）
# - 缓存策略不当导致数据不一致
# - 安全头部不够严格
```

**错误 3：网站使用管理系统模式配置**
```bash
# ❌ 错误：网站使用了管理系统模式的配置
# 问题：
# - robots.txt 屏蔽所有搜索引擎（SEO 失效）
# - 严格的安全头部影响网站功能
# - 缓存策略过于保守影响性能
```

#### ✅ 正确配置方式

**场景 1：只做管理系统（推荐新手）**
```bash
# 只配置 odoo-admin.conf
# 使用 IP 或二级域名访问（如 erp.example.com）
# 特点：高安全性，屏蔽搜索引擎
```

**场景 2：只做网站**
```bash
# 只配置 odoo-site.conf
# 使用主域名访问（如 www.example.com）
# 特点：SEO 友好，性能优化
```

**场景 3：管理系统 + 网站（高级）**
```bash
# 同时配置两个文件，使用不同域名：
# - erp.example.com → odoo-admin.conf（管理系统）
# - www.example.com → odoo-site.conf（网站）
# 
# 注意：必须使用不同的域名，不能共用！
```

#### 🔍 如何判断应该选择哪种模式？

**选择管理系统模式，如果您：**
- ✅ 只需要内部使用 Odoo 进行业务管理
- ✅ 不需要对外展示网站
- ✅ 希望最大化安全性
- ✅ 不关心 SEO
- ✅ 通过 IP 或内部域名访问

**选择网站模式，如果您：**
- ✅ 需要使用 Odoo Website 模块建站
- ✅ 需要搜索引擎收录
- ✅ 需要对外展示产品/服务
- ✅ 关心网站性能和 SEO
- ✅ 使用公开域名访问

**选择双模式，如果您：**
- ✅ 既需要内部管理系统
- ✅ 又需要对外展示网站
- ✅ 有两个不同的域名可用
- ✅ 熟悉 Nginx 配置

#### ⚠️ 混用模式的后果

如果在同一个域名上混用两种模式的配置，会导致：

1. **安全问题**
   - 管理后台可能被搜索引擎收录
   - 安全头部配置冲突
   - 访问控制失效

2. **功能问题**
   - 缓存策略冲突导致数据不一致
   - 某些功能无法正常工作
   - 用户会话管理混乱

3. **性能问题**
   - 缓存命中率低
   - 不必要的限流影响用户体验
   - 资源浪费

4. **SEO 问题**
   - 搜索引擎无法正确收录
   - robots.txt 配置冲突
   - 网站排名受影响

#### 📝 配置建议

1. **新手用户**：先使用管理系统模式，熟悉后再考虑扩展
2. **企业用户**：使用双模式，管理和展示分离
3. **个人用户**：根据主要需求选择单一模式
4. **测试环境**：可以使用管理系统模式，生产环境再切换

---

### 4.0 Nginx 全局性能与安全优化

在配置站点之前，先优化 Nginx 主配置文件以提升性能和安全性。

**编辑 Nginx 主配置文件：**
```bash
sudo nano /etc/nginx/nginx.conf
```

**完整优化配置：**
```nginx
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    ##
    # 基础设置
    ##
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    types_hash_max_size 2048;
    server_tokens off;
    
    # 客户端请求限制
    client_max_body_size 128M;
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
    
    # MIME 类型
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL 优化配置
    ##
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    ##
    # 日志配置
    ##
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';
    
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;
    error_log /var/log/nginx/error.log warn;

    ##
    # Gzip 压缩配置
    ##
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        application/atom+xml
        image/svg+xml
        text/x-component
        text/x-cross-domain-policy;
    gzip_disable "msie6";
    gzip_min_length 256;
    gzip_buffers 16 8k;

    ##
    # 缓存配置
    ##
    proxy_cache_path /var/cache/nginx/odoo 
        levels=1:2 
        keys_zone=odoo_cache:100m 
        max_size=1g 
        inactive=60m 
        use_temp_path=off;
    
    proxy_cache_path /var/cache/nginx/static 
        levels=1:2 
        keys_zone=static_cache:100m 
        max_size=2g 
        inactive=7d 
        use_temp_path=off;

    ##
    # 代理优化配置
    ##
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
    proxy_temp_file_write_size 8k;
    proxy_connect_timeout 90;
    proxy_send_timeout 90;
    proxy_read_timeout 90;
    proxy_http_version 1.1;
    
    # 代理头部设置
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection "";

    ##
    # 限流配置
    ##
    # 登录页面限流
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    # API 限流
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/m;
    # 通用限流
    limit_req_zone $binary_remote_addr zone=general_limit:10m rate=10r/s;
    # 连接数限制
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    ##
    # 文件句柄缓存
    ##
    open_file_cache max=10000 inactive=30s;
    open_file_cache_valid 60s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    ##
    # 安全头部（全局默认）
    ##
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    ##
    # 虚拟主机配置
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

**创建缓存目录：**
```bash
sudo mkdir -p /var/cache/nginx/odoo
sudo mkdir -p /var/cache/nginx/static
sudo chown -R www-data:www-data /var/cache/nginx
```

**验证配置并重启：**
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### 4.1 SSL 证书配置

**方式一：Let's Encrypt 证书（域名访问）**
```bash
sudo certbot --nginx -d example.com -d www.example.com
```

**方式二：自签名证书（IP访问）**
```bash
sudo mkdir -p /etc/ssl/private
sudo chmod 700 /etc/ssl/private

sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/odoo.key \
  -out /etc/ssl/certs/odoo.crt \
  -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Odoo/CN=your-server-ip"
```

### 4.2 管理系统模式 Nginx 配置

> **⚠️ 使用场景**：只用于内部管理，不对外展示网站  
> **⚠️ 重要提醒**：如果您需要搭建网站，请跳过此节，使用 4.3 网站模式配置  
> **⚠️ 禁止混用**：不要同时配置管理系统模式和网站模式在同一个域名上

```bash
sudo nano /etc/nginx/sites-available/odoo-admin.conf
```

写入以下内容：
```nginx
# HTTP 跳转 HTTPS
server {
    listen 80;
    server_name your_domain_or_ip;
    return 301 https://$host$request_uri;
}

# HTTPS 主配置
server {
    listen 443 ssl http2;
    server_name your_domain_or_ip;

    # SSL 证书配置
    ssl_certificate /etc/ssl/certs/odoo.crt;
    ssl_certificate_key /etc/ssl/private/odoo.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 日志配置
    access_log /var/log/nginx/odoo-admin-access.log main;
    error_log /var/log/nginx/odoo-admin-error.log warn;

    # 连接数限制
    limit_conn conn_limit 10;

    # 屏蔽搜索引擎
    location = /robots.txt {
        default_type text/plain;
        return 200 "User-agent: *\nDisallow: /\n";
        access_log off;
    }

    # 禁止访问数据库管理界面
    location ~* ^/web/database/(manager|selector) {
        deny all;
        return 403;
    }

    # 登录页面限流
    location ~* ^/web/login {
        limit_req zone=login_limit burst=3 nodelay;
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }

    # 静态资源缓存（管理系统只缓存静态文件）
    location ~* ^/web/static/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://localhost:8069;
        proxy_cache static_cache;
        proxy_cache_valid 200 1y;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Cache-Status $upstream_cache_status;
        access_log off;
    }

    # 文件上传
    location ~* ^/web/content/ {
        proxy_pass http://localhost:8069;
        client_max_body_size 128M;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }

    # 主要业务逻辑（不缓存）
    location / {
        # 阻止常见爬虫
        if ($http_user_agent ~* (bot|spider|crawler|scraper|python|curl|wget|scrapy|beautifulsoup|ahrefs|semrush|mj12bot|dotbot|baiduspider|yandex)) {
            return 403;
        }

        # 通用限流
        limit_req zone=general_limit burst=20 nodelay;

        # 不缓存动态内容
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
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 安全头部（管理系统严格模式）
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
}
```

启用配置：
```bash
sudo ln -s /etc/nginx/sites-available/odoo-admin.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**✅ 配置完成检查：**
```bash
# 确认只启用了管理系统模式
ls -la /etc/nginx/sites-enabled/

# 应该只看到 odoo-admin.conf，不应该有 odoo-site.conf
# 如果同时存在两个配置文件，请删除其中一个
```

### 4.3 网站模式 Nginx 配置

> **⚠️ 使用场景**：需要对外展示网站，使用 Odoo Website 模块  
> **⚠️ 重要提醒**：如果您只需要内部管理系统，请跳过此节，使用 4.2 管理系统模式配置  
> **⚠️ 禁止混用**：不要同时配置管理系统模式和网站模式在同一个域名上  
> **⚠️ 域名要求**：网站模式需要正式域名和 Let's Encrypt 证书

```bash
sudo nano /etc/nginx/sites-available/odoo-site.conf
```

写入以下内容：
```nginx
# 非 www 跳转到 www
server {
    listen 80;
    server_name example.com;
    return 301 https://www.example.com$request_uri;
}

# www HTTP 跳转 HTTPS
server {
    listen 80;
    server_name www.example.com;
    return 301 https://$host$request_uri;
}

# 非 www HTTPS 跳转到 www HTTPS
server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    
    return 301 https://www.example.com$request_uri;
}

# 主网站配置
server {
    listen 443 ssl http2;
    server_name www.example.com;

    # SSL 证书配置
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    # 日志配置
    access_log /var/log/nginx/odoo-site-access.log main;
    error_log /var/log/nginx/odoo-site-error.log warn;

    # 连接数限制
    limit_conn conn_limit 50;

    # 禁止访问数据库管理界面
    location ~* ^/web/database/(manager|selector) {
        deny all;
        return 403;
    }

    # 静态资源长期缓存
    location ~* ^/(web|website)/static/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|otf)$ {
        proxy_pass http://localhost:8069;
        proxy_cache static_cache;
        proxy_cache_valid 200 1y;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
        add_header X-Cache-Status $upstream_cache_status;
        access_log off;
        
        # Gzip 已在主配置中启用
    }

    # 图片优化
    location ~* ^/web/image/.*\.(png|jpg|jpeg|gif|webp)$ {
        proxy_pass http://localhost:8069;
        proxy_cache static_cache;
        proxy_cache_valid 200 30d;
        
        expires 30d;
        add_header Cache-Control "public";
        add_header Vary "Accept-Encoding";
        access_log off;
    }

    # 前端页面短期缓存
    location ~* ^/(shop|blog|contactus|aboutus|page) {
        proxy_pass http://localhost:8069;
        proxy_cache odoo_cache;
        proxy_cache_valid 200 5m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_bypass $cookie_session_id $http_pragma $http_authorization;
        proxy_no_cache $cookie_session_id;
        proxy_cache_lock on;
        
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
        add_header Vary "Accept-Encoding";
        add_header X-Cache-Status $upstream_cache_status;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }

    # 后台管理不缓存
    location ~* ^/web/ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        
        # 后台登录限流
        limit_req zone=login_limit burst=5 nodelay;
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 用户相关页面不缓存
    location ~* ^/(my|shop/checkout|shop/cart|shop/payment) {
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

    # API 限流
    location ~* ^/api/ {
        limit_req zone=api_limit burst=50 nodelay;
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 文件上传
    location ~* ^/web/content/ {
        proxy_pass http://localhost:8069;
        client_max_body_size 128M;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }

    # 默认位置
    location / {
        # 通用限流
        limit_req zone=general_limit burst=20 nodelay;
        
        proxy_pass http://localhost:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # SEO 友好的安全头
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Robots-Tag "index, follow" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

启用配置：
```bash
sudo ln -s /etc/nginx/sites-available/odoo-site.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**✅ 配置完成检查：**
```bash
# 确认只启用了网站模式
ls -la /etc/nginx/sites-enabled/

# 应该只看到 odoo-site.conf，不应该有 odoo-admin.conf
# 如果同时存在两个配置文件，请删除其中一个（除非您是高级用户配置双模式）
```

**🔍 双模式配置说明（高级用户）：**

如果您确实需要同时运行管理系统和网站，必须满足以下条件：

1. **使用不同的域名**
   - 管理系统：`erp.example.com`（二级域名）
   - 网站：`www.example.com`（主域名）

2. **修改配置文件中的 server_name**
   ```bash
   # odoo-admin.conf 中
   server_name erp.example.com;
   
   # odoo-site.conf 中
   server_name www.example.com example.com;
   ```

3. **分别申请 SSL 证书**
   ```bash
   sudo certbot --nginx -d erp.example.com
   sudo certbot --nginx -d example.com -d www.example.com
   ```

4. **验证配置**
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

### 4.4 Nginx 性能监控

**创建 Nginx 状态监控页面：**
```bash
sudo nano /etc/nginx/sites-available/nginx-status.conf
```

写入：
```nginx
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```

启用并测试：
```bash
sudo ln -s /etc/nginx/sites-available/nginx-status.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 查看状态
curl http://127.0.0.1:8080/nginx_status
```

---

## 第五部分：安全加固

### 5.1 配置 Fail2Ban

**创建 Odoo 过滤规则：**
```bash
sudo nano /etc/fail2ban/filter.d/odoo.conf
```

写入：
```ini
[Definition]
failregex = .*Login failed for db.*from <HOST>
ignoreregex =
```

**创建 Jail 配置：**
```bash
sudo nano /etc/fail2ban/jail.d/odoo.conf
```

写入：
```ini
[odoo]
enabled = true
filter = odoo
logpath = /opt/odoo/data/odoo.log
maxretry = 5
findtime = 600
bantime = 3600
action = iptables[name=Odoo, port=http, protocol=tcp]
```

重启服务：
```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status
```

### 5.2 数据库安全配置

**进入数据库容器：**
```bash
docker exec -it odoo-db psql -U odoo
```

**创建性能索引：**
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_res_partner_name ON res_partner(name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_res_partner_email ON res_partner(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_template_name ON product_template(name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_move_date ON account_move(date);
```

**启用查询统计：**
```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
ANALYZE;
```

退出：
```sql
\q
```

### 5.3 定期维护脚本

**创建数据库维护脚本：**
```bash
mkdir -p /opt/odoo/scripts
nano /opt/odoo/scripts/db_maintenance.sh
```

写入：
```bash
#!/bin/bash
echo "开始数据库维护 - $(date)"

# 重建索引
docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"

# 更新统计信息
docker exec odoo-db psql -U odoo -c "ANALYZE;"

# 清理死元组
docker exec odoo-db psql -U odoo -c "VACUUM ANALYZE;"

echo "数据库维护完成 - $(date)"
```

设置权限并添加定时任务：
```bash
chmod +x /opt/odoo/scripts/db_maintenance.sh
(crontab -l 2>/dev/null; echo "0 2 * * 0 /opt/odoo/scripts/db_maintenance.sh >> /var/log/odoo_maintenance.log 2>&1") | crontab -
```

---

## 第六部分：Cloudflare 集成

### 6.1 Cloudflare DNS 配置

在 Cloudflare 控制面板添加 DNS 记录：
```
类型    名称              内容              代理状态
A      example.com       your-server-ip    已代理
A      www.example.com   your-server-ip    已代理
```

### 6.2 Cloudflare 真实 IP 配置

**编辑 Nginx 主配置：**
```bash
sudo nano /etc/nginx/nginx.conf
```

在 `http` 块中添加：
```nginx
http {
    # Cloudflare IP 范围
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
    
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;
}
```

重启 Nginx：
```bash
sudo systemctl reload nginx
```

### 6.3 Cloudflare 缓存规则（网站模式）

在 Cloudflare 控制面板创建页面规则：

**规则 1：静态资源**
- URL: `*.example.com/web/static/*`
- 设置: 缓存级别 = 缓存所有内容，边缘缓存TTL = 1个月

**规则 2：后台不缓存**
- URL: `*.example.com/web/*`
- 设置: 缓存级别 = 绕过缓存

**规则 3：前端页面**
- URL: `*.example.com/*`
- 设置: 缓存级别 = 标准，边缘缓存TTL = 2小时

### 6.4 Cloudflare 安全设置（管理系统模式）

**创建 WAF 规则：**
- 表达式: `(http.host eq "erp.example.com") and (ip.geoip.country ne "CN")`
- 操作: 阻止

**启用 Bot Fight Mode：**
- 安全 > Bots > 启用 Bot Fight Mode

---

## 第七部分：Odoo 系统内优化

### 7.1 Odoo 后台性能设置

登录 Odoo 后台，进行以下配置：

**网站性能设置（网站模式）：**
- 导航: 网站 > 配置 > 设置
- 启用: 压缩 HTML、压缩 CSS、压缩 JavaScript
- 启用: 合并资源、延迟加载

**数据库过滤器（重要）：**
```bash
nano /opt/odoo/config/odoo.conf
```

确保设置：
```ini
dbfilter = ^your_database_name$
list_db = False
```

### 7.2 Odoo SEO 优化（网站模式）

**启用网站地图：**
- 导航: 网站 > 配置 > 设置 > SEO
- 启用: 网站地图、结构化数据、社交媒体优化

**配置 robots.txt：**
- 访问: https://www.example.com/robots.txt
- 确保允许搜索引擎访问

### 7.3 Odoo 安全设置

**启用双因素认证：**
- 导航: 设置 > 用户 > 选择用户
- 启用: 双因素认证

**设置密码策略：**
- 导航: 设置 > 技术 > 参数 > 系统参数
- 添加: `auth_password_policy.minlength = 12`

---

## 第八部分：备份与监控

### 8.1 自动备份脚本

```bash
nano /opt/odoo/scripts/backup.sh
```

写入：
```bash
#!/bin/bash
BACKUP_DIR="/opt/odoo/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

# 数据库备份
docker exec odoo-db pg_dump -U odoo -Fc odoo > "$BACKUP_DIR/odoo_db_$DATE.dump"

# 文件存储备份
tar -czf "$BACKUP_DIR/odoo_files_$DATE.tar.gz" -C /opt/odoo data addons

# 清理旧备份
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "备份完成 - $(date)"
```

设置定时任务：
```bash
chmod +x /opt/odoo/scripts/backup.sh
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/odoo/scripts/backup.sh >> /var/log/odoo_backup.log 2>&1") | crontab -
```

### 8.2 系统监控脚本

```bash
nano /opt/odoo/scripts/monitor.sh
```

写入：
```bash
#!/bin/bash
echo "=== Odoo 系统监控 $(date) ==="

# 系统资源
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
echo "内存: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "磁盘: $(df -h / | awk 'NR==2 {print $5}')"

# 容器状态
echo -e "\n容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}"

# 容器资源
echo -e "\n容器资源:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# 数据库连接
echo -e "\n数据库连接数:"
docker exec odoo-db psql -U odoo -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null

echo -e "\n监控完成"
```

设置定时任务：
```bash
chmod +x /opt/odoo/scripts/monitor.sh
(crontab -l 2>/dev/null; echo "0 * * * * /opt/odoo/scripts/monitor.sh >> /var/log/odoo_monitor.log 2>&1") | crontab -
```

### 8.3 SSL 证书自动续期

Let's Encrypt 证书会自动续期，验证配置：
```bash
sudo certbot renew --dry-run
```

创建续期钩子：
```bash
sudo nano /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

写入：
```bash
#!/bin/bash
systemctl reload nginx
echo "$(date): SSL证书已更新" >> /var/log/certbot-renewal.log
```

设置权限：
```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

---

## 第九部分：故障排查

### 9.1 容器启动失败

```bash
# 查看详细错误
docker-compose logs

# 检查配置
docker-compose config

# 重新启动
docker-compose down && docker-compose up -d
```

### 9.2 无法访问网站

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 检查配置
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

### 9.3 数据库连接失败

```bash
# 检查数据库状态
docker exec odoo-db pg_isready -U odoo

# 测试连接
docker exec odoo ping db

# 查看日志
docker logs odoo-db
```

### 9.4 内存不足

```bash
# 检查内存使用
free -h
docker stats

# 调整容器限制
nano /opt/odoo/docker-compose.yml
# 修改 memory 参数后重启
docker-compose restart
```

### 9.5 性能问题

```bash
# 检查慢查询
docker exec odoo-db psql -U odoo -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# 检查数据库大小
docker exec odoo-db psql -U odoo -c "SELECT pg_size_pretty(pg_database_size('odoo'));"

# 重建索引
docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"
```

---

## 第十部分：日常运维命令

### 10.1 容器管理

```bash
# 查看容器状态
docker ps

# 查看日志
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

# 更新镜像
docker-compose pull
docker-compose up -d
```

### 10.2 数据库管理

```bash
# 备份数据库
docker exec odoo-db pg_dump -U odoo -Fc odoo > backup.dump

# 恢复数据库
docker exec -i odoo-db pg_restore -U odoo -d odoo < backup.dump

# 进入数据库
docker exec -it odoo-db psql -U odoo

# 查看数据库大小
docker exec odoo-db psql -U odoo -c "SELECT pg_size_pretty(pg_database_size('odoo'));"
```

### 10.3 系统维护

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

# 清理 Docker 资源
docker system prune -a
```

### 10.4 日志管理

```bash
# 查看 Odoo 日志
tail -f /opt/odoo/data/odoo.log

# 查看 Nginx 日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# 清理日志
sudo truncate -s 0 /var/log/nginx/access.log
sudo truncate -s 0 /var/log/nginx/error.log
```

---

## 附录：资源配置参考表

### VPS 配置与参数对照

| VPS 配置 | Workers | Odoo 内存 | Odoo CPU | PostgreSQL shared_buffers | Redis 内存 |
|----------|---------|-----------|----------|---------------------------|------------|
| 2核4GB   | 5       | 2GB       | 1.5核    | 1GB                       | 512MB      |
| 4核8GB   | 9       | 4GB       | 2核      | 2GB                       | 1GB        |
| 6核16GB  | 13      | 8GB       | 3核      | 4GB                       | 2GB        |
| 8核32GB  | 17      | 12GB      | 4核      | 8GB                       | 4GB        |

### 配置调整公式

- **Workers**: CPU 核心数 × 2 + 1
- **Odoo 内存**: VPS 总内存 × 50-75%
- **PostgreSQL shared_buffers**: VPS 总内存 × 25%
- **PostgreSQL effective_cache_size**: VPS 总内存 × 75%
- **Redis 内存**: 512MB - 2GB（根据并发量）

---

## 完成检查清单

部署完成后，请确认以下项目：

- [ ] SSH 密钥登录已配置，密码登录已禁用
- [ ] 防火墙已启用，只开放必要端口
- [ ] Docker 容器正常运行
- [ ] Nginx 反向代理配置正确
- [ ] SSL 证书已配置（Let's Encrypt 或自签名）
- [ ] 数据库管理界面已禁用（list_db = False）
- [ ] dbfilter 已设置
- [ ] Fail2Ban 已配置并运行
- [ ] 自动备份脚本已设置
- [ ] 监控脚本已设置
- [ ] Cloudflare 已配置（如使用）
- [ ] 性能监控正常

---

**文档版本**: v1.0  
**作者**: huwencai.com  
**更新日期**: 2026-01-13  
**GitHub**: https://github.com/hwc0212/install-odoo19
