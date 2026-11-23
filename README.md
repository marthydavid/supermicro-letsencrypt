[![release](https://github.com/marthydavid/supermicro-letsencrypt/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/marthydavid/supermicro-letsencrypt/actions/workflows/release.yml)

# supermicro-letsencrypt

Docker container to install Supermicro IPMI TLS certificates via ACME


[python script source](https://gist.github.com/mattisz/d112ebfe1869c56ce111ecbd2cbbd04d/569b20ddc8bcc2c04a875de2e9e918570a0cf93a)


# Config options

| Option | Type | Default |
|--------|------|---------|
| IPMI_USERNAME | String | - |
| IPMI_PASSWORD | String | - |
| IPMI_DOMAIN  | String | - |
| LE_EMAIL      | String | - |
| LE_SERVER      | String | https://acme-v02.api.letsencrypt.org/directory |
| DNS_PROVIDER  | String (options of [go-acme/lego](https://github.com/go-acme/lego#dns-providers) ) | route53 |
| MODEL         | String (X9-X13) | X11 |
| FORCE_UPDATE  | bool (`true` forces renewal and upload) | false |
| RENEW_BEFORE_SECONDS | Integer | 2592000 (30 days) |
| DEBUG         | any | - |

# Usage with Docker

```bash
docker run -v ~/.aws:/home/lego/.aws \
           -v ~/.lego:/home/lego/.lego \
           -e IPMI_USERNAME=ADMIN \
           -e IPMI_PASSWORD=ADMIN \
           -e IPMI_DOMAIN=ipmi.my.tld \
           -e LE_EMAIL=me@my.tld \
           -e DNS_PROVIDER=route53 \
           -e MODEL=X10 \
           ghcr.io/marthydavid/supermicro-letsencrypt
```


# Usage with kubernetes cronjob

```bash
kubectl create configmap sm-ipmi-info \
        --from-literal=IPMI_USERNAME=ADMIN \
        --from-literal=IPMI_DOMAIN=ipmi.my.tld \
        --from-literal=LE_EMAIL=me@my.tld \
        --from-literal=DNS_PROVIDER=route53 \
        --from-literal=MODEL=X10
kubectl create secret generic sm-ipmi-secret \
        --from-literal=IPMI_PASSWORD=ADMIN \
        --from-literal=AWS_ACCESS_KEY_ID=blahblahblah \
        --from-literal=AWS_SECRET_ACCESS_KEY=blahblahblah

kubectl apply -f demo/kubernetes/cronjob.yaml
kubectl get cm,secret,cronjob,pvc

# To trigger a run:

kubectl create job --from cronjob/sm-letsencrypt sm-letsencrypt-first-run

kubectl logs -f sm-letsencrypt-first-run
```

# Known firmware behaviour

- **X11 (verified on BMC firmware 01.74.17)**: the BMC accepts a multi-certificate upload and even reports it as installed, but silently discards it at the next boot and reverts to the default Supermicro certificate. Only the leaf certificate survives, so for `MODEL=X11` the updater uploads just the leaf (X12 already worked this way; X10 keeps the full file). The BMC therefore serves no intermediate: browsers fetch it themselves, but clients that do not (e.g. `curl`) need the Let's Encrypt intermediate in their trust store.
- The wrapper verifies after the reboot that the BMC serves the new certificate and exits with status 3 otherwise, so a reverting BMC can no longer look like a successful run.
- A certificate from the Let's Encrypt **staging** CA is replaced automatically when `LE_SERVER` points at production.

# Development

```bash
bash tests/renewal-logic.sh                 # renewal decisions, local TLS server + stubs
python3 -m unittest discover -s tests -v    # updater payload tests
```
