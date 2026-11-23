# lego v5 changed the CLI, file layout and key encoding; stay on v4 until validated on real BMCs.
FROM goacme/lego:v4.35.2

# apk package versions are tied to the Alpine release of the pinned lego base image; pinning them here would only break builds.
# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates bash openssl py3-openssl py3-lxml py3-requests py3-urllib3 \
    && adduser -u 1000 -D lego

USER 1000
WORKDIR /home/lego

COPY --chmod=755 le-supermicro-ipmi.sh supermicro-ipmi-updater.py /home/lego/

VOLUME /home/lego/.lego

ENTRYPOINT ["/home/lego/le-supermicro-ipmi.sh"]
