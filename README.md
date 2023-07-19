# docker-supermicro-letsencrypt

Docker container to install Supermicro IPMI TLS certificates via ACME


[python script source](https://gist.githubusercontent.com/mattisz/d112ebfe1869c56ce111ecbd2cbbd04d/raw/569b20ddc8bcc2c04a875de2e9e918570a0cf93a/ipmi-updater.py)


# Usage with Docker

```bash
docker run -v ~/.aws:/home/lego/.aws \
           -v ~/.lego:/home/lego/.lego \
           -e IPMI_USERNAME=ADMIN \
           -e IPMI_PASSWORD=ADMIN \
           -e IPMI_ADDRESS=ipmi.my.tld \
           -e LE_EMAIL=me@my.tld \
           -e DNS_PROVIDER=route53 \
           -e MODEL=X10 \
           ghcr.io/marthydavid/supermicro-letsencrypt
```