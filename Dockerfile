# syntax=docker/dockerfile:1.7

FROM node:22-trixie-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        g++ \
        make \
        pkg-config \
        python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json .npmrc ./
COPY scripts/setup-appium.js ./scripts/setup-appium.js
RUN npm ci --omit=optional

COPY . .
RUN npm run dist \
    && npm prune --omit=dev --omit=optional

FROM node:22-trixie-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adb \
        ca-certificates \
        tini \
        usbutils \
    && rm -rf /var/lib/apt/lists/* \
    && adb version \
    && adb help 2>&1 | grep -q "pair HOST"

WORKDIR /app

COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p /root/.android

EXPOSE 8000

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "dist/index.js"]
