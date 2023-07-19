FROM goacme/lego:v4.12.3
LABEL org.opencontainers.image.source https://github.com/marthydavid/docker-supermicro-letsencrypt
RUN apk add --no-cache ca-certificates bash openssl  python3-dev py3-pip gcc  musl-dev libffi-dev openssl-dev \
    && adduser -u 1000 -D  lego

USER 1000

WORKDIR /home/lego

ADD le-supermicro-ipmi.sh supermicro-ipmi-updater.py requirements.txt /home/lego/

RUN pip install -r requirements.txt

VOLUME /home/lego/.lego

ENTRYPOINT ["/home/lego/le-supermicro-ipmi.sh"]
