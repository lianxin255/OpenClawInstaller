# ============================================================
# ClawdBot Docker 镜像
# 
# 构建: docker build -t clawdbot .
# 运行: docker run -d --name clawdbot -v ~/.clawd:/root/.clawd clawdbot
# ============================================================

FROM node:22-alpine

LABEL maintainer="ClawdBot Community"
LABEL description="ClawdBot - Your Personal AI Assistant"
LABEL version="1.0.0"

# 安装基础依赖
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    tzdata

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建工作目录
WORKDIR /app

# 安装 ClawdBot
RUN npm install -g clawdbot@latest

# 创建配置目录
RUN mkdir -p /root/.clawd/logs \
    /root/.clawd/data \
    /root/.clawd/skills \
    /root/.clawd/backups

# 复制默认配置和技能
COPY examples/config.example.yaml /root/.clawd/config.yaml.example
COPY examples/skills/ /root/.clawd/skills/

# 设置卷挂载点
VOLUME ["/root/.clawd"]

# 暴露端口
EXPOSE 18789

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD clawdbot health || exit 1

# 入口脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["clawdbot", "start", "--daemon"]
