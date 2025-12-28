#!/bin/bash

# --- 步骤 1: 注入机密配置 (保持不变) ---
mkdir -p config
if [ -f config/config.yaml.template ]; then
    echo "正在生成配置文件..."
    envsubst < config/config.yaml.template > config/config.yaml
else
    echo "提示: 未找到模板，假设 config.yaml 已存在"
fi

# --- 步骤 2: 生成 Nginx 安全配置 (新增) ---
echo "正在配置 Nginx 安全网关..."

# 如果用户没有设置 MCP_SECRET，则生成一个警告但不开启验证（防止报错）
if [ -z "$MCP_SECRET" ]; then
    echo "⚠️ 警告: 未设置 MCP_SECRET 环境变量，服务将不设防！"
    AUTH_BLOCK=""
else
    echo "🔒 已启用访问控制，Token: $MCP_SECRET"
    # Nginx 逻辑：如果请求头 X-MCP-Token 不等于密码，返回 403
    AUTH_BLOCK="if (\$http_x_mcp_token != \"$MCP_SECRET\") { return 403; }"
fi

# 动态生成 nginx.conf
# 1. 监听 Render 分配的 $PORT (外部入口)
# 2. 转发给本地 8000 端口 (内部 Python 服务)
# 3. 开启 SSE 支持 (proxy_buffering off)
cat > /etc/nginx/nginx.conf <<EOF
worker_processes 1;
events { worker_connections 1024; }
http {
    sendfile on;
    keepalive_timeout 65;
    server {
        listen $PORT;
        server_name localhost;

        location / {
            # --- 安全检查 ---
            $AUTH_BLOCK

            # --- 转发逻辑 ---
            proxy_pass http://127.0.0.1:8000;
            
            # --- SSE 关键配置 (必须有，否则流式传输会卡住) ---
            proxy_http_version 1.1;
            proxy_set_header Connection '';
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 24h;
            
            # 传递真实 IP
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF

# --- 步骤 3: 启动服务 ---

# A. 启动 Nginx (前台运行还是后台？Nginx 默认后台，但我们需要它作为守护)
# 我们让 Nginx 在后台跑，脚本最后挂起，或者让 Python 在后台，Nginx 在前台。
# 这里选择：Python 后台，Nginx 前台。

echo "启动 TrendRadar 新闻推送 (后台)..."
python main.py > /var/log/trendradar_push.log 2>&1 &

echo "启动 MCP Server (内部端口 8000)..."
# 注意：这里强制监听 8000，不监听 $PORT 了，因为 $PORT 被 Nginx 占用了
# 日志重定向，避免刷屏
python -m mcp_server.server --transport http --host 127.0.0.1 --port 8000 > /var/log/mcp.log 2>&1 &

# 等待 Python 启动一会儿
sleep 3

echo "启动 Nginx 网关 (监听端口 $PORT)..."
# daemon off 让 Nginx 在前台运行，保持容器存活
nginx -g 'daemon off;'
