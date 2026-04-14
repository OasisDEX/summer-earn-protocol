FROM node:20-alpine AS builder

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./
COPY packages/summer-earn-gov-alert-bot ./packages/summer-earn-gov-alert-bot

RUN pnpm install --frozen-lockfile --ignore-scripts

WORKDIR /app/packages/summer-earn-gov-alert-bot

RUN pnpm run build

FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/packages/summer-earn-gov-alert-bot /app

CMD ["pnpm", "start"]
