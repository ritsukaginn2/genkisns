# GenkiSNS LLM proxy — no external npm deps, pure Node built-ins (incl. node:sqlite).
FROM node:24-alpine

WORKDIR /app

# Only the manifest and source are needed (no dependency install step).
COPY package.json ./
COPY src ./src

# SQLite database lives on a writable volume owned by the non-root node user.
RUN mkdir -p /data && chown -R node:node /data
USER node

ENV NODE_ENV=production \
    PORT=8787 \
    HOST=0.0.0.0 \
    DATA_FILE=/data/llm-proxy.db

VOLUME ["/data"]
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8787)+'/readyz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/index.js"]
