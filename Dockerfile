# Tunnel Bunny - felsokningscontainer for VPN-natverk.
# VPN-koll, DNS-lackagetest och hastighetsmatning i en bild, ~25 MB.
#
#   docker run -d -p 8080:8080 tunnelbunny   webbgranssnitt med knappar
#   docker run --rm tunnelbunny vpn|dns|speed  engangskorning i terminalen
#   docker run --rm -it --entrypoint sh tunnelbunny    skal for egen felsokning
#
# Bygger for arkitekturen bilden byggs pa. Ooklas binar ar musl-byggd och kor pa
# Alpine utan gcompat - verifierat i 3.23.
FROM alpine:3.23

ARG SPEEDTEST_VERSION=1.2.0

RUN apk add --no-cache \
        curl ca-certificates \
        busybox-extras \
        bind-tools \
        mtr \
        iputils-ping \
        tar \
    # uname -m, INTE $TARGETARCH: den automatiska ARG:en slog inte igenom och
    # bygget lade en x86_64-binar i arm64-bilden utan att klaga.
    && arch="$(uname -m)" \
    && case "$arch" in \
         x86_64|aarch64) : ;; \
         *) echo "arkitektur $arch stods ej" >&2; exit 1 ;; \
       esac \
    # Bara 1.2.0 finns - 1.2.1 ger 403.
    && curl -fsSL "https://install.speedtest.net/app/cli/ookla-speedtest-${SPEEDTEST_VERSION}-linux-${arch}.tgz" \
       | tar xz -C /usr/local/bin speedtest \
    && chmod 755 /usr/local/bin/speedtest \
    && apk del tar

COPY check /usr/local/bin/check
COPY entrypoint /usr/local/bin/entrypoint
COPY www /www
RUN chmod 755 /usr/local/bin/check /usr/local/bin/entrypoint /www/cgi-bin/run \
    && mkdir -p /config

VOLUME /config
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint"]
