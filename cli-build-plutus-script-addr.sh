#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common-utils.sh

# Verify correct number of arguments  ---------
if [[ "$#" -eq 0 || "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: build-plutus-script-addr.sh <script-name>"; exit 1; fi
# Get script name
script_name=${1}

# Verify if plutus script exists
[[ -f ${plutus_script_path}/${script_name}.plutus ]] && info "OK ${script_name}.plutus exists" || { error "${script_name}.plutus missing"; exit 1; }

#--------- Run program ---------

info "Creating ${address_path}/${script_name}.addr"
${cardanocli} address build \
    --payment-script-file ${plutus_script_path}/${script_name}.plutus \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${address_path}/${script_name}.addr
info "Address: $(cat ${address_path}/${script_name}.addr)"
info "Plutus script address saved ${address_path}/${script_name}.addr)"