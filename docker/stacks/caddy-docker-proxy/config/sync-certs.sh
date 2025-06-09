#!/bin/sh

CERT_NAME="${1:-cert.pem}"
CERT_DIR="/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${CERT_NAME}/"

if [ ! -f "${CERT_DIR}${CERT_NAME}.crt" ]; then
  echo "Missing certificate"
  exit 1
fi

if [ ! -f "${CERT_DIR}${CERT_NAME}.key" ]; then
  echo "Missing certificate key"
  exit 1
fi

# unifi
scp -o "StrictHostKeyChecking=no" -i /secrets/UNIFI_SSH_KEY "${CERT_DIR}${CERT_NAME}.crt" "root@10.100.1.1:/data/unifi-core/config/d5536a1d-cc4c-4516-bdc0-5fc934a5e82e.crt"
scp -o "StrictHostKeyChecking=no" -i /secrets/UNIFI_SSH_KEY "${CERT_DIR}${CERT_NAME}.key" "root@10.100.1.1:/data/unifi-core/config/d5536a1d-cc4c-4516-bdc0-5fc934a5e82e.key"
ssh -o "StrictHostKeyChecking=no" -i /secrets/UNIFI_SSH_KEY -t "root@10.100.1.1" "service nginx reload"
