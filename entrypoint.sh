#!/bin/bash

# --- 步骤 1: 注入机密配置 ---
# 将环境变量写入配置文件
mkdir -p config
if [ -f config/config.yaml.template ]; then
    echo "正在生成配置文件..."
    envsubst < config/config.yaml.template > config/config.yaml
else
    echo "提示: 未找到模板，假设 config.yaml 已存在"
fi

# --- 步骤 2: 启动新闻推送 (后台运行) ---
echo "启动 TrendRadar 新闻推送服务..."
# 后台运行 main.py，日志写入文件以免干扰
python main.py > /var/log/trendradar_push.log 2>&1 &

# --- 步骤 3: 启动 MCP 服务 (前台运行) ---
echo "启动 MCP Server (HTTP模式)..."
echo "监听端口: $PORT"

# 直接调用 Python 模块，替代 start-http.sh
# --transport http: 开启 HTTP 模式
# --host 0.0.0.0: 允许外部访问
# --port $PORT: 使用 Render 分配的端口 (关键!)
python -m mcp_server.server --transport http --host 0.0.0.0 --port $PORT
