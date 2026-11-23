#!/usr/bin/env bash
# Exercises the renew/skip decisions of le-supermicro-ipmi.sh against a local TLS server.
# Stubs replace lego and the updater, so no network, ACME or BMC is involved.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
PORT=18443
SERVER_PID=""
cleanup() { [ -n "${SERVER_PID}" ] && kill "${SERVER_PID}" 2>/dev/null; rm -rf "${WORK}"; }
trap cleanup EXIT

cd "${WORK}"
printf '#!/bin/sh\necho STUB-LEGO "$@"\nmkdir -p .lego/certificates\n' > lego
printf '#!/bin/sh\necho STUB-UPDATER "$@"\nexit 0\n' > updater
chmod +x lego updater
# Point the script at the stubs and the local port; skip post-reboot verification (covered separately).
sed -e "s#/lego #${WORK}/lego #g" \
    -e "s#python3 supermicro-ipmi-updater.py#${WORK}/updater#" \
    -e "s#:443#:${PORT}#g" "${ROOT}/le-supermicro-ipmi.sh" > run.sh
chmod +x run.sh

export IPMI_USERNAME=u IPMI_PASSWORD=p IPMI_DOMAIN=localhost LE_EMAIL=e@example.com VERIFY_SERVED_CERT=false
failures=0

serve() { # subject days
    openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem -days "$2" -subj "$1" 2>/dev/null
    openssl s_server -accept "${PORT}" -cert c.pem -key k.pem -www >/dev/null 2>&1 &
    SERVER_PID=$!
    sleep 1
}
stop() { kill "${SERVER_PID}" 2>/dev/null; wait "${SERVER_PID}" 2>/dev/null; SERVER_PID=""; }

check() { # description expected-substring command...
    local desc="$1" want="$2"; shift 2
    local out
    out="$("$@" 2>&1)"
    if grep -q -- "${want}" <<<"${out}"; then echo "ok   - ${desc}"; else echo "FAIL - ${desc} (wanted '${want}')"; echo "${out}" | sed 's/^/       /'; failures=$((failures + 1)); fi
}

check "missing variable is rejected" "LE_EMAIL not set" env -u LE_EMAIL ./run.sh
check "unreachable BMC proceeds with renewal" "Could not read the certificate" ./run.sh

serve "/O=Let's Encrypt/CN=R11" 90
check "valid Let's Encrypt cert is left alone" "No need to renew" ./run.sh
check "FORCE_UPDATE=true forces renewal and --force-update" "STUB-UPDATER.*--force-update" env FORCE_UPDATE=true ./run.sh
check "cert inside the renewal window renews" "expires within" env RENEW_BEFORE_SECONDS=99999999 ./run.sh
stop

serve "/O=Let's Encrypt/CN=(STAGING) Fake" 90
check "staging cert is replaced when LE_SERVER is production" "STAGING CA" ./run.sh
check "staging cert is kept when LE_SERVER is staging" "No need to renew" env LE_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory ./run.sh
stop

serve "/O=Self/CN=x" 90
check "non-Let's Encrypt cert forces renewal" "NOT from Let's Encrypt" ./run.sh
check "password is not passed on the command line" "STUB-UPDATER" ./run.sh
out="$(./run.sh 2>&1)"
if grep -q -- '--password' <<<"${out}"; then echo "FAIL - --password appears in updater args"; failures=$((failures + 1)); else echo "ok   - updater is not given --password"; fi
stop

exit "${failures}"
