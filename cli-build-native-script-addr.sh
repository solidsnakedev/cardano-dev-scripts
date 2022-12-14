#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common-utils.sh

# Verify correct number of arguments  ---------
if [[ "$#" -eq 0 || "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: build-native-script-addr.sh <script-name>"; exit 1; fi

# Get script name
script_name=${1}

# Verify if plutus script exists
[[ -f ${native_script_path}/${script_name}.script ]] && info "OK ${script_name}.script exists" || { error "${script_name}.script missing"; exit 1; }

#--------- Run program ---------

info "Creating ${address_path}/${script_name}.addr"
${cardanocli} address build \
    --payment-script-file ${native_script_path}/${script_name}.script \
    --testnet-magic $TESTNET_MAGIC \
    --out-file ${address_path}/${script_name}.addr
info "Address: $(cat ${address_path}/${script_name}.addr)"
info "Native script address saved ${address_path}/${script_name}.addr"
