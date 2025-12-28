# 使用官方 Python 3.13 轻量级镜像
FROM python:3.13-slim

# 1. 设置时区 (中国时间，确保新闻推送准时)
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 2. 设置工作目录
WORKDIR /app

# 3. 安装系统工具
# gettext-base: 用于 envsubst (注入密码)
RUN apt-get update && \
    apt-get install -y gettext-base && \
    rm -rf /var/lib/apt/lists/*

# 4. 复制项目文件
COPY . .

# 5. 安装依赖 (使用标准的 pip)
# 额外安装 uvicorn/fastapi 确保 MCP HTTP 功能可用
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install uvicorn fastapi sse-starlette

# 6. 赋予启动脚本权限
RUN chmod +x entrypoint.sh

# 7. 设置环境变量
ENV PYTHONUNBUFFERED=1

# 8. 启动入口
CMD ["./entrypoint.sh"]
