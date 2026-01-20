# ===========================
# Stage 1: 构建阶段
# ===========================
FROM registry.cn-shanghai.aliyuncs.com/qianxing-fe/node:20-alpine AS builder
ARG APP_ENV=production
WORKDIR /app
# 安装 pnpm（使用全局安装）
RUN npm install -g pnpm
# 仅复制依赖文件（充分利用缓存）
COPY package.json ./
# 安装依赖（可使用淘宝镜像加速）
RUN pnpm install --registry=https://registry.npmmirror.com
# 复制源码
COPY . .
# 构建项目（根据环境调整命令）
RUN APP_ENV=${APP_ENV} pnpm run build
# ===========================
# Stage 2: 运行阶段
# ===========================
FROM registry.cn-shanghai.aliyuncs.com/qianxing-fe/node:20-alpine AS runner
WORKDIR /app
ENV PORT=3333
# 从构建阶段复制 standalone 产物
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
# 暴露端口
EXPOSE 3333
# 使用 root 用户运行（默认就是 root，可显式声明）
USER root
# 启动 Next.js 服务
CMD ["node", "server.js"]
