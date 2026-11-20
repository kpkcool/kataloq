# syntax=docker/dockerfile:1
# kataloq-api container image. Runs locally via docker compose and unchanged on
# AWS (ECS / App Runner). Configuration comes from environment variables only.

# ---- Build: install all dependencies and compile TypeScript ----
FROM node:26-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

# ---- Runtime: production dependencies + compiled JS only ----
FROM node:26-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
# Owned by the runtime user: Node reads package.json at start-up (to see "type": "module"),
# and the image must not depend on the file permissions of whoever built it.
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build --chown=node:node /app/dist ./dist

# Never run as root.
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
