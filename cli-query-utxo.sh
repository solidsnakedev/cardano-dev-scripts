#!/bin/bash

#--------- Import common paths and functions ---------
source common-utils.sh

#--------- Verification process  ---------
if [[ "$#" -eq 0 || "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: query-utxo <wallet-name>"; exit 1; fi
# Get wallet name
wallet_origin=${1}

# Verify if wallet addr exists
[[ -f ${address_path}/${wallet_origin}.addr ]] || { error "${wallet_origin}.addr missing"; exit 1; }

#--------- Run program ---------
${cardanocli} query utxo \
  --testnet-magic $TESTNET_MAGIC \
  --address $(cat ${address_path}/${wallet_origin}.addr)