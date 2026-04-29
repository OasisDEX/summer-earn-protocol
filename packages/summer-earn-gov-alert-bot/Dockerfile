FROM node:20-alpine AS builder

RUN apk add --no-cache git

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./
COPY packages/typescript-config ./packages/typescript-config
COPY packages/eslint-config ./packages/eslint-config
COPY packages/summer-earn-gov-alert-bot ./packages/summer-earn-gov-alert-bot

RUN pnpm install --frozen-lockfile --ignore-scripts

# Build with esbuild
# --bundle: includes all your workspace dependencies
# --platform=node: keeps node built-ins (fs, path) external
# --format=esm: matches your modern setup
WORKDIR /app/packages/summer-earn-gov-alert-bot
RUN npx esbuild src/index.ts \
    --bundle \
    --platform=node \
    --format=esm \
    --outfile=dist/bundle.js \
    --sourcemap \
    --banner:js="import { createRequire } from 'module'; import { fileURLToPath } from 'url'; import { dirname } from 'path'; const require = createRequire(import.meta.url); const __filename = fileURLToPath(import.meta.url); const __dirname = dirname(__filename);"

# --- RUNNER STAGE ---
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# You only need the single bundled file! 
# You don't even need node_modules in the final image.
COPY --from=builder /app/packages/summer-earn-gov-alert-bot/dist /app/dist

CMD ["node", "dist/bundle.js"]