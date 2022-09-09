#!/bin/bash

#--------- Import common paths and functions ---------
source common-utils.sh

#--------- Help  ---------
if [[ "$1" == "--help" ]]; then
echo "cli-query-utxo-json.sh wallet1 | jq '. | {ada : .\"2f296e95c76b7797640112e94a8e2ef3757c34aedc51ffbbb7d0aa0399cf2907#0\".value.lovelace}'"
exit 0; fi

#--------- Verification process  ---------
if [[ "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: query-utxo <wallet-name> | --help"; exit 1; fi


# Get wallet name
wallet_origin=${1}

# Verify if wallet addr exists
[[ -f ${address_path}/${wallet_origin}.addr ]] || { error "${wallet_origin}.addr missing"; exit 1; }

#--------- Run program ---------
${cardanocli} query utxo \
  --testnet-magic $TESTNET_MAGIC \
  --address $(cat ${address_path}/${wallet_origin}.addr) \
  --out-file ${data_path}/query-utxo.json

cat ${data_path}/query-utxo.json | jq 