#!/usr/bin/env bash
set -e

if ! [ -z ${DEBUG+x} ]; then
	set -x
fi

if [ -z ${IPMI_USERNAME+x} ]; then
        echo "IPMI_USERNAME not set!"
        exit 1
fi
if [ -z ${IPMI_PASSWORD+x} ]; then
        echo "IPMI_PASSWORD not set!"
        exit 1
fi
if [ -z ${IPMI_DOMAIN+x} ]; then
        echo "IPMI_DOMAIN not set!"
        exit 1
fi
if [ -z ${LE_EMAIL+x} ]; then
        echo "LE_EMAIL not set!"
        exit 1
fi


FORCE_UPDATE="false"

force_update() {
  if [ "${FORCE_UPDATE}" == "true" ]; then
        echo --force-update
  fi
}

# Function to check SSL certificate expiry
check_ssl_expiry() {
    # Use timeout to prevent hanging in case of connection issues
    timeout 5 echo | openssl s_client -servername "${IPMI_DOMAIN}" -connect "${IPMI_DOMAIN}":443 2>/dev/null | openssl x509 -noout -checkend 2592000
    return $?
}

# Function to check if certificate is issued by Let's Encrypt
check_letsencrypt_issuer() {
    # Extract the issuer from the currently installed certificate
    timeout 5 echo | openssl s_client -servername "${IPMI_DOMAIN}" -connect "${IPMI_DOMAIN}":443 2>/dev/null | openssl x509 -noout -issuer | grep -q "Let's Encrypt"
    return $?
}

# Determine if we should renew the certificate
should_renew="false"

# Check if certificate is from Let's Encrypt
if check_letsencrypt_issuer; then
    # Certificate is from Let's Encrypt
    if check_ssl_expiry; then
        # Certificate is not expiring, no need to renew
        echo "Certificate is from Let's Encrypt and is valid. No need to renew."
        exit 0
    else
        # Certificate is expiring within 30 days
        echo "Certificate is from Let's Encrypt and expiring within 30 days. Renewing the certificate..."
        should_renew="true"
    fi
else
    # Certificate is NOT from Let's Encrypt - always renew
    echo "Certificate is NOT from Let's Encrypt. Forcing renewal..."
    should_renew="true"
fi

# Check FORCE_UPDATE flag
if [ "${FORCE_UPDATE}" == "true" ]; then
    echo "FORCE_UPDATE is set to true. Forcing renewal..."
    should_renew="true"
fi

# If should_renew is false, exit without doing anything
if [ "${should_renew}" == "false" ]; then
    echo "No renewal needed."
    exit 0
fi

# Sign the request and obtain a certificate
if [ -f ".lego/certificates/${IPMI_DOMAIN}.crt" ]; then
    /lego --key-type rsa2048 --server ${LE_SERVER-https://acme-v02.api.letsencrypt.org/directory} --email ${LE_EMAIL} --dns ${DNS_PROVIDER:-route53} --accept-tos --domains ${IPMI_DOMAIN} renew
else
    /lego --key-type rsa2048 --server ${LE_SERVER-https://acme-v02.api.letsencrypt.org/directory} --email ${LE_EMAIL} --dns ${DNS_PROVIDER:-route53} --accept-tos --domains ${IPMI_DOMAIN} run
fi

python3 supermicro-ipmi-updater.py --ipmi-url https://${IPMI_DOMAIN} --cert-file .lego/certificates/${IPMI_DOMAIN}.crt --key-file .lego/certificates/${IPMI_DOMAIN}.key --username ${IPMI_USERNAME} --password ${IPMI_PASSWORD} --model ${MODEL:-X11} $(force_update)