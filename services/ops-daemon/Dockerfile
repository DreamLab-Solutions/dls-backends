FROM node:20-alpine

RUN apk add --no-cache docker-cli docker-cli-compose

WORKDIR /workspace

COPY package.json package-lock.json* ./
COPY services/ops-daemon/package.json services/ops-daemon/package-lock.json* ./services/ops-daemon/
COPY packages/dls-domain/package.json ./packages/dls-domain/
COPY packages/dls-domain/tsconfig.json ./packages/dls-domain/
COPY packages/dls-domain/src ./packages/dls-domain/src

RUN npm install --include=dev --workspace services/ops-daemon --workspace packages/dls-domain
RUN npm run -w packages/dls-domain build && npm run -w packages/dls-domain build:schema

COPY services/ops-daemon ./services/ops-daemon

WORKDIR /workspace/services/ops-daemon
EXPOSE 5055
CMD ["npm", "start"]
