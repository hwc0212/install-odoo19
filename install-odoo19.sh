#!/bin/bash

# Odoo 19 生产环境自动部署脚本
# 作者: huwencai.com
# GitHub: https://github.com/hwc0212/install-odoo19
# 适用系统: Ubuntu 24.04 LTS
# 更新日期: 2026年1月14日
# 版本: v2.0.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本！"
        log_info "请先创建非root用户并配置sudo权限"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "24.04" ]]; then
        log_error "此脚本仅支持 Ubuntu 24.04 LTS"
        log_info "当前系统: $PRETTY_NAME"
        exit 1
    fi
    
    log_info "系统检查通过: $PRETTY_NAME"
}

# 检查系统资源
check_resources() {
    local cpu_cores=$(nproc)
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    
    log_info "系统资源检查:"
    log_info "  CPU 核心数: $cpu_cores"
    log_info "  内存大小: ${memory_gb}GB"
    
    if [[ $cpu_cores -lt 2 ]] || [[ $memory_gb -lt 3 ]]; then
        log_warn "系统资源可能不足，建议至少2核4GB"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}
# 配置变量收集
collect_config() {
    log_step "配置信息收集"
    
    echo "Odoo 19 部署模式说明:"
    echo "1. 不输入域名 → IP访问（管理系统模式）"
    echo "2. 输入二级域名（如 erp.example.com）→ 管理系统模式"
    echo "3. 输入主域名（如 example.com 或 www.example.com）→ 网站模式"
    echo
    
    # 域名配置
    read -p "请输入域名（直接回车使用IP访问）: " DOMAIN_INPUT
    
    if [[ -z "$DOMAIN_INPUT" ]]; then
        # 不输入域名 - IP访问模式
        DEPLOY_TYPE="ip"
        log_info "选择: IP访问模式（管理系统）"
        
    elif [[ "$DOMAIN_INPUT" =~ ^www\. ]]; then
        # 输入www域名 - 网站模式，www为默认
        DEPLOY_TYPE="website"
        WWW_DOMAIN="$DOMAIN_INPUT"
        MAIN_DOMAIN="${DOMAIN_INPUT#www.}"  # 去掉www前缀
        DEFAULT_DOMAIN="$WWW_DOMAIN"
        REDIRECT_FROM="$MAIN_DOMAIN"
        REDIRECT_TO="$WWW_DOMAIN"
        log_info "选择: 网站模式"
        log_info "默认域名: $DEFAULT_DOMAIN"
        log_info "跳转规则: $REDIRECT_FROM → $REDIRECT_TO"
        
    elif [[ "$DOMAIN_INPUT" =~ \. ]] && [[ ! "$DOMAIN_INPUT" =~ ^www\. ]]; then
        # 判断是主域名还是二级域名
        local domain_parts=$(echo "$DOMAIN_INPUT" | tr '.' '\n' | wc -l)
        
        if [[ $domain_parts -eq 2 ]]; then
            # 主域名（如 example.com）- 网站模式，主域名为默认
            DEPLOY_TYPE="website"
            MAIN_DOMAIN="$DOMAIN_INPUT"
            WWW_DOMAIN="www.$DOMAIN_INPUT"
            DEFAULT_DOMAIN="$MAIN_DOMAIN"
            REDIRECT_FROM="$WWW_DOMAIN"
            REDIRECT_TO="$MAIN_DOMAIN"
            log_info "选择: 网站模式"
            log_info "默认域名: $DEFAULT_DOMAIN"
            log_info "跳转规则: $REDIRECT_FROM → $REDIRECT_TO"
        else
            # 二级域名（如 erp.example.com）- 管理系统模式
            DEPLOY_TYPE="admin"
            ADMIN_DOMAIN="$DOMAIN_INPUT"
            log_info "选择: 管理系统模式"
            log_info "管理域名: $ADMIN_DOMAIN"
        fi
    else
        log_error "域名格式不正确"
        exit 1
    fi
    
    # 数据库配置
    read -p "请输入数据库密码: " -s DB_PASSWORD
    echo
    if [[ -z "$DB_PASSWORD" ]]; then
        log_error "数据库密码不能为空"
        exit 1
    fi
    
    read -p "请输入Odoo管理员密码: " -s ADMIN_PASSWORD
    echo
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        log_error "管理员密码不能为空"
        exit 1
    fi
    
    # 自动计算资源配置
    CPU_CORES=$(nproc)
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    WORKERS=$((CPU_CORES * 2 + 1))
    ODOO_MEMORY=$((MEMORY_GB * 50 / 100))
    PG_SHARED_BUFFERS=$((MEMORY_GB * 25 / 100))
    PG_EFFECTIVE_CACHE=$((MEMORY_GB * 75 / 100))
    
    # 根据CPU核心数计算work_mem
    if [[ $CPU_CORES -le 2 ]]; then
        PG_WORK_MEM="32MB"
    elif [[ $CPU_CORES -le 4 ]]; then
        PG_WORK_MEM="64MB"
    else
        PG_WORK_MEM="128MB"
    fi
    
    # 根据并发量计算Redis内存
    if [[ $MEMORY_GB -le 4 ]]; then
        REDIS_MEMORY="256mb"
    elif [[ $MEMORY_GB -le 8 ]]; then
        REDIS_MEMORY="512mb"
    elif [[ $MEMORY_GB -le 16 ]]; then
        REDIS_MEMORY="1gb"
    else
        REDIS_MEMORY="2gb"
    fi
    
    # 计算内存限制（字节）
    ODOO_MEMORY_SOFT=$((ODOO_MEMORY * 1024 * 1024 * 1024))
    ODOO_MEMORY_HARD=$((ODOO_MEMORY_SOFT * 5 / 4))
    
    log_info "自动计算的资源配置:"
    log_info "  CPU核心数: $CPU_CORES"
    log_info "  总内存: ${MEMORY_GB}GB"
    log_info "  Workers: $WORKERS"
    log_info "  Odoo内存限制: ${ODOO_MEMORY}GB (soft) / $((ODOO_MEMORY * 5 / 4))GB (hard)"
    log_info "  PostgreSQL shared_buffers: ${PG_SHARED_BUFFERS}GB"
    log_info "  PostgreSQL effective_cache_size: ${PG_EFFECTIVE_CACHE}GB"
    log_info "  PostgreSQL work_mem: $PG_WORK_MEM"
    log_info "  Redis maxmemory: $REDIS_MEMORY"
}

# 系统优化
optimize_system() {
    log_step "系统性能优化"
    
    # 更新系统
    log_info "更新系统包..."
    sudo apt update && sudo apt upgrade -y
    
    # 安装必要软件
    log_info "安装必要软件..."
    sudo apt install -y curl wget git ufw fail2ban build-essential \
        libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
        libssl-dev nginx certbot python3-certbot-nginx htop
    
    # 优化文件句柄限制
    log_info "优化系统参数..."
    sudo tee -a /etc/security/limits.conf > /dev/null << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
    
    # 优化内核参数
    sudo tee -a /etc/sysctl.conf > /dev/null << EOF

# Odoo 优化参数
fs.file-max = 2097152
fs.nr_open = 2097152
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 65535
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    sudo sysctl -p
}
# 配置防火墙
setup_firewall() {
    log_step "配置防火墙"
    
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow OpenSSH
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw deny 8069
    sudo ufw deny 5432
    sudo ufw deny 6379
    
    echo "y" | sudo ufw enable
    log_info "防火墙配置完成"
}

# 安装Docker
install_docker() {
    log_step "安装Docker"
    
    if command -v docker &> /dev/null; then
        log_info "Docker已安装，跳过..."
        return
    fi
    
    sudo apt install -y docker.io docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    # 配置Docker daemon
    sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    
    sudo systemctl restart docker
    log_info "Docker安装完成"
}

# 创建目录结构
create_directories() {
    log_step "创建目录结构"
    
    sudo mkdir -p /opt/odoo/{data,addons,pgdata,redis,config}
    sudo chown -R $USER:$USER /opt/odoo
    
    log_info "目录结构创建完成"
}

# 生成配置文件
generate_configs() {
    log_step "生成配置文件"
    
    # 生成odoo.conf
    cat > /opt/odoo/config/odoo.conf << EOF
[options]
# 数据库配置
db_host = db
db_port = 5432
db_user = odoo
db_password = $DB_PASSWORD

# 基础配置
addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons
data_dir = /var/lib/odoo

# 安全配置
proxy_mode = True
list_db = False
admin_passwd = $ADMIN_PASSWORD

# 性能配置
workers = $WORKERS
max_cron_threads = 2
limit_time_cpu = 60
limit_time_real = 120
limit_memory_soft = $ODOO_MEMORY_SOFT
limit_memory_hard = $ODOO_MEMORY_HARD

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
EOF
    # 生成postgresql.conf
    cat > /opt/odoo/config/postgresql.conf << EOF
# PostgreSQL 15 优化配置
max_connections = 200
shared_buffers = ${PG_SHARED_BUFFERS}GB
effective_cache_size = ${PG_EFFECTIVE_CACHE}GB
work_mem = $PG_WORK_MEM
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
EOF

    # 生成redis.conf
    cat > /opt/odoo/config/redis.conf << EOF
bind 0.0.0.0
port 6379
timeout 300
maxmemory $REDIS_MEMORY
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
loglevel notice
maxclients 10000
protected-mode no
EOF

    # 生成docker-compose.yml
    cat > /opt/odoo/docker-compose.yml << EOF
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
      - PASSWORD=$DB_PASSWORD
    volumes:
      - ./data:/var/lib/odoo
      - ./addons:/mnt/extra-addons
      - ./config/odoo.conf:/etc/odoo/odoo.conf:ro
    networks:
      - odoo-net
    deploy:
      resources:
        limits:
          cpus: "$((CPU_CORES * 50 / 100))"
          memory: "${ODOO_MEMORY}G"
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
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_USER=odoo
      - POSTGRES_DB=postgres
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    networks:
      - odoo-net
    command: >
      postgres
      -c shared_buffers=${PG_SHARED_BUFFERS}GB
      -c effective_cache_size=${PG_EFFECTIVE_CACHE}GB
      -c work_mem=$PG_WORK_MEM
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
    command: redis-server /usr/local/etc/redis/redis.conf

networks:
  odoo-net:
    driver: bridge
EOF

    log_info "配置文件生成完成"
}
# 生成Nginx配置
generate_nginx_config() {
    log_step "生成Nginx配置"
    
    sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    
    if [[ "$DEPLOY_TYPE" == "ip" ]] || [[ "$DEPLOY_TYPE" == "admin" ]]; then
        # IP访问或管理系统配置
        local server_name
        if [[ "$DEPLOY_TYPE" == "ip" ]]; then
            server_name="$(hostname -I | awk '{print $1}') _"
        else
            server_name="$ADMIN_DOMAIN"
        fi
        
        sudo tee /etc/nginx/sites-available/odoo-admin.conf > /dev/null << EOF
server {
    listen 80;
    server_name $server_name;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $server_name;

    ssl_certificate /etc/ssl/certs/odoo-admin.crt;
    ssl_certificate_key /etc/ssl/private/odoo-admin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # 屏蔽搜索引擎
    location = /robots.txt {
        default_type text/plain;
        return 200 "User-agent: *\\nDisallow: /\\n";
    }

    # 禁止访问数据库管理界面
    location ~* ^/web/database/(manager|selector) {
        deny all;
        return 403;
    }

    location / {
        # 阻止爬虫
        if (\$http_user_agent ~* (bot|spider|crawler|scraper)) {
            return 403;
        }

        proxy_pass http://localhost:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }

    # 安全头
    add_header X-Robots-Tag "noindex, nofollow" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
}
EOF
        
        sudo ln -sf /etc/nginx/sites-available/odoo-admin.conf /etc/nginx/sites-enabled/
    fi
    
    if [[ "$DEPLOY_TYPE" == "website" ]]; then
        # 网站配置 - 根据用户输入决定跳转方向
        sudo tee /etc/nginx/sites-available/odoo-site.conf > /dev/null << EOF
# 域名跳转配置
server {
    listen 80;
    listen 443 ssl http2;
    server_name $REDIRECT_FROM;
    
    ssl_certificate /etc/letsencrypt/live/$DEFAULT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DEFAULT_DOMAIN/privkey.pem;
    
    return 301 https://$REDIRECT_TO\$request_uri;
}

# 默认域名HTTP跳转HTTPS
server {
    listen 80;
    server_name $DEFAULT_DOMAIN;
    return 301 https://\$host\$request_uri;
}

# 主网站配置
server {
    listen 443 ssl http2;
    server_name $DEFAULT_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DEFAULT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DEFAULT_DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # 禁止访问数据库管理界面
    location ~* ^/web/database/(manager|selector) {
        deny all;
        return 403;
    }

    location / {
        proxy_pass http://localhost:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;
    }

    # 静态资源缓存
    location ~* \\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # 安全头
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Robots-Tag "index, follow" always;
}
EOF
        
        sudo ln -sf /etc/nginx/sites-available/odoo-site.conf /etc/nginx/sites-enabled/
    fi
}
# 生成SSL证书
generate_ssl_certificates() {
    log_step "生成SSL证书"
    
    # 为IP访问或管理系统生成自签名证书
    if [[ "$DEPLOY_TYPE" == "ip" ]] || [[ "$DEPLOY_TYPE" == "admin" ]]; then
        sudo mkdir -p /etc/ssl/private
        sudo chmod 700 /etc/ssl/private
        
        local cert_cn
        if [[ "$DEPLOY_TYPE" == "ip" ]]; then
            cert_cn="$(hostname -I | awk '{print $1}')"
        else
            cert_cn="$ADMIN_DOMAIN"
        fi
        
        sudo openssl req -x509 -nodes -days 365 \
            -newkey rsa:2048 \
            -keyout /etc/ssl/private/odoo-admin.key \
            -out /etc/ssl/certs/odoo-admin.crt \
            -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Odoo-Internal/CN=$cert_cn"
        
        log_info "管理系统SSL证书生成完成"
    fi
    
    # 为网站申请Let's Encrypt证书
    if [[ "$DEPLOY_TYPE" == "website" ]]; then
        log_warn "网站SSL证书需要手动申请Let's Encrypt证书"
        log_info "请在部署完成后运行: sudo certbot --nginx -d $MAIN_DOMAIN -d $WWW_DOMAIN"
    fi
}

# 配置Fail2Ban
setup_fail2ban() {
    log_step "配置Fail2Ban"
    
    # Odoo过滤规则
    sudo tee /etc/fail2ban/filter.d/odoo.conf > /dev/null << 'EOF'
[Definition]
failregex = .*Login failed for db.*from <HOST>
ignoreregex =
EOF

    # Jail配置
    sudo tee /etc/fail2ban/jail.d/odoo.conf > /dev/null << EOF
[odoo]
enabled = true
filter = odoo
logpath = /opt/odoo/data/odoo.log
maxretry = 5
findtime = 600
bantime = 3600
action = iptables[name=Odoo, port=http, protocol=tcp]
EOF

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    log_info "Fail2Ban配置完成"
}

# 创建备份脚本
create_backup_script() {
    log_step "创建备份脚本"
    
    mkdir -p /opt/odoo/scripts /opt/odoo/backups
    
    # 创建备份脚本
    cat > /opt/odoo/scripts/backup.sh << 'EOF'
#!/bin/bash
# Odoo 自动备份脚本

BACKUP_DIR="/opt/odoo/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "$(date): 开始备份..."

# 数据库备份
echo "备份数据库..."
docker exec odoo-db pg_dump -U odoo -Fc odoo > "$BACKUP_DIR/odoo_db_$DATE.dump"

if [ $? -eq 0 ]; then
    echo "数据库备份成功: odoo_db_$DATE.dump"
else
    echo "数据库备份失败！"
    exit 1
fi

# 文件存储备份
echo "备份文件存储..."
tar -czf "$BACKUP_DIR/odoo_filestore_$DATE.tar.gz" -C /opt/odoo data

if [ $? -eq 0 ]; then
    echo "文件存储备份成功: odoo_filestore_$DATE.tar.gz"
else
    echo "文件存储备份失败！"
    exit 1
fi

# 配置文件备份
echo "备份配置文件..."
tar -czf "$BACKUP_DIR/odoo_config_$DATE.tar.gz" -C /opt/odoo config addons

# 清理旧备份
echo "清理 $RETENTION_DAYS 天前的旧备份..."
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "$(date): 备份完成！"
EOF

    chmod +x /opt/odoo/scripts/backup.sh
    
    # 创建数据库维护脚本
    cat > /opt/odoo/scripts/db_maintenance.sh << 'EOF'
#!/bin/bash
# 数据库维护脚本

echo "开始数据库维护 - $(date)"

# 重建索引
echo "重建索引..."
docker exec odoo-db psql -U odoo -c "REINDEX DATABASE odoo;"

# 更新统计信息
echo "更新统计信息..."
docker exec odoo-db psql -U odoo -c "ANALYZE;"

# 清理死元组
echo "清理死元组..."
docker exec odoo-db psql -U odoo -c "VACUUM ANALYZE;"

echo "数据库维护完成 - $(date)"
EOF

    chmod +x /opt/odoo/scripts/db_maintenance.sh
    
    # 添加定时任务
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/odoo/scripts/backup.sh >> /var/log/odoo_backup.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 3 * * 0 /opt/odoo/scripts/db_maintenance.sh >> /var/log/odoo_maintenance.log 2>&1") | crontab -
    
    log_info "备份脚本创建完成"
    log_info "  - 每天凌晨2点自动备份"
    log_info "  - 每周日凌晨3点数据库维护"
}

# 启动服务
start_services() {
    log_step "启动Odoo服务"
    
    cd /opt/odoo
    docker-compose up -d
    
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if docker ps | grep -q "odoo.*Up"; then
        log_info "Odoo容器启动成功"
    else
        log_error "Odoo容器启动失败"
        docker-compose logs
        exit 1
    fi
    
    # 启动Nginx
    sudo nginx -t && sudo systemctl restart nginx
    log_info "Nginx启动成功"
}

# 验证部署
verify_deployment() {
    log_step "验证部署"
    
    # 检查容器状态
    log_info "检查容器状态..."
    docker ps
    
    # 检查端口
    log_info "检查端口监听..."
    if ss -tlnp | grep -E '8069|5432|6379' > /dev/null; then
        log_warn "发现暴露的端口，请检查配置"
    else
        log_info "端口配置正确，未发现暴露端口"
    fi
    
    # 测试HTTP访问
    local server_ip=$(hostname -I | awk '{print $1}')
    if curl -s -o /dev/null -w "%{http_code}" "http://$server_ip" | grep -q "301"; then
        log_info "HTTP重定向正常"
    else
        log_warn "HTTP重定向可能有问题"
    fi
    
    log_info "部署验证完成"
}
# 显示部署信息
show_deployment_info() {
    log_step "部署完成"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo "=================================="
    echo "Odoo 19 部署完成！"
    echo "=================================="
    echo
    echo "访问信息:"
    
    case $DEPLOY_TYPE in
        "ip")
            echo "  管理系统: https://$server_ip"
            echo "  访问模式: IP访问（管理系统模式）"
            ;;
        "admin")
            echo "  管理系统: https://$ADMIN_DOMAIN"
            echo "  访问模式: 管理系统模式"
            ;;
        "website")
            echo "  网站地址: https://$DEFAULT_DOMAIN"
            echo "  域名跳转: $REDIRECT_FROM → $REDIRECT_TO"
            echo "  访问模式: 网站模式"
            ;;
    esac
    
    echo
    echo "系统资源配置:"
    echo "  CPU核心数: $CPU_CORES"
    echo "  总内存: ${MEMORY_GB}GB"
    echo "  Odoo Workers: $WORKERS"
    echo "  Odoo内存限制: ${ODOO_MEMORY}GB"
    echo "  PostgreSQL缓冲区: ${PG_SHARED_BUFFERS}GB"
    echo "  Redis内存: $REDIS_MEMORY"
    
    echo
    echo "重要提醒:"
    echo "1. 首次访问需要创建数据库"
    echo "2. 创建数据库后立即编辑 /opt/odoo/config/odoo.conf"
    echo "   添加: dbfilter = ^your_database_name$"
    echo "   然后重启: cd /opt/odoo && docker-compose restart odoo"
    if [[ "$DEPLOY_TYPE" == "website" ]]; then
        echo "3. 申请 Let's Encrypt 证书:"
        echo "   sudo certbot --nginx -d $MAIN_DOMAIN -d $WWW_DOMAIN"
        echo "4. 重启 Nginx: sudo systemctl reload nginx"
    fi
    echo
    echo "自动化任务:"
    echo "  ✅ 每天凌晨2点自动备份"
    echo "  ✅ 每周日凌晨3点数据库维护"
    echo "  ✅ Fail2Ban 入侵防护已启用"
    echo
    echo "📖 详细文档和命令参考:"
    echo "   https://github.com/hwc0212/install-odoo19"
    echo
    
    log_warn "请重新登录SSH以使Docker权限生效！"
    log_info "部署完成，祝使用愉快！"
}

# 主函数
main() {
    echo "=================================="
    echo "Odoo 19 生产环境自动部署脚本"
    echo "作者: huwencai.com"
    echo "GitHub: https://github.com/hwc0212/install-odoo19"
    echo "版本: v2.0.0"
    echo "更新日期: 2026年1月14日"
    echo "=================================="
    echo
    
    check_root
    check_system
    check_resources
    collect_config
    
    log_info "开始部署，预计需要10-15分钟..."
    
    optimize_system
    setup_firewall
    install_docker
    create_directories
    generate_configs
    generate_nginx_config
    generate_ssl_certificates
    setup_fail2ban
    create_backup_script
    start_services
    verify_deployment
    show_deployment_info
    
    log_info "部署脚本执行完成！"
}

# 执行主函数
main "$@"