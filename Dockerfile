# syntax=docker/dockerfile:1

FROM alpine:3.22 AS cmarkbuild
RUN apk add --no-cache cmake make gcc g++ musl-dev git \
 && git clone --depth 1 --branch 0.29.0.gfm.13 https://github.com/github/cmark-gfm.git /cmark-src \
 && cmake -S /cmark-src -B /cmark-src/build -DCMAKE_BUILD_TYPE=Release -DCMARK_TESTS=OFF -DCMAKE_INSTALL_PREFIX=/cmark \
 && cmake --build /cmark-src/build -j"$(nproc)" \
 && cmake --install /cmark-src/build

FROM alpine:3.22 AS erlbuild-base
ARG TARGETARCH
ENV ERL_ROOT=/usr/lib/erlang

COPY --from=cmarkbuild /cmark /cmark
ENV PKG_CONFIG_PATH=/cmark/lib/pkgconfig \
    C_INCLUDE_PATH=/cmark/include \
    LIBRARY_PATH=/cmark/lib

RUN --mount=type=secret,id=gh_token,env=GITHUB_TOKEN,required=false set -eu; \
  case "$TARGETARCH" in arm64) A=aarch64 ;; *) A=x86_64 ;; esac; \
  apk add --no-cache erlang28 erlang28-dev git bash curl gcc musl-dev pkgconf file-dev sqlite-dev argon2-dev brotli-dev jq; \
  curl -fsSL --retry 8 --retry-all-errors --retry-delay 3 -o /usr/local/bin/rebar3 https://s3.amazonaws.com/rebar3/rebar3 \
  && chmod +x /usr/local/bin/rebar3; \
  asset="https://github.com/casey/just/releases/download/1.58.0/just-1.58.0-${A}-unknown-linux-musl.tar.gz"; \
  if [ -n "${GITHUB_TOKEN:-}" ]; then \
    api_asset=$(curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" "https://api.github.com/repos/casey/just/releases/tags/1.58.0" | jq -r --arg a "$A" '.assets[] | select(.name | test("^just-1\\.58\\.0-" + $a + "-unknown-linux-musl\\.tar\\.gz$")) | .url' | head -n1); \
    if [ -n "$api_asset" ]; then asset="$api_asset"; fi; \
  fi; \
  curl -fsSL --retry 8 --retry-all-errors --retry-delay 3 \
    -H "Accept: application/octet-stream" \
    -o /tmp/just.tar.gz "$asset" \
  && tar -xzf /tmp/just.tar.gz -C /usr/local/bin just \
  && rm /tmp/just.tar.gz
WORKDIR /build
COPY rebar.config rebar.lock ./

FROM erlbuild-base AS migbuild
ENV REBAR_PROFILE=migrations
COPY migrator ./migrator
COPY migrations ./migrations
RUN rebar3 as migrations escriptize

FROM erlbuild-base AS prod
ENV REBAR_PROFILE=prod
COPY src ./src
RUN rebar3 as prod escriptize

FROM denoland/deno:2.9.7 AS frontend
WORKDIR /app/frontend
COPY frontend/deno.lock frontend/package.json frontend/.npmrc ./
RUN deno install
COPY frontend ./
RUN mkdir -p /app/site-root && deno task build

FROM alpine:3.22 AS runtime
RUN   apk add --no-cache \
      erlang28 sqlite-libs argon2-libs brotli ncurses-libs file \
      ca-certificates tini \
  && adduser -D -u 1000 -s /bin/sh app

COPY --from=cmarkbuild /cmark/lib/libcmark-gfm.so.0.29.0.gfm.13 /usr/lib/
COPY --from=cmarkbuild /cmark/lib/libcmark-gfm-extensions.so.0.29.0.gfm.13 /usr/lib/

WORKDIR /app
COPY --from=prod /build/_build/prod/bin/petring ./petring
COPY --from=migbuild /build/_build/migrations/bin/migrator ./migrator
COPY --from=migbuild /build/migrations ./migrations
COPY --from=frontend /app/site-root ./site-root
COPY docker/start.sh ./start.sh
RUN chmod +x ./petring ./migrator ./start.sh \
 && mkdir -p /app/data && chown -R app:app /app
USER app
ENV HOME=/app
VOLUME ["/app/data"]
EXPOSE 8080
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/start.sh"]
