FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY src/ ./src/

# /data is the Andasy persistent volume mount point for SQLite
# It is created by the volume attachment — we just ensure it exists for local runs
RUN mkdir -p /data

EXPOSE 3000

CMD ["node", "src/server.js"]
