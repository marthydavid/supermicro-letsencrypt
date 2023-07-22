[![release](https://github.com/marthydavid/supermicro-letsencrypt/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/marthydavid/supermicro-letsencrypt/actions/workflows/release.yml)

# supermicro-letsencrypt

Docker container to install Supermicro IPMI TLS certificates via ACME


[python script source](https://gist.githubusercontent.com/mattisz/d112ebfe1869c56ce111ecbd2cbbd04d/raw/569b20ddc8bcc2c04a875de2e9e918570a0cf93a/ipmi-updater.py)


# Config options

| Option | Type | Default |
|--------|------|---------|
| IPMI_USERNAME | String | - |
| IPMI_PASSWORD | String | - |
| IPMI_ADDRESS  | String | - |
| LE_EMAIL      | String | - |
| DNS_PROVIDER  | String (options of [go-acme/lego](https://github.com/go-acme/lego#dns-providers) ) | route53 |
| MODEL         | String (X9-X13) | X11 |
| DEBUG         | any | - |

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


# Usage with kubernetes cronjob

```bash
kubectl create configmap sm-ipmi-info \
        --from-literal=IPMI_USERNAME=ADMIN \
        --from-literal=IPMI_ADDRESS=ipmi.my.tld \
        --from-literal=LE_EMAIL=me@my.tld \
        --from-literal=DNS_PROVIDER=route53 \
        --from-literal=MODEL=X10
kubectl create secret generic sm-ipmi-secret \
        --from-literal=IPMI_PASSWORD=ADMIN \
        --from-literal=AWS_ACCESS_KEY_ID=blahblahblah \
        --from-literal=AWS_SECRET_ACCESS_KEY=blahblahblah

kubectl apply -f demo/kubernetes/cronjob.yaml
kubectl get cm,secret,cronjob

# To trigger a run:

kubectl create job --from cronjob/sm-letsencrypt sm-letsencrypt-first-run

kubectl logs -f sm-letsencrypt-first-run
```