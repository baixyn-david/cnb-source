# 使用官方 Node.js 18 LTS 镜像作为基础镜像
FROM registry.cn-shanghai.aliyuncs.com/qianxing-fe/node:20-alpine AS base
RUN npm install -g pnpm
WORKDIR /app

# 安装依赖阶段
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# 复制依赖配置文件
COPY package.json pnpm-lock.yaml ./

# 安装依赖
RUN pnpm install --frozen-lockfile

# 构建阶段
FROM base AS builder
WORKDIR /app

# 注入代理变量（可选，用于构建时访问外部资源）
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV http_proxy=$HTTP_PROXY
ENV https_proxy=$HTTPS_PROXY

# 从 deps 阶段复制 node_modules
COPY --from=deps /app/node_modules ./node_modules
# 复制项目文件
COPY . .

# 禁用 Next.js 遥测
ENV NEXT_TELEMETRY_DISABLED=1

# 临时屏蔽字体下载逻辑（解决网络连接失败问题，不修改本地业务代码）
RUN sed -i 's/const _dmSans =/ \/\/ const _dmSans =/g' app/layout.tsx && \
    sed -i 's/const _spaceMono =/ \/\/ const _spaceMono =/g' app/layout.tsx && \
    sed -i 's/const _sourceSerif_4 =/ \/\/ const _sourceSerif_4 =/g' app/layout.tsx

# 执行构建
RUN pnpm build

# 生产运行阶段
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 创建非 root 用户
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# 复制构建产物
COPY --from=builder /app/public ./public

# 设置正确的权限并复制预渲染缓存
RUN mkdir .next
RUN chown nextjs:nodejs .next

# 自动利用输出跟踪来减少镜像大小
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# 启动应用
CMD ["node", "server.js"]
