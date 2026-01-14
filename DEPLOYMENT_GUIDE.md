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
| **PostgreSQL work_mem** | 根据CPU核心数 | 1-2核=32MB, 4核=64MB, 6-8核=128MB |
| **Redis 内存** | 512MB - 2GB | 根据并发用户数 |

#### 📋 常见 VPS 配置参考表

| VPS 配置 | Workers | Odoo 内存 (soft/hard) | PG shared_buffers | PG effective_cache | PG work_mem | Redis 内存 |
|----------|---------|----------------------|-------------------|-------------------|-------------|-----------|
| **1核2GB** | 3 | 1GB / 1.2GB | 512MB | 1.5GB | 32MB | 256MB |
| **2核4GB** | 5 | 2GB / 2.5GB | 1GB | 3GB | 32MB | 512MB |
| **4核8GB** | 9 | 4GB / 5GB | 2GB | 6GB | 64MB | 1GB |
| **6核16GB** | 13 | 8GB / 10GB | 4GB | 12GB | 128MB | 2GB |
| **8核32GB** | 17 | 16GB / 20GB | 8GB | 24GB | 128MB | 4GB |

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
          cpus: "2"              # ⚠️ 修改为：CPU核心数 × 50-80%（例如：4核 × 60% = 2.4核）
          memory: "4G"           # ⚠️ 修改为：总内存 × 50-75%（例如：8GB × 60% = 4.8GB）
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
          cpus: "1"              # ⚠️ 修改为：CPU核心数 × 25-50%（例如：4核 × 30% = 1.2核）
          memory: "2G"           # ⚠️ 修改为：总内存 × 25-30%（例如：8GB × 25% = 2GB）
    command: >
      postgres
      -c shared_buffers=2GB      # ⚠️ 修改为：总内存 × 25%（例如：8GB × 25% = 2GB）
      -c effective_cache_size=6GB # ⚠️ 修改为：总内存 × 75%（例如：8GB × 75% = 6GB）
      -c work_mem=64MB           # ⚠️ 修改为：1-2核=32MB, 4核=64MB, 6-8核=128MB
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
          cpus: "0.5"            # ⚠️ Redis 通常不需要太多CPU（0.5核足够）
          memory: "512M"         # ⚠️ 修改为：512MB-2GB（1-2核=256MB, 2-4核=512MB, 4-8核=1-2GB）
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
| 既要管理又要网站 | **网站模式** | odoo-site.conf | 推荐，已包含后台安全优化 |

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
# 特点：高安全性，屏蔽所有搜索引擎
```

**场景 2：只做网站**
```bash
# 只配置 odoo-site.conf
# 使用主域名访问（如 www.example.com）
# 特点：SEO 友好，性能优化
```

**场景 3：既要管理又要网站（推荐）**
```bash
# 只配置 odoo-site.conf（网站模式）
# 使用主域名访问（如 www.example.com）
# 
# 说明：
# - 网站模式已包含后台管理的安全优化
# - 后台登录有限流保护
# - 可通过 Odoo 后台配置 robots.txt 屏蔽后台收录
# - 无需单独配置管理系统模式
```

#### 🔍 如何判断应该选择哪种模式？

**选择管理系统模式，如果您：**
- ✅ 只需要内部使用 Odoo 进行业务管理
- ✅ 不需要对外展示网站
- ✅ 希望最大化安全性（完全屏蔽搜索引擎）
- ✅ 不关心 SEO
- ✅ 通过 IP 或内部域名访问

**选择网站模式，如果您：**
- ✅ 需要使用 Odoo Website 模块建站
- ✅ 需要搜索引擎收录网站内容
- ✅ 需要对外展示产品/服务
- ✅ 关心网站性能和 SEO
- ✅ 使用公开域名访问
- ✅ **既需要网站又需要管理后台**（推荐此模式）

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

1. **新手用户**：先使用管理系统模式，熟悉 Odoo 后再考虑扩展
2. **企业用户**：如果需要网站，直接使用网站模式（已包含后台安全优化）
3. **纯内部使用**：使用管理系统模式（最高安全性）
4. **测试环境**：可以使用管理系统模式，生产环境再根据需求选择

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

#### 方式一：Let's Encrypt 证书（域名访问，推荐）

**申请证书：**
```bash
sudo certbot --nginx -d example.com -d www.example.com
```

**配置自动续期：**

Let's Encrypt 证书有效期为 90 天，需要定期续期。

1. **测试自动续期**
   ```bash
   sudo certbot renew --dry-run
   ```

2. **创建续期钩子脚本**
   ```bash
   sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
   sudo nano /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
   ```

   写入：
   ```bash
   #!/bin/bash
   # SSL 证书续期后重载 Nginx
   systemctl reload nginx
   echo "$(date): Let's Encrypt 证书已更新，Nginx 已重载" >> /var/log/certbot-renewal.log
   ```

3. **设置执行权限**
   ```bash
   sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
   ```

4. **验证自动续期任务**
   ```bash
   # Certbot 会自动创建 systemd timer
   sudo systemctl list-timers | grep certbot
   
   # 查看续期配置
   sudo cat /etc/letsencrypt/renewal/example.com.conf
   ```

**说明：**
- Certbot 会自动创建 systemd timer，每天检查两次证书是否需要续期
- 证书在到期前 30 天会自动续期
- 续期成功后会自动执行钩子脚本重载 Nginx

#### 方式二：自签名证书（IP访问或内部测试）

**生成自签名证书：**
```bash
sudo mkdir -p /etc/ssl/private
sudo chmod 700 /etc/ssl/private

sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/odoo.key \
  -out /etc/ssl/certs/odoo.crt \
  -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Odoo/CN=your-server-ip"
```

**配置自动更新：**

自签名证书也需要定期更新（建议每年更新一次）。

1. **创建自动更新脚本**
   ```bash
   sudo nano /opt/odoo/scripts/renew_self_signed_cert.sh
   ```

   写入：
   ```bash
   #!/bin/bash
   # 自签名证书自动更新脚本
   
   CERT_PATH="/etc/ssl/certs/odoo.crt"
   KEY_PATH="/etc/ssl/private/odoo.key"
   SERVER_IP=$(hostname -I | awk '{print $1}')
   LOG_FILE="/var/log/ssl-renewal.log"
   
   echo "$(date): 开始更新自签名证书" >> "$LOG_FILE"
   
   # 检查证书是否即将过期（30天内）
   if openssl x509 -checkend 2592000 -noout -in "$CERT_PATH"; then
       echo "$(date): 证书仍然有效，无需更新" >> "$LOG_FILE"
       exit 0
   fi
   
   # 备份旧证书
   sudo cp "$CERT_PATH" "${CERT_PATH}.backup.$(date +%Y%m%d)"
   sudo cp "$KEY_PATH" "${KEY_PATH}.backup.$(date +%Y%m%d)"
   
   # 生成新证书
   sudo openssl req -x509 -nodes -days 365 \
       -newkey rsa:2048 \
       -keyout "$KEY_PATH" \
       -out "$CERT_PATH" \
       -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Odoo/CN=$SERVER_IP"
   
   # 重载 Nginx
   sudo systemctl reload nginx
   
   echo "$(date): 自签名证书已更新，Nginx 已重载" >> "$LOG_FILE"
   ```

2. **设置执行权限**
   ```bash
   sudo chmod +x /opt/odoo/scripts/renew_self_signed_cert.sh
   ```

3. **添加到定时任务（每月检查一次）**
   ```bash
   (sudo crontab -l 2>/dev/null; echo "0 3 1 * * /opt/odoo/scripts/renew_self_signed_cert.sh") | sudo crontab -
   ```

4. **手动测试脚本**
   ```bash
   sudo /opt/odoo/scripts/renew_self_signed_cert.sh
   
   # 查看日志
   sudo tail -f /var/log/ssl-renewal.log
   ```

**说明：**
- 脚本会检查证书是否在 30 天内过期
- 如果即将过期，自动生成新证书并备份旧证书
- 更新后自动重载 Nginx
- 每月 1 号凌晨 3 点自动检查

#### 证书验证

**验证证书信息：**
```bash
# Let's Encrypt 证书
sudo certbot certificates

# 自签名证书
openssl x509 -in /etc/ssl/certs/odoo.crt -text -noout | grep -E "Issuer|Subject|Not"
```

**测试 HTTPS 访问：**
```bash
# 测试证书
curl -I https://your-domain.com

# 检查证书过期时间
echo | openssl s_client -servername your-domain.com -connect your-domain.com:443 2>/dev/null | openssl x509 -noout -dates
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
```

**� 后台安全说明：**

网站模式已经包含了后台管理的安全优化：
- ✅ 后台登录有限流保护（防暴力破解）
- ✅ 后台页面不缓存（防数据泄露）
- ✅ 数据库管理界面已禁用
- ✅ WebSocket 支持（实时通信）

**如需进一步屏蔽后台被搜索引擎收录：**

1. 登录 Odoo 后台
2. 进入：设置 > 技术 > 用户界面 > 视图
3. 搜索并编辑 `website.robots` 视图
4. 添加以下内容：
   ```
   User-agent: *
   Disallow: /web/
   Disallow: /my/
   Allow: /
   ```

这样可以允许搜索引擎收录网站内容，但屏蔽后台管理页面。

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

### 6.4 Cloudflare 安全设置

> **💡 提示**：以下安全设置适用于管理系统模式和网站模式，根据实际需求选择配置

#### 6.4.1 WAF 自定义规则（重要）

在 Cloudflare 控制面板：安全 > WAF > 自定义规则

**规则 1：保护后台登录页面（必须配置）**
```
规则名称: 保护 Odoo 后台登录
表达式:
  (http.request.uri.path contains "/web/login") and
  (cf.threat_score gt 10)
操作: 质询 (Managed Challenge)
```

**规则 2：限制后台访问地理位置（可选）**
```
规则名称: 限制后台地理访问
表达式:
  (http.request.uri.path contains "/web/") and
  (ip.geoip.country ne "CN" and ip.geoip.country ne "US")
操作: 阻止
说明: 只允许中国和美国访问后台，根据实际需求修改国家代码
```

**规则 3：阻止数据库管理界面访问（必须配置）**
```
规则名称: 阻止数据库管理
表达式:
  (http.request.uri.path contains "/web/database/manager") or
  (http.request.uri.path contains "/web/database/selector")
操作: 阻止
```

**规则 4：防止暴力破解（必须配置）**
```
规则名称: 登录频率限制
表达式:
  (http.request.uri.path eq "/web/login") and
  (http.request.method eq "POST")
操作: 速率限制
配置:
  - 请求数: 5 次
  - 时间窗口: 10 分钟
  - 超过限制后: 阻止 1 小时
```

**规则 5：阻止恶意爬虫（推荐）**
```
规则名称: 阻止恶意爬虫
表达式:
  (http.user_agent contains "scrapy") or
  (http.user_agent contains "python-requests") or
  (http.user_agent contains "curl") or
  (http.user_agent contains "wget") or
  (cf.bot_management.score lt 30)
操作: 阻止
说明: 阻止常见爬虫工具，但不影响正常用户
```

**规则 6：防止 SQL 注入（推荐）**
```
规则名称: SQL 注入防护
表达式:
  (http.request.uri.query contains "union select") or
  (http.request.uri.query contains "drop table") or
  (http.request.uri.query contains "' or '1'='1") or
  (http.request.body.raw contains "union select")
操作: 阻止
```

**规则 7：防止 XSS 攻击（推荐）**
```
规则名称: XSS 攻击防护
表达式:
  (http.request.uri.query contains "<script") or
  (http.request.uri.query contains "javascript:") or
  (http.request.uri.query contains "onerror=")
操作: 阻止
```

**规则 8：限制文件上传大小（可选）**
```
规则名称: 限制大文件上传
表达式:
  (http.request.uri.path contains "/web/content") and
  (http.request.body.size gt 134217728)
操作: 阻止
说明: 限制上传文件大小为 128MB，根据实际需求调整
```

#### 6.4.2 托管规则集（Managed Rulesets）

在 Cloudflare 控制面板：安全 > WAF > 托管规则

**启用以下规则集：**
- ✅ **Cloudflare Managed Ruleset** - 启用（推荐）
- ✅ **Cloudflare OWASP Core Ruleset** - 启用（推荐）
- ✅ **Cloudflare Exposed Credentials Check** - 启用

**配置敏感度：**
- 管理系统模式：设置为"高"
- 网站模式：设置为"中"（避免误拦截）

#### 6.4.3 Bot 管理

在 Cloudflare 控制面板：安全 > Bots

**Bot Fight Mode（免费版）：**
- ✅ 启用 Bot Fight Mode
- 说明：自动阻止已知的恶意机器人

**Super Bot Fight Mode（付费版）：**
如果使用付费版，配置如下：
- 已验证的机器人：允许（如 Google、Bing）
- 未验证的机器人：质询
- 肯定是机器人：阻止

#### 6.4.4 DDoS 防护

在 Cloudflare 控制面板：安全 > DDoS

**HTTP DDoS 攻击防护：**
- ✅ 启用（默认启用）
- 敏感度：高

**网络层 DDoS 攻击防护：**
- ✅ 启用（默认启用）

#### 6.4.5 安全级别设置

在 Cloudflare 控制面板：安全 > 设置

**安全级别：**
- 管理系统模式：高
- 网站模式：中

**质询通过时间：**
- 设置为 30 分钟（平衡安全性和用户体验）

#### 6.4.6 IP 访问规则（可选）

在 Cloudflare 控制面板：安全 > WAF > 工具

**白名单配置（如果有固定办公 IP）：**
```
规则名称: 办公室 IP 白名单
IP 地址: 123.456.789.0/24
操作: 允许
说明: 允许办公室 IP 直接访问，跳过所有安全检查
```

**黑名单配置（如果发现恶意 IP）：**
```
规则名称: 恶意 IP 黑名单
IP 地址: 恶意IP地址
操作: 阻止
说明: 永久阻止已知的恶意 IP
```

#### 6.4.7 速率限制规则

在 Cloudflare 控制面板：安全 > WAF > 速率限制规则

**API 接口限流：**
```
规则名称: API 速率限制
匹配条件: (http.request.uri.path contains "/api/")
速率: 100 请求 / 分钟
操作: 阻止
持续时间: 10 分钟
```

**搜索功能限流：**
```
规则名称: 搜索速率限制
匹配条件: (http.request.uri.path contains "/shop") and (http.request.uri.query contains "search")
速率: 20 请求 / 分钟
操作: 质询
持续时间: 5 分钟
```

#### 6.4.8 安全验证

**测试 WAF 规则：**
```bash
# 测试 SQL 注入防护
curl "https://www.example.com/?id=1' or '1'='1"
# 应该被阻止

# 测试 XSS 防护
curl "https://www.example.com/?q=<script>alert(1)</script>"
# 应该被阻止

# 测试正常访问
curl "https://www.example.com/"
# 应该正常访问
```

**查看安全事件：**
- 导航：Cloudflare 控制面板 > 安全 > 事件
- 查看被阻止的请求和触发的规则
- 根据实际情况调整规则

#### 6.4.9 安全建议总结

**必须配置的规则（优先级高）：**
1. ✅ 保护后台登录页面
2. ✅ 阻止数据库管理界面
3. ✅ 登录频率限制
4. ✅ 启用 Cloudflare Managed Ruleset
5. ✅ 启用 Bot Fight Mode

**推荐配置的规则（优先级中）：**
1. ✅ 阻止恶意爬虫
2. ✅ SQL 注入防护
3. ✅ XSS 攻击防护
4. ✅ API 速率限制

**可选配置的规则（根据需求）：**
1. ⚪ 地理位置限制
2. ⚪ IP 白名单/黑名单
3. ⚪ 文件上传大小限制

### 6.5 Cloudflare 性能优化

#### 6.5.1 速度优化设置

在 Cloudflare 控制面板：速度 > 优化

**Auto Minify（自动压缩）：**
- ✅ JavaScript - 启用
- ✅ CSS - 启用
- ✅ HTML - 启用
- 说明：自动压缩代码，减少文件大小

**Brotli 压缩：**
- ✅ 启用
- 说明：比 Gzip 压缩率更高，减少传输数据量

**Early Hints：**
- ✅ 启用
- 说明：提前发送资源提示，加快页面加载

**HTTP/2 和 HTTP/3：**
- ✅ HTTP/2 - 启用（默认）
- ✅ HTTP/3 (QUIC) - 启用
- 说明：使用最新协议，提升连接速度

**Rocket Loader：**
- ❌ 禁用（重要！）
- 说明：会破坏 Odoo 的 JavaScript，必须禁用

**Mirage：**
- ✅ 启用（付费功能）
- 说明：自动优化图片加载

#### 6.5.2 缓存配置优化

在 Cloudflare 控制面板：缓存 > 配置

**缓存级别：**
- 网站模式：标准
- 管理系统模式：绕过

**浏览器缓存 TTL：**
- 设置为 4 小时
- 说明：平衡缓存效果和内容更新

**始终在线：**
- ✅ 启用
- 说明：当源服务器宕机时，显示缓存的页面

**开发模式：**
- ❌ 禁用（生产环境）
- 说明：仅在调试时临时启用

#### 6.5.3 页面规则优化（网站模式）

在 Cloudflare 控制面板：规则 > 页面规则

**规则 1：静态资源长期缓存**
```
URL: *.example.com/web/static/*
设置:
  - 缓存级别: 缓存所有内容
  - 边缘缓存 TTL: 1 个月
  - 浏览器缓存 TTL: 1 年
  - 自动压缩: 开启
```

**规则 2：图片资源优化**
```
URL: *.example.com/web/image/*
设置:
  - 缓存级别: 缓存所有内容
  - 边缘缓存 TTL: 7 天
  - Polish: 有损压缩（付费功能）
  - WebP 转换: 启用（付费功能）
```

**规则 3：后台完全不缓存**
```
URL: *.example.com/web/*
设置:
  - 缓存级别: 绕过
  - 禁用性能功能: 开启
  - 禁用安全功能: 关闭（保持安全检查）
```

**规则 4：API 接口不缓存**
```
URL: *.example.com/api/*
设置:
  - 缓存级别: 绕过
  - 禁用性能功能: 开启
```

**规则 5：前端页面短期缓存**
```
URL: *.example.com/*
设置:
  - 缓存级别: 标准
  - 边缘缓存 TTL: 2 小时
  - 浏览器缓存 TTL: 4 小时
  - 绕过缓存条件: Cookie 包含 session_id
```

#### 6.5.4 Argo Smart Routing（付费功能）

在 Cloudflare 控制面板：流量 > Argo

**Argo Smart Routing：**
- ✅ 启用（付费）
- 说明：智能路由，选择最快的网络路径
- 效果：平均提速 30%
- 费用：$5/月 + $0.10/GB

**Argo Tiered Cache：**
- ✅ 启用（免费）
- 说明：使用 Cloudflare 的分层缓存架构
- 效果：提高缓存命中率，减少回源请求

#### 6.5.5 图片优化（付费功能）

在 Cloudflare 控制面板：速度 > 优化 > 图片优化

**Polish（图片压缩）：**
- 选项：有损压缩
- 说明：自动压缩图片，减少 50% 文件大小
- 费用：$20/月

**WebP 转换：**
- ✅ 启用
- 说明：自动转换为 WebP 格式，支持的浏览器自动使用
- 效果：比 JPEG 小 25-35%

**Mirage（自适应图片）：**
- ✅ 启用
- 说明：根据网络速度和设备自动调整图片质量
- 费用：包含在 Pro 套餐中

#### 6.5.6 Workers 脚本优化（高级）

创建 Cloudflare Workers 脚本进行高级优化：

```javascript
// Odoo 性能优化 Worker
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  const cache = caches.default
  
  // 静态资源激进缓存
  if (url.pathname.match(/\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$/)) {
    const cacheKey = new Request(url.toString(), request)
    let response = await cache.match(cacheKey)
    
    if (!response) {
      response = await fetch(request)
      if (response.status === 200) {
        const headers = new Headers(response.headers)
        headers.set('Cache-Control', 'public, max-age=31536000, immutable')
        headers.set('Vary', 'Accept-Encoding')
        
        const newResponse = new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: headers
        })
        
        event.waitUntil(cache.put(cacheKey, newResponse.clone()))
        return newResponse
      }
    }
    return response
  }
  
  // 后台不缓存
  if (url.pathname.startsWith('/web/') || 
      url.pathname.startsWith('/my/')) {
    const response = await fetch(request)
    const headers = new Headers(response.headers)
    headers.set('Cache-Control', 'no-cache, no-store, must-revalidate')
    
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: headers
    })
  }
  
  // 前端页面智能缓存
  if (url.pathname.match(/^\/(shop|blog|page)/)) {
    const cacheKey = new Request(url.toString(), request)
    
    // 如果有 session cookie，不使用缓存
    if (request.headers.get('Cookie')?.includes('session_id')) {
      return fetch(request)
    }
    
    let response = await cache.match(cacheKey)
    if (!response) {
      response = await fetch(request)
      if (response.status === 200) {
        const headers = new Headers(response.headers)
        headers.set('Cache-Control', 'public, max-age=300')
        
        const newResponse = new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: headers
        })
        
        event.waitUntil(cache.put(cacheKey, newResponse.clone()))
        return newResponse
      }
    }
    return response
  }
  
  // 默认处理
  return fetch(request)
}
```

**部署 Worker：**

1. **创建 Worker**
   - 登录 Cloudflare 控制面板
   - 导航：Workers & Pages
   - 点击"创建应用程序"
   - 选择"创建 Worker"
   - 输入名称：`odoo-optimizer`

2. **编辑代码**
   - 点击"快速编辑"
   - 删除默认代码
   - 粘贴上述优化脚本
   - 点击"保存并部署"

3. **绑定到域名（重要）**
   - 返回 Workers & Pages 列表
   - 点击刚创建的 `odoo-optimizer`
   - 选择"触发器"标签
   - 点击"添加自定义域"
   - 输入您的域名：`www.example.com`（使用主域名）
   - 点击"添加自定义域"
   - 等待 DNS 验证完成（通常几分钟）

4. **验证 Worker 是否生效**
   ```bash
   # 检查响应头
   curl -I https://www.example.com/web/static/src/css/bootstrap.css
   
   # 应该看到 Worker 添加的缓存头
   # Cache-Control: public, max-age=31536000, immutable
   ```

5. **监控 Worker 性能**
   - 导航：Workers & Pages > odoo-optimizer > 指标
   - 查看：请求数、成功率、CPU 时间

**注意事项：**
- ✅ Worker 绑定到主域名后会自动拦截所有请求
- ✅ 免费版每天有 10 万次请求限制
- ✅ 超过限制后需要升级到付费版（$5/月）
- ⚠️ Worker 优先级高于页面规则，会覆盖页面规则的缓存设置
- ⚠️ 如果不需要 Worker，可以随时删除绑定

#### 6.5.7 性能监控

**启用 Web Analytics：**
- 导航：Cloudflare 控制面板 > 分析 > Web Analytics
- ✅ 启用
- 说明：查看页面加载时间、访问量等指标

**查看缓存分析：**
- 导航：Cloudflare 控制面板 > 缓存 > 分析
- 查看：缓存命中率、节省的带宽、请求数

**性能优化建议：**
```bash
# 测试网站速度
curl -w "@curl-format.txt" -o /dev/null -s https://www.example.com

# curl-format.txt 内容：
time_namelookup:  %{time_namelookup}\n
time_connect:  %{time_connect}\n
time_appconnect:  %{time_appconnect}\n
time_pretransfer:  %{time_pretransfer}\n
time_redirect:  %{time_redirect}\n
time_starttransfer:  %{time_starttransfer}\n
time_total:  %{time_total}\n
```

#### 6.5.8 性能优化总结

**免费功能（必须启用）：**
1. ✅ Auto Minify（JS/CSS/HTML）
2. ✅ Brotli 压缩
3. ✅ HTTP/3 (QUIC)
4. ✅ Argo Tiered Cache
5. ✅ 页面规则优化

**付费功能（推荐）：**
1. 💰 Argo Smart Routing（$5/月）
2. 💰 Polish 图片压缩（$20/月）
3. 💰 Workers（$5/月，10万请求免费）

**高级优化（可选）：**
1. ⚡ Workers 脚本
2. ⚡ 自定义缓存策略

**预期效果：**
- 页面加载速度提升 50-70%
- 带宽节省 60-80%
- 服务器负载降低 70-90%
- 缓存命中率达到 80%+

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

**配置 robots.txt（重要）：**

网站模式下，需要配置 robots.txt 来控制搜索引擎收录：

1. **允许收录网站，屏蔽后台（推荐）**
   - 导航: 网站 > 配置 > 设置 > SEO
   - 找到 "robots.txt" 设置
   - 添加以下内容：
   ```
   User-agent: *
   Disallow: /web/
   Disallow: /my/
   Disallow: /shop/checkout
   Disallow: /shop/cart
   Allow: /
   
   Sitemap: https://www.example.com/sitemap.xml
   ```

2. **验证配置**
   - 访问: `https://www.example.com/robots.txt`
   - 确认内容正确显示

**说明：**
- `Disallow: /web/` - 屏蔽后台管理页面
- `Disallow: /my/` - 屏蔽用户个人页面
- `Disallow: /shop/checkout` - 屏蔽结账页面
- `Disallow: /shop/cart` - 屏蔽购物车页面
- `Allow: /` - 允许收录其他所有页面
- `Sitemap` - 告诉搜索引擎网站地图位置

### 7.3 Odoo 安全设置

**启用双因素认证：**
- 导航: 设置 > 用户 > 选择用户
- 启用: 双因素认证

**设置密码策略：**
- 导航: 设置 > 技术 > 参数 > 系统参数
- 添加: `auth_password_policy.minlength = 12`

**会话超时设置：**
- 导航: 设置 > 技术 > 参数 > 系统参数
- 添加: `session_timeout = 3600`（1小时，单位：秒）

### 7.4 Odoo 数据库优化

**定期清理过期数据：**

1. **清理邮件日志**
   - 导航: 设置 > 技术 > 自动化 > 计划动作
   - 创建新动作：
     - 名称: 清理邮件日志
     - 模型: mail.mail
     - 执行: Python 代码
     - 代码:
       ```python
       # 删除30天前的已发送邮件
       old_mails = env['mail.mail'].search([
           ('state', '=', 'sent'),
           ('date', '<', (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d'))
       ])
       old_mails.unlink()
       ```
     - 间隔: 每天
     - 下次执行: 凌晨 2:00

2. **清理审计日志**
   - 导航: 设置 > 技术 > 自动化 > 计划动作
   - 创建新动作：
     - 名称: 清理审计日志
     - 模型: ir.logging
     - 执行: Python 代码
     - 代码:
       ```python
       # 删除90天前的日志
       old_logs = env['ir.logging'].search([
           ('create_date', '<', (datetime.now() - timedelta(days=90)).strftime('%Y-%m-%d'))
       ])
       old_logs.unlink()
       ```
     - 间隔: 每周
     - 下次执行: 周日凌晨 3:00

**数据库索引优化：**

定期在数据库中执行（已在第五部分配置）：
```bash
docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"
docker exec odoo-db psql -U odoo -c "VACUUM ANALYZE;"
```

### 7.5 Odoo 缓存优化

**启用资源缓存：**
- 导航: 设置 > 技术 > 参数 > 系统参数
- 添加或修改:
  - `web.assets.debug_mode = False`
  - `web.base.url = https://www.example.com`（设置正确的基础 URL）

**清理缓存（当更新模块后）：**
```bash
# 重启 Odoo 容器清理缓存
docker restart odoo

# 或在 Odoo 后台
# 导航: 设置 > 技术 > 数据库结构 > 清除资源
```

### 7.6 Odoo 模块优化

**禁用不需要的模块：**
- 导航: 应用 > 已安装
- 卸载不使用的模块（减少资源占用）
- 建议保留的核心模块：
  - base
  - web
  - mail
  - website（如果使用网站）

**推荐安装的性能优化模块：**
- `web_responsive` - 响应式界面优化
- `web_advanced_search` - 高级搜索优化
- `base_automation` - 自动化任务

### 7.7 Odoo 文件存储优化

**配置文件存储位置：**

确保 `odoo.conf` 中配置了正确的存储路径：
```ini
data_dir = /var/lib/odoo
```

**定期清理附件：**
```bash
# 查看附件占用空间
docker exec odoo-db psql -U odoo -c "
SELECT pg_size_pretty(sum(octet_length(datas))) as total_size 
FROM ir_attachment 
WHERE datas IS NOT NULL;"

# 清理未使用的附件（在 Odoo 后台执行）
# 导航: 设置 > 技术 > 附件
# 搜索并删除未关联的附件
```

### 7.8 Odoo 日志优化

**调整日志级别：**

编辑 `odoo.conf`：
```bash
nano /opt/odoo/config/odoo.conf
```

修改日志配置：
```ini
# 生产环境使用 info 级别
log_level = info

# 调试时可临时改为 debug
# log_level = debug

# 日志轮转
log_rotate = True
log_max_size = 100000000  # 100MB

# 日志处理器
log_handler = :INFO
```

重启容器：
```bash
docker restart odoo
```

### 7.9 Odoo 性能监控

**启用性能分析：**
- 导航: 设置 > 技术 > 参数 > 系统参数
- 添加: `profiling_enabled_until = 2026-12-31`（启用到指定日期）

**查看慢查询：**
```bash
# 在数据库中查看慢查询
docker exec odoo-db psql -U odoo -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"
```

**监控内存使用：**
```bash
# 查看 Odoo 容器内存使用
docker stats odoo --no-stream

# 如果内存使用率持续超过 80%，需要调整配置
```

### 7.10 Odoo 邮件服务优化

**配置外部邮件服务器（推荐）：**

使用外部邮件服务（如 Gmail、SendGrid、阿里云邮件）比自建邮件服务器更可靠。

1. **配置发件服务器**
   - 导航: 设置 > 技术 > 外发邮件服务器
   - 点击"创建"
   - 配置示例（Gmail）：
     ```
     描述: Gmail SMTP
     SMTP 服务器: smtp.gmail.com
     SMTP 端口: 587
     连接安全: TLS (STARTTLS)
     用户名: your-email@gmail.com
     密码: your-app-password
     ```
   - 点击"测试连接"验证配置

2. **配置收件服务器（可选）**
   - 导航: 设置 > 技术 > 收件邮件服务器
   - 配置 IMAP/POP3 服务器
   - 用于接收客户回复邮件

3. **邮件队列优化**
   
   编辑 `odoo.conf`：
   ```bash
   nano /opt/odoo/config/odoo.conf
   ```
   
   添加邮件配置：
   ```ini
   # 邮件发送优化
   email_from = noreply@example.com
   smtp_server = smtp.gmail.com
   smtp_port = 587
   smtp_user = your-email@gmail.com
   smtp_password = your-app-password
   smtp_ssl = False
   smtp_ssl_certificate_filename = False
   smtp_ssl_private_key_filename = False
   
   # 邮件队列优化
   max_cron_threads = 2
   ```

4. **邮件发送限流**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加: `mail.session.batch.size = 50`（每批发送50封）
   - 添加: `mail.bounce.alias = bounce`（退信处理）

**常用邮件服务配置：**

| 服务商 | SMTP 服务器 | 端口 | 安全 | 说明 |
|--------|-------------|------|------|------|
| Gmail | smtp.gmail.com | 587 | TLS | 需要应用专用密码 |
| Outlook | smtp.office365.com | 587 | TLS | 企业邮箱推荐 |
| 阿里云 | smtp.aliyun.com | 465 | SSL | 国内推荐 |
| SendGrid | smtp.sendgrid.net | 587 | TLS | 专业邮件服务 |
| 腾讯企业邮 | smtp.exmail.qq.com | 465 | SSL | 国内企业推荐 |

### 7.11 Odoo 多语言优化

**加载语言包：**
- 导航: 设置 > 翻译 > 加载翻译
- 选择需要的语言（如：简体中文）
- 点击"加载"

**设置默认语言：**
- 导航: 设置 > 用户 > 选择用户
- 修改"语言"字段

**翻译优化：**
- 导航: 设置 > 技术 > 参数 > 系统参数
- 添加: `web.base.url.freeze = True`（冻结基础 URL，提升多语言性能）

### 7.12 Odoo 定时任务优化

**查看和优化定时任务：**

1. **查看所有定时任务**
   - 导航: 设置 > 技术 > 自动化 > 计划动作
   - 查看所有自动执行的任务

2. **禁用不需要的任务**
   
   常见可禁用的任务（根据实际需求）：
   - `Mail: Email Queue Manager` - 如果不使用邮件功能
   - `Website: Update Visitor` - 如果不使用网站访客追踪
   - `IM: Bus Presence` - 如果不使用即时通讯
   - `Calendar: Reminder` - 如果不使用日历提醒

3. **调整任务执行频率**
   
   对于高频任务，可以降低执行频率：
   - `Mail: Fetch Mail` - 从每分钟改为每5分钟
   - `Base: Auto-vacuum` - 从每天改为每周

4. **优化 Cron Workers**
   
   编辑 `odoo.conf`：
   ```bash
   nano /opt/odoo/config/odoo.conf
   ```
   
   调整 cron 线程数：
   ```ini
   # Cron 优化（根据 CPU 核心数调整）
   max_cron_threads = 2    # 2核=1, 4核=2, 8核=4
   ```

### 7.13 Odoo 资产（Assets）优化

**启用资产压缩和合并：**

1. **后台配置**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 确认以下参数：
     ```
     web.assets.debug_mode = False
     web.assets.minimize = True
     ```

2. **清理旧资产**
   ```bash
   # 清理 Odoo 资产缓存
   docker exec odoo rm -rf /var/lib/odoo/sessions/*
   docker exec odoo rm -rf /var/lib/odoo/filestore/*/ir.attachment/*
   docker restart odoo
   ```

3. **资产 CDN 配置（可选）**
   
   如果使用 Cloudflare 或其他 CDN：
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加: `web.base.url.freeze = True`
   - 添加: `web.base.url = https://www.example.com`

### 7.14 Odoo API 限流和安全

**配置 API 访问限制：**

1. **启用 API 限流**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加: `api.rate_limit = 100`（每分钟100次请求）

2. **API 密钥管理**
   - 导航: 设置 > 用户 > 选择用户
   - 生成 API 密钥（用于外部集成）
   - 定期轮换 API 密钥

3. **禁用 XML-RPC（如果不使用）**
   
   编辑 `odoo.conf`：
   ```bash
   nano /opt/odoo/config/odoo.conf
   ```
   
   添加：
   ```ini
   # 禁用 XML-RPC（如果不需要外部 API 访问）
   xmlrpc = False
   xmlrpc_interface = 127.0.0.1
   ```

### 7.15 Odoo 会话管理优化

**优化会话存储：**

1. **Redis 会话配置（已在 3.3 节配置）**
   
   确认 `odoo.conf` 中已启用：
   ```ini
   session_redis = True
   redis_host = redis
   redis_port = 6379
   redis_dbindex = 1
   redis_pass = False
   ```

2. **会话超时设置**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加: `session_timeout = 3600`（1小时，单位：秒）
   - 管理系统模式建议: 1800秒（30分钟）
   - 网站模式建议: 3600秒（1小时）

3. **清理过期会话**
   ```bash
   # 手动清理 Redis 会话
   docker exec odoo-redis redis-cli FLUSHDB
   
   # 或创建定时任务自动清理
   nano /opt/odoo/scripts/clean_sessions.sh
   ```
   
   写入：
   ```bash
   #!/bin/bash
   # 清理过期的 Redis 会话
   docker exec odoo-redis redis-cli --scan --pattern "session:*" | \
   while read key; do
       ttl=$(docker exec odoo-redis redis-cli TTL "$key")
       if [ "$ttl" -eq -1 ]; then
           docker exec odoo-redis redis-cli DEL "$key"
       fi
   done
   echo "$(date): 会话清理完成" >> /var/log/odoo_session_clean.log
   ```
   
   设置定时任务：
   ```bash
   chmod +x /opt/odoo/scripts/clean_sessions.sh
   (crontab -l 2>/dev/null; echo "0 3 * * * /opt/odoo/scripts/clean_sessions.sh") | crontab -
   ```

### 7.16 Odoo 附件存储优化

**配置对象存储（高级，可选）：**

对于大量文件存储，可以使用对象存储服务（如阿里云 OSS、AWS S3）：

1. **安装对象存储模块**
   ```bash
   # 下载对象存储模块（示例）
   cd /opt/odoo/addons
   git clone https://github.com/OCA/storage.git
   docker restart odoo
   ```

2. **配置对象存储**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加对象存储配置（根据具体模块文档）

3. **本地存储优化**
   
   如果使用本地存储，定期清理：
   ```bash
   # 查看附件存储大小
   du -sh /opt/odoo/data/filestore/
   
   # 清理缩略图缓存
   find /opt/odoo/data/filestore/ -name "*_thumbnail_*" -mtime +30 -delete
   ```

### 7.17 Odoo 报表性能优化

**优化 PDF 生成：**

1. **安装 wkhtmltopdf（已在系统中）**
   ```bash
   # 验证 wkhtmltopdf 是否可用
   docker exec odoo which wkhtmltopdf
   ```

2. **配置报表缓存**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加: `report.cache = True`（启用报表缓存）

3. **异步生成报表（大型报表）**
   - 对于大型报表，使用后台任务生成
   - 导航: 设置 > 技术 > 自动化 > 计划动作
   - 创建定时生成报表的任务

### 7.18 Odoo 搜索性能优化

**优化全文搜索：**

1. **启用 PostgreSQL 全文搜索**
   ```bash
   # 进入数据库
   docker exec -it odoo-db psql -U odoo
   ```
   
   执行：
   ```sql
   -- 创建全文搜索索引（示例：产品名称）
   CREATE INDEX CONCURRENTLY idx_product_name_fts 
   ON product_template 
   USING gin(to_tsvector('english', name));
   
   -- 创建全文搜索索引（示例：客户名称）
   CREATE INDEX CONCURRENTLY idx_partner_name_fts 
   ON res_partner 
   USING gin(to_tsvector('english', name));
   
   \q
   ```

2. **配置搜索限制**
   - 导航: 设置 > 技术 > 参数 > 系统参数
   - 添加: `web.search.limit = 80`（搜索结果限制）

### 7.19 Odoo 开发者模式管理

**生产环境禁用开发者模式：**

1. **检查开发者模式状态**
   - 导航: 设置
   - 查看右下角是否显示"开发者模式"

2. **禁用开发者模式**
   - 如果启用了开发者模式，点击"停用开发者模式"
   - 或通过 URL: `https://www.example.com/web?debug=0`

3. **限制开发者模式访问**
   - 导航: 设置 > 用户 > 组
   - 创建"开发者"组
   - 只给必要的用户分配此组
   - 配置系统参数: `base.group_no_one = developer_group`

### 7.20 Odoo 系统优化总结

**必须配置的优化（优先级高）：**
1. ✅ 数据库过滤器（dbfilter）
2. ✅ 禁用数据库列表（list_db = False）
3. ✅ Redis 会话管理
4. ✅ 资产压缩和合并
5. ✅ 日志级别设置（info）
6. ✅ 会话超时设置

**推荐配置的优化（优先级中）：**
1. ✅ 邮件服务器配置
2. ✅ 定时任务优化
3. ✅ 定期清理过期数据
4. ✅ 数据库索引优化
5. ✅ 禁用不需要的模块
6. ✅ 生产环境禁用开发者模式

**可选配置的优化（根据需求）：**
1. ⚪ 对象存储配置
2. ⚪ API 限流
3. ⚪ 多语言优化
4. ⚪ 全文搜索优化
5. ⚪ 报表缓存

**性能监控指标：**
- 响应时间: < 500ms（正常页面）
- 数据库查询: < 100ms（单次查询）
- 内存使用: < 80%（容器内存）
- CPU 使用: < 70%（平均负载）
- 会话数: 根据 VPS 配置调整

**定期维护任务：**
- 每天: 清理邮件日志、监控系统资源
- 每周: 数据库 VACUUM、清理审计日志
- 每月: 清理附件、更新索引、检查慢查询
- 每季度: 审查定时任务、优化数据库、更新模块

---

## 第八部分：数据备份

### 8.1 完整备份脚本

**创建备份脚本：**
```bash
mkdir -p /opt/odoo/scripts
nano /opt/odoo/scripts/backup.sh
```

**写入以下内容：**
```bash
#!/bin/bash
# Odoo 完整备份脚本

BACKUP_DIR="/opt/odoo/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# 创建备份目录
mkdir -p "$BACKUP_DIR"

echo "$(date): 开始备份..."

# 1. 数据库备份（压缩格式）
echo "备份数据库..."
docker exec odoo-db pg_dump -U odoo -Fc odoo > "$BACKUP_DIR/odoo_db_$DATE.dump"

if [ $? -eq 0 ]; then
    echo "数据库备份成功: odoo_db_$DATE.dump"
else
    echo "数据库备份失败！"
    exit 1
fi

# 2. 文件存储备份
echo "备份文件存储..."
tar -czf "$BACKUP_DIR/odoo_filestore_$DATE.tar.gz" -C /opt/odoo data

if [ $? -eq 0 ]; then
    echo "文件存储备份成功: odoo_filestore_$DATE.tar.gz"
else
    echo "文件存储备份失败！"
    exit 1
fi

# 3. 配置文件备份
echo "备份配置文件..."
tar -czf "$BACKUP_DIR/odoo_config_$DATE.tar.gz" -C /opt/odoo config addons

if [ $? -eq 0 ]; then
    echo "配置文件备份成功: odoo_config_$DATE.tar.gz"
else
    echo "配置文件备份失败！"
fi

# 4. 清理旧备份（保留最近 N 天）
echo "清理 $RETENTION_DAYS 天前的旧备份..."
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# 5. 显示备份信息
echo "当前备份列表："
ls -lh "$BACKUP_DIR" | tail -10

echo "$(date): 备份完成！"
```

**设置执行权限并测试：**
```bash
chmod +x /opt/odoo/scripts/backup.sh

# 测试备份脚本
/opt/odoo/scripts/backup.sh
```

### 8.2 自动备份定时任务

**设置每天凌晨 2 点自动备份：**
```bash
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/odoo/scripts/backup.sh >> /var/log/odoo_backup.log 2>&1") | crontab -
```

**查看定时任务：**
```bash
crontab -l
```

**查看备份日志：**
```bash
tail -f /var/log/odoo_backup.log
```

### 8.3 数据恢复

**恢复数据库：**
```bash
# 1. 停止 Odoo 容器
docker stop odoo

# 2. 删除旧数据库（可选，谨慎操作）
docker exec odoo-db psql -U odoo -c "DROP DATABASE IF EXISTS odoo;"
docker exec odoo-db psql -U odoo -c "CREATE DATABASE odoo OWNER odoo;"

# 3. 恢复数据库
docker exec -i odoo-db pg_restore -U odoo -d odoo < /opt/odoo/backups/odoo_db_20260113_020000.dump

# 4. 启动 Odoo 容器
docker start odoo
```

**恢复文件存储：**
```bash
# 1. 停止 Odoo 容器
docker stop odoo

# 2. 备份当前数据（以防万一）
mv /opt/odoo/data /opt/odoo/data.old

# 3. 解压备份文件
tar -xzf /opt/odoo/backups/odoo_filestore_20260113_020000.tar.gz -C /opt/odoo

# 4. 启动 Odoo 容器
docker start odoo
```

### 8.4 远程备份（推荐）

**使用 rsync 同步到远程服务器：**
```bash
# 安装 rsync
sudo apt install -y rsync

# 创建远程备份脚本
nano /opt/odoo/scripts/remote_backup.sh
```

写入：
```bash
#!/bin/bash
# 远程备份脚本

REMOTE_USER="backup_user"
REMOTE_HOST="backup.example.com"
REMOTE_DIR="/backups/odoo"
LOCAL_DIR="/opt/odoo/backups"

echo "$(date): 开始远程同步..."

# 使用 rsync 同步到远程服务器
rsync -avz --delete \
    -e "ssh -i ~/.ssh/backup_key" \
    "$LOCAL_DIR/" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

if [ $? -eq 0 ]; then
    echo "$(date): 远程同步成功"
else
    echo "$(date): 远程同步失败"
    exit 1
fi
```

设置定时任务（每天凌晨 3 点）：
```bash
chmod +x /opt/odoo/scripts/remote_backup.sh
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/odoo/scripts/remote_backup.sh >> /var/log/odoo_remote_backup.log 2>&1") | crontab -
```

### 8.5 系统监控命令

以下命令可以帮助您随时查看系统状态：

**查看系统资源：**
```bash
# CPU 使用率
top -bn1 | grep "Cpu(s)"

# 内存使用情况
free -h

# 磁盘使用情况
df -h

# 实时监控（需要安装 htop）
htop
```

**查看容器状态：**
```bash
# 查看所有容器
docker ps -a

# 查看容器资源使用
docker stats

# 查看特定容器资源
docker stats odoo odoo-db odoo-redis --no-stream
```

**查看数据库状态：**
```bash
# 数据库连接数
docker exec odoo-db psql -U odoo -c "SELECT count(*) FROM pg_stat_activity;"

# 数据库大小
docker exec odoo-db psql -U odoo -c "SELECT pg_size_pretty(pg_database_size('odoo'));"

# 表大小排行
docker exec odoo-db psql -U odoo -c "
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;"
```

**查看网络状态：**
```bash
# 查看端口监听
ss -tlnp

# 查看网络连接
netstat -an | grep ESTABLISHED | wc -l
```

---

## 第九部分：日志分析与问题诊断

### 9.1 日志文件位置

**主要日志文件：**
```
/opt/odoo/data/odoo.log              # Odoo 应用日志
/var/log/nginx/access.log            # Nginx 访问日志
/var/log/nginx/error.log             # Nginx 错误日志
/var/log/odoo_backup.log             # 备份日志
/var/log/odoo_maintenance.log        # 维护日志
```

**Docker 容器日志：**
```bash
# 查看容器日志
docker logs odoo
docker logs odoo-db
docker logs odoo-redis

# 实时查看日志
docker logs -f odoo

# 查看最近 100 行
docker logs --tail 100 odoo
```

### 9.2 Odoo 日志分析

**查看 Odoo 日志：**
```bash
# 实时查看日志
tail -f /opt/odoo/data/odoo.log

# 查看最近 100 行
tail -100 /opt/odoo/data/odoo.log

# 查看特定时间段的日志
grep "2026-01-13" /opt/odoo/data/odoo.log
```

**常见错误分析：**

**1. 数据库连接错误**
```bash
# 搜索数据库连接错误
grep -i "could not connect" /opt/odoo/data/odoo.log

# 常见原因：
# - 数据库容器未启动
# - 数据库密码错误
# - 网络配置问题

# 解决方法：
docker ps | grep odoo-db                    # 检查数据库容器状态
docker logs odoo-db                         # 查看数据库日志
docker exec odoo ping db                    # 测试网络连接
```

**2. 内存不足错误**
```bash
# 搜索内存错误
grep -i "memory" /opt/odoo/data/odoo.log
grep -i "MemoryError" /opt/odoo/data/odoo.log

# 查看内存使用
docker stats odoo --no-stream

# 解决方法：
# - 增加容器内存限制（docker-compose.yml）
# - 减少 workers 数量（odoo.conf）
# - 优化数据库查询
```

**3. 权限错误**
```bash
# 搜索权限错误
grep -i "permission denied" /opt/odoo/data/odoo.log

# 解决方法：
sudo chown -R 101:101 /opt/odoo/data
docker restart odoo
```

**4. 模块加载错误**
```bash
# 搜索模块错误
grep -i "module.*error" /opt/odoo/data/odoo.log

# 查看模块依赖
docker exec odoo odoo --version

# 解决方法：
# - 检查模块依赖
# - 更新模块列表
# - 重新安装模块
```

**5. 慢查询分析**
```bash
# 搜索慢查询（超过 1 秒）
grep "query took" /opt/odoo/data/odoo.log | awk '$NF > 1'

# 查看数据库慢查询
docker exec odoo-db psql -U odoo -c "
SELECT query, calls, total_time, mean_time, max_time
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"
```

### 9.3 Nginx 日志分析

**访问日志分析：**
```bash
# 查看访问日志
tail -f /var/log/nginx/access.log

# 统计访问量最多的 IP
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# 统计访问量最多的 URL
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# 统计 HTTP 状态码
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# 统计响应时间（需要配置 $request_time）
awk '{print $NF}' /var/log/nginx/access.log | sort -n | tail -20

# 查找 404 错误
grep " 404 " /var/log/nginx/access.log | tail -20

# 查找 500 错误
grep " 50[0-9] " /var/log/nginx/access.log | tail -20
```

**错误日志分析：**
```bash
# 查看错误日志
tail -f /var/log/nginx/error.log

# 统计错误类型
grep "error" /var/log/nginx/error.log | awk '{print $8}' | sort | uniq -c | sort -rn

# 查找上游服务器错误
grep "upstream" /var/log/nginx/error.log | tail -20

# 查找超时错误
grep "timeout" /var/log/nginx/error.log | tail -20
```

### 9.4 数据库日志分析

**查看 PostgreSQL 日志：**
```bash
# 进入数据库容器查看日志
docker exec odoo-db cat /var/log/postgresql/postgresql-15-main.log

# 查看当前连接
docker exec odoo-db psql -U odoo -c "
SELECT pid, usename, application_name, client_addr, state, query
FROM pg_stat_activity 
WHERE datname = 'odoo';"

# 查看锁等待
docker exec odoo-db psql -U odoo -c "
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.query AS blocked_query,
       blocking_activity.query AS blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;"

# 查看表膨胀
docker exec odoo-db psql -U odoo -c "
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
       pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;"
```

### 9.5 系统日志分析

**查看系统日志：**
```bash
# 查看系统日志
sudo journalctl -xe

# 查看 Docker 服务日志
sudo journalctl -u docker

# 查看 Nginx 服务日志
sudo journalctl -u nginx

# 查看最近的错误
sudo journalctl -p err -b
```

### 9.6 性能问题诊断

**CPU 使用率过高：**
```bash
# 查看 CPU 使用率
top -bn1 | head -20

# 查看进程 CPU 使用
ps aux --sort=-%cpu | head -10

# 查看容器 CPU 使用
docker stats --no-stream

# 诊断步骤：
# 1. 检查是否有慢查询
# 2. 检查 workers 数量是否过多
# 3. 检查是否有死循环或无限递归
# 4. 检查定时任务是否过于频繁
```

**内存使用率过高：**
```bash
# 查看内存使用
free -h

# 查看进程内存使用
ps aux --sort=-%mem | head -10

# 查看容器内存使用
docker stats --no-stream

# 诊断步骤：
# 1. 检查是否有内存泄漏
# 2. 检查 limit_memory_soft/hard 设置
# 3. 检查数据库缓存配置
# 4. 检查是否有大量会话未释放
```

**磁盘空间不足：**
```bash
# 查看磁盘使用
df -h

# 查看目录大小
du -sh /opt/odoo/*
du -sh /var/log/*
du -sh /var/lib/docker/*

# 清理方法：
# 1. 清理旧日志
sudo truncate -s 0 /var/log/nginx/*.log
find /opt/odoo/data -name "*.log" -mtime +30 -delete

# 2. 清理 Docker 资源
docker system prune -a

# 3. 清理旧备份
find /opt/odoo/backups -mtime +7 -delete

# 4. 清理数据库
docker exec odoo-db psql -U odoo -c "VACUUM FULL;"
```

**网络连接问题：**
```bash
# 测试网络连接
ping -c 4 8.8.8.8

# 测试 DNS 解析
nslookup example.com

# 查看网络连接数
netstat -an | grep ESTABLISHED | wc -l

# 查看端口监听
ss -tlnp

# 测试 Odoo 端口
curl -I http://localhost:8069

# 测试 Nginx
curl -I http://localhost
```

### 9.7 日志清理与轮转

**手动清理日志：**
```bash
# 清理 Nginx 日志
sudo truncate -s 0 /var/log/nginx/access.log
sudo truncate -s 0 /var/log/nginx/error.log

# 清理 Odoo 日志（保留最近 1000 行）
tail -1000 /opt/odoo/data/odoo.log > /tmp/odoo.log.tmp
mv /tmp/odoo.log.tmp /opt/odoo/data/odoo.log

# 清理 Docker 日志
docker exec odoo truncate -s 0 /var/lib/odoo/odoo.log
```

**配置日志轮转：**
```bash
# 创建 logrotate 配置
sudo nano /etc/logrotate.d/odoo
```

写入：
```
/opt/odoo/data/odoo.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker restart odoo > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 www-data www-data
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
```

测试配置：
```bash
sudo logrotate -d /etc/logrotate.d/odoo
```

---

## 第十部分：常用运维命令速查


### 10.1 容器管理命令

```bash
# 查看所有容器状态
docker ps -a

# 查看运行中的容器
docker ps

# 启动所有服务
cd /opt/odoo && docker-compose up -d

# 停止所有服务
cd /opt/odoo && docker-compose down

# 重启特定容器
docker restart odoo
docker restart odoo-db
docker restart odoo-redis

# 重启所有服务
cd /opt/odoo && docker-compose restart

# 查看容器日志
docker logs odoo
docker logs -f odoo              # 实时查看
docker logs --tail 100 odoo      # 查看最近 100 行

# 进入容器
docker exec -it odoo bash
docker exec -it odoo-db bash

# 更新镜像
cd /opt/odoo
docker-compose pull
docker-compose up -d

# 清理未使用的资源
docker system prune -a
```

### 10.2 数据库管理命令

```bash
# 进入数据库
docker exec -it odoo-db psql -U odoo

# 查看数据库大小
docker exec odoo-db psql -U odoo -c "SELECT pg_size_pretty(pg_database_size('odoo'));"

# 查看表大小
docker exec odoo-db psql -U odoo -c "
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"

# 查看连接数
docker exec odoo-db psql -U odoo -c "SELECT count(*) FROM pg_stat_activity;"

# 数据库备份
docker exec odoo-db pg_dump -U odoo -Fc odoo > backup_$(date +%Y%m%d).dump

# 数据库恢复
docker stop odoo
docker exec -i odoo-db pg_restore -U odoo -d odoo < backup_20260113.dump
docker start odoo

# 数据库优化
docker exec odoo-db psql -U odoo -c "VACUUM ANALYZE;"
docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"

# 查看慢查询
docker exec odoo-db psql -U odoo -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 10;"
```

### 10.3 Nginx 管理命令

```bash
# 检查配置
sudo nginx -t

# 重载配置（不中断服务）
sudo systemctl reload nginx

# 重启 Nginx
sudo systemctl restart nginx

# 查看状态
sudo systemctl status nginx

# 查看访问日志
sudo tail -f /var/log/nginx/access.log

# 查看错误日志
sudo tail -f /var/log/nginx/error.log

# 统计访问量
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# 查看 404 错误
grep " 404 " /var/log/nginx/access.log | tail -20

# 查看 500 错误
grep " 50[0-9] " /var/log/nginx/access.log | tail -20
```

### 10.4 系统资源监控命令

```bash
# 查看 CPU 使用率
top -bn1 | head -20
htop                    # 交互式查看

# 查看内存使用
free -h

# 查看磁盘使用
df -h
du -sh /opt/odoo/*

# 查看网络连接
ss -tlnp
netstat -an | grep ESTABLISHED | wc -l

# 查看进程
ps aux --sort=-%cpu | head -10    # CPU 占用最高
ps aux --sort=-%mem | head -10    # 内存占用最高

# 查看容器资源
docker stats
docker stats --no-stream
```

### 10.5 防火墙与安全命令

```bash
# 查看防火墙状态
sudo ufw status

# 查看 Fail2Ban 状态
sudo fail2ban-client status
sudo fail2ban-client status odoo

# 解封 IP
sudo fail2ban-client set odoo unbanip 192.168.1.100

# 查看被封禁的 IP
sudo fail2ban-client status odoo | grep "Banned IP"

# 查看 SSH 登录日志
sudo tail -f /var/log/auth.log
```

### 10.6 SSL 证书管理命令

```bash
# 查看证书信息
sudo certbot certificates

# 手动续期证书
sudo certbot renew

# 测试续期（不实际执行）
sudo certbot renew --dry-run

# 查看证书过期时间
echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates

# 强制续期
sudo certbot renew --force-renewal
```

### 10.7 备份与恢复命令

```bash
# 手动执行备份
/opt/odoo/scripts/backup.sh

# 查看备份文件
ls -lh /opt/odoo/backups/

# 查看备份日志
tail -f /var/log/odoo_backup.log

# 完整恢复流程
docker stop odoo
docker exec -i odoo-db pg_restore -U odoo -d odoo < /opt/odoo/backups/odoo_db_20260113_020000.dump
tar -xzf /opt/odoo/backups/odoo_filestore_20260113_020000.tar.gz -C /opt/odoo
docker start odoo
```

### 10.8 定时任务管理命令

```bash
# 查看当前用户的定时任务
crontab -l

# 编辑定时任务
crontab -e

# 查看定时任务日志
grep CRON /var/log/syslog

# 查看备份任务日志
tail -f /var/log/odoo_backup.log

# 查看维护任务日志
tail -f /var/log/odoo_maintenance.log
```

### 10.9 快速问题诊断命令

```bash
# 一键检查系统状态
cat << 'EOF' > /tmp/check_odoo.sh
#!/bin/bash
echo "=== Odoo 系统状态检查 ==="
echo ""
echo "1. 容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "2. 系统资源:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
echo "内存: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "磁盘: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo ""
echo "3. 容器资源:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""
echo "4. 数据库连接:"
docker exec odoo-db psql -U odoo -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | grep -E "^\s+[0-9]+"
echo ""
echo "5. Nginx 状态:"
sudo systemctl is-active nginx
echo ""
echo "6. 最近错误 (Odoo):"
tail -20 /opt/odoo/data/odoo.log | grep -i error | tail -5
echo ""
echo "7. 最近错误 (Nginx):"
sudo tail -20 /var/log/nginx/error.log | tail -5
EOF

chmod +x /tmp/check_odoo.sh
/tmp/check_odoo.sh
```

### 10.10 常用故障排查流程

**问题 1：网站无法访问**
```bash
# 1. 检查 Nginx 状态
sudo systemctl status nginx

# 2. 检查 Nginx 配置
sudo nginx -t

# 3. 检查 Odoo 容器
docker ps | grep odoo

# 4. 查看 Odoo 日志
docker logs --tail 50 odoo

# 5. 查看 Nginx 错误日志
sudo tail -50 /var/log/nginx/error.log

# 6. 测试端口
curl -I http://localhost:8069
curl -I http://localhost
```

**问题 2：性能缓慢**
```bash
# 1. 检查系统资源
docker stats --no-stream

# 2. 检查慢查询
docker exec odoo-db psql -U odoo -c "
SELECT query, calls, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 5;"

# 3. 检查数据库大小
docker exec odoo-db psql -U odoo -c "SELECT pg_size_pretty(pg_database_size('odoo'));"

# 4. 优化数据库
docker exec odoo-db psql -U odoo -c "VACUUM ANALYZE;"

# 5. 重启服务
docker restart odoo
```

**问题 3：数据库连接失败**
```bash
# 1. 检查数据库容器
docker ps | grep odoo-db

# 2. 测试数据库连接
docker exec odoo-db pg_isready -U odoo

# 3. 查看数据库日志
docker logs --tail 50 odoo-db

# 4. 测试网络连接
docker exec odoo ping db

# 5. 重启数据库
docker restart odoo-db
docker restart odoo
```

**问题 4：内存不足**
```bash
# 1. 查看内存使用
free -h
docker stats --no-stream

# 2. 查看进程内存
ps aux --sort=-%mem | head -10

# 3. 调整配置
nano /opt/odoo/config/odoo.conf
# 减少 workers 数量
# 减少 limit_memory_soft/hard

# 4. 重启服务
docker restart odoo
```

---

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
