FROM goacme/lego:v4.13.3
RUN apk add --no-cache ca-certificates bash openssl python3-dev py3-pip py3-openssl py3-lxml py3-requests py3-urllib3 \
    && adduser -u 1000 -D  lego

USER 1000

WORKDIR /home/lego

ADD le-supermicro-ipmi.sh supermicro-ipmi-updater.py requirements.txt /home/lego/

#RUN pip install -r requirements.txt

VOLUME /home/lego/.lego

ENTRYPOINT ["/home/lego/le-supermicro-ipmi.sh"]
