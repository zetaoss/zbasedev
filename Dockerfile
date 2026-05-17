# https://github.com/zetaoss/zbase
FROM ghcr.io/zetaoss/zbase:v0.43.800

ARG ZBASEDEV_VERSION
ENV ZBASEDEV_VERSION=${ZBASEDEV_VERSION}

# https://nodejs.org/en/download LTS for linux using nvm
ARG NVM_VERSION=v0.40.4
ARG NODE_MAJOR_VERSION=24

# https://go.dev/dl/
ARG GO_VERSION=1.26.3

ENV GOPATH=/root/go
ENV PATH=/usr/local/go/bin:/root/go/bin:${PATH}

RUN set -eux \
    && apt-get update && apt-get install -y --no-install-recommends \
        inotify-tools \
        jq \
        mariadb-client \
        procps \
        psmisc \
        redis-tools \
        ripgrep \
        supervisor \
        tini \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    ## go
    && ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
        amd64) GOARCH='amd64' ;; \
        arm64) GOARCH='arm64' ;; \
        *) echo "unsupported arch: ${ARCH}" >&2; exit 1 ;; \
    esac \
    && curl -L "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" -o /tmp/go.tgz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm -f /tmp/go.tgz \
    && mkdir -p "${GOPATH}/bin" \
    && export PATH=/usr/local/go/bin:/root/go/bin:$PATH \
    && go version \
    && go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    ## pnpm
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash \
    && . "$HOME/.nvm/nvm.sh" \
    && nvm install ${NODE_MAJOR_VERSION} \
    && node -v \
    && corepack enable pnpm \
    && pnpm -v \
    && npm install -g @google/gemini-cli

RUN set -eux \
    && VSCODE_SERVER_DIR=/root/.vscode-server \
    && TAG="$(curl -s https://api.github.com/repos/microsoft/vscode/releases/latest | jq -r .tag_name)" \
    && SHA="$(curl -s https://api.github.com/repos/microsoft/vscode/git/ref/tags/${TAG} | jq -r .object.sha)" \
    && mkdir -p "${VSCODE_SERVER_DIR}/bin/${SHA}" \
    && curl -s -L "https://update.code.visualstudio.com/commit:${SHA}/server-linux-x64/stable" -o vscode-server.tar.gz \
    && tar -xz -C "${VSCODE_SERVER_DIR}/bin/${SHA}" --strip-components=1 -f vscode-server.tar.gz \
    && rm -f vscode-server.tar.gz \
    && for extension in \
        bradlc.vscode-tailwindcss \
        dawhite.mustache \
        dbaeumer.vscode-eslint \
        editorconfig.editorconfig \
        esbenp.prettier-vscode \
        evgenius33.laravel-pint-fixer \
        golang.go \
        ms-azuretools.vscode-containers \
        ms-vscode.makefile-tools \
        openai.chatgpt \
        svelte.svelte-vscode \
        vitest.explorer \
    ; do \
    "${VSCODE_SERVER_DIR}/bin/${SHA}/bin/code-server" --install-extension "${extension}"; \
    done

RUN set -eux \
    && cd / \
    && git clone https://github.com/zetaoss/zengine.git app \
    && cd /app/ \
    && mv     /var/www/html                     /app/w \
    && ln -rs /app/mwz/extensions/ZetaExtension /app/w/extensions/ \
    && ln -rs /app/mwz/skins/ZetaSkin           /app/w/skins/ \
    && cd /app/laravel/ && composer install \
    && cd /app/svelte/                  && pnpm add esbuild --allow-build=esbuild && pnpm install && pnpm run build \
    && cd /app/w/skins/ZetaSkin/svelte/ && pnpm add esbuild --allow-build=esbuild && pnpm install && pnpm run build \
    && chown www-data:www-data -R /app/*

