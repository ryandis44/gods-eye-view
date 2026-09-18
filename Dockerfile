# syntax=docker/dockerfile:1

FROM node:24-bookworm-slim AS build
WORKDIR /app

# Puppeteer is used by local QA, not by the application server.
ENV PUPPETEER_SKIP_DOWNLOAD=1
COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY . .

# These two public credentials are intentionally compiled into the browser.
# Private provider credentials must only be supplied at container runtime.
ARG GOOGLE_MAPS_API_KEY=""
ARG CESIUM_ION_TOKEN=""
RUN npm run build

FROM node:24-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=4173

# Vite and the provider plugins are required at runtime, including ws.
COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/build ./build
COPY --from=build /app/server ./server
COPY --from=build /app/src ./src
COPY --from=build /app/config ./config
COPY --from=build /app/vite.config.js ./vite.config.js
COPY --from=build /app/scripts/pinokio-environment.mjs /app/scripts/google-server-key.mjs ./scripts/

RUN mkdir -p .gev-cache .gev-logs node_modules/.vite-temp \
    && chown -R node:node .gev-cache .gev-logs node_modules/.vite-temp
USER node

EXPOSE 4173
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 4173) + '/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["sh", "-c", "exec node node_modules/vite/bin/vite.js preview --host 0.0.0.0 --port \"${PORT:-4173}\" --strictPort"]
