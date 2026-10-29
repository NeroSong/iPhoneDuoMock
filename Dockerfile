# Build with --pull to receive security fixes for both base images.
FROM node:22-alpine AS build
WORKDIR /app
RUN chown node:node /app
USER node

COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

COPY --chown=node:node tsconfig.json vite.config.ts tokens.css index.html ./
COPY --chown=node:node src ./src
COPY --chown=node:node public ./public
COPY --chown=node:node scripts ./scripts
COPY --chown=node:node zh ./zh
COPY --chown=node:node ja ./ja
COPY --chown=node:node fr ./fr
RUN npm run build && node scripts/prepare-container.mjs

FROM nginxinc/nginx-unprivileged:stable-alpine AS runtime
USER root
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/*
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/container-security-headers.conf /etc/nginx/security-headers.conf
COPY --from=build /app/dist/ /usr/share/nginx/html/
USER 101:101
EXPOSE 8080
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
# Skip upstream entrypoint scripts: configuration is immutable at runtime.
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
