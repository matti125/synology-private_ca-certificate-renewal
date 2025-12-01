#!/bin/bash

# This script assumes that you only have the factory-installed self-signed certificate in use,
# known as "default". If you have added other certificates,
# this means that those new certs could now be used instead of the default one.
# In that case the script will not work, as it will use the folder specified in the 
# DEFAULT file. Possibly the easiest workaround in that case would be to remove 
# the added certs, or at least make the "default" cert 
# the cert that will be used for all services. Both actions be done through the NAS (DSM) GUI.

set -euo pipefail

# --- Configurable domain via first CLI argument ---
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domain>"
    exit 1
fi
DOM="$1"

ACME=/usr/local/share/acme.sh/acme.sh
CONF_HOME=~certadmin/acme

# Ask acme.sh for domain info and extract DOMAIN_CONF path for the source directory
info="$($ACME --config-home "$CONF_HOME" --info -d "$DOM" 2>/dev/null || true)"
DOMAIN_CONF="$(printf '%s\n' "$info" | sed -n 's/^DOMAIN_CONF=//p')"

if [ -z "$DOMAIN_CONF" ] || [ ! -r "$DOMAIN_CONF" ]; then
  echo "Could not determine DOMAIN_CONF for $DOM" >&2
  echo "acme.sh --info output was:" >&2
  printf '%s\n' "$info" >&2
  exit 1
fi

# The per-domain certificate directory
S="$(dirname "$DOMAIN_CONF")"
#S=~certadmin/acme/"${DOM}_ecc"
# --- Destination directory ---
ARCHIVE_DIR=/usr/syno/etc/certificate/_archive
D="${ARCHIVE_DIR}/$(cat ${ARCHIVE_DIR}/DEFAULT)"

# --- Sanity checks ---
if [[ ! -d "$S" ]]; then
    echo "ERROR: Source directory does not exist: $S"
    exit 1
fi
if [[ ! -d "$D" ]]; then
    echo "ERROR: Certificate archive directory does not exist: $D"
    exit 1
fi

# --- Copy certs into Synology DSM cert archive ---
cp "${S}/fullchain.cer"  "${D}/fullchain.pem"
cp "${S}/${DOM}.cer"     "${D}/cert.pem"
cp "${S}/${DOM}.key"     "${D}/privkey.pem"

# --- Apply to DSM + reload nginx ---
/usr/syno/bin/synow3tool --gen-all
/usr/syno/bin/synosystemctl reload nginx
