#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common.sh

# Verify correct number of arguments  ---------
if [[ "$#" -eq 0 || "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: build-native-script-addr.sh <script-name>"; exit 1; fi

# Get script name
script_name=${1}

# Verify if plutus script exists
[[ -f ${script_path}/${script_name}.script ]] && info "OK ${script_name}.script exists" || { error "${script_name}.script missing"; exit 1; }

#--------- Run program ---------

info "Creating ${key_path}/${script_name}.addr"
${cardanocli} address build \
    --payment-script-file ${script_path}/${script_name}.script \
    --testnet-magic $TESTNET_MAGIC \
    --out-file ${key_path}/${script_name}.addr
info "Address: $(cat ${key_path}/${script_name}.addr)"
info "Native script address saved ${key_path}/${script_name}.addr"
