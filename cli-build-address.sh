#!/bin/bash
set -eo pipefail

#--------- Import common paths and functions ---------
source common-utils.sh

# Verify correct number of arguments  ---------
if [[ "$#" -eq 0 || "$#" -gt 2 ]]; then error "Missing parameters" && info "Usage: build-address.sh <wallet-name> | <wallet-name> <stake-name>"; exit 1; fi
# Get wallet name
wallet_name=${1}
# Verify if wallet vkey exists
[[ -f ${key_path}/${wallet_name}.vkey ]] && info "OK ${wallet_name}.vkey exists" || { error "${wallet_name}.vkey missing"; exit 1; }

if [[ -n ${2} ]]; then
    # Get stake name
    stake_name=${2}
    # Verify if policy vkey exists
    [[ -f ${key_path}/${stake_name}.vkey ]] && info "OK ${stake_name}.vkey exists" || { error "${stake_name}.vkey missing"; exit 1; }

    #--------- Run program ---------
    info "Creating/Deriving cardano address from verification key"
    ${cardanocli} address build \
        --payment-verification-key-file ${key_path}/${wallet_name}.vkey \
        --stake-verification-key-file ${key_path}/${stake_name}.vkey \
        --out-file ${address_path}/${wallet_name}.addr \
        --testnet-magic $TESTNET_MAGIC
else
    #--------- Run program ---------
    info "Creating/Deriving cardano address from verification key"
    ${cardanocli} address build \
        --payment-verification-key-file ${key_path}/${wallet_name}.vkey \
        --out-file ${address_path}/${wallet_name}.addr \
        --testnet-magic $TESTNET_MAGIC
fi

info "Cardano address created ${address_path}/${wallet_name}.addr"
