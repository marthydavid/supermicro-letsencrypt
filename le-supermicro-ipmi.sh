#!/usr/bin/env bash
set -euo pipefail

if [ -n "${DEBUG+x}" ]; then
    set -x
fi

for var in IPMI_USERNAME IPMI_PASSWORD IPMI_DOMAIN LE_EMAIL; do
    if [ -z "${!var:-}" ]; then
        echo "${var} not set!" >&2
        exit 1
    fi
done

FORCE_UPDATE="${FORCE_UPDATE:-false}"
LE_SERVER="${LE_SERVER:-https://acme-v02.api.letsencrypt.org/directory}"
DNS_PROVIDER="${DNS_PROVIDER:-route53}"
MODEL="${MODEL:-X11}"
# Renew when the installed certificate expires within this many seconds (30 days).
RENEW_BEFORE_SECONDS="${RENEW_BEFORE_SECONDS:-2592000}"

CERT_FILE=".lego/certificates/${IPMI_DOMAIN}.crt"
KEY_FILE=".lego/certificates/${IPMI_DOMAIN}.key"

# Fetch the certificate currently served by the BMC (PEM). Empty output if unreachable.
fetch_served_cert() {
    echo | timeout 10 openssl s_client -servername "${IPMI_DOMAIN}" -connect "${IPMI_DOMAIN}:443" 2>/dev/null \
        | openssl x509 2>/dev/null || true
}

served_cert="$(fetch_served_cert)"
should_renew="false"

if [ "${FORCE_UPDATE}" = "true" ]; then
    echo "FORCE_UPDATE is set to true. Forcing renewal..."
    should_renew="true"
elif [ -z "${served_cert}" ]; then
    echo "Could not read the certificate served by ${IPMI_DOMAIN}:443. Proceeding with renewal..."
    should_renew="true"
elif ! printf '%s\n' "${served_cert}" | openssl x509 -noout -issuer | grep -q "Let's Encrypt"; then
    echo "Certificate is NOT from Let's Encrypt. Forcing renewal..."
    should_renew="true"
elif ! printf '%s\n' "${served_cert}" | openssl x509 -noout -checkend "${RENEW_BEFORE_SECONDS}" >/dev/null; then
    echo "Certificate is from Let's Encrypt and expires within ${RENEW_BEFORE_SECONDS}s. Renewing..."
    should_renew="true"
fi

if [ "${should_renew}" = "false" ]; then
    echo "Certificate is from Let's Encrypt and is valid. No need to renew."
    exit 0
fi

lego_args=(
    --key-type rsa2048
    --server "${LE_SERVER}"
    --email "${LE_EMAIL}"
    --dns "${DNS_PROVIDER}"
    --accept-tos
    --domains "${IPMI_DOMAIN}"
)

# Renew only a non-empty certificate; obtain a new one if it is missing or empty.
if [ -s "${CERT_FILE}" ]; then
    /lego "${lego_args[@]}" renew
else
    /lego "${lego_args[@]}" run
fi

updater_args=(
    --ipmi-url "https://${IPMI_DOMAIN}"
    --cert-file "${CERT_FILE}"
    --key-file "${KEY_FILE}"
    --username "${IPMI_USERNAME}"
    --model "${MODEL}"
)
if [ "${FORCE_UPDATE}" = "true" ]; then
    updater_args+=(--force-update)
fi

# The updater reads the password from $IPMI_PASSWORD, keeping it out of the process list.
export IPMI_PASSWORD
exec python3 supermicro-ipmi-updater.py "${updater_args[@]}"
