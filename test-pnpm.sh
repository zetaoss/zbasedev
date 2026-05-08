#!/bin/bash
docker run --rm node:22-bullseye bash -c "\
  corepack enable pnpm && \
  mkdir -p /app && cd /app && \
  echo '{\"name\":\"test\",\"dependencies\":{\"esbuild\":\"0.27.7\"}}' > package.json && \
  pnpm install"