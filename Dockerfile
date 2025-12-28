# 使用官方 Python 3.10 轻量级镜像
FROM python:3.13-slim

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置工作目录
WORKDIR /app

# --- 关键修改：安装 Nginx 和 gettext-base ---
RUN apt-get update && \
    apt-get install -y nginx gettext-base && \
    rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY . .

# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install uvicorn fastapi sse-starlette

# 赋予启动脚本权限
RUN chmod +x entrypoint.sh

# 设置环境变量
ENV PYTHONUNBUFFERED=1

# 启动入口
CMD ["./entrypoint.sh"]
