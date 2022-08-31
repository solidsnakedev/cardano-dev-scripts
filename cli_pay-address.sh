#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common.sh

# Verify correct number of arguments  ---------
if [[ "$#" -eq 0 || "$#" -ne 3 ]]; then error "Missing parameters" && info "Usage: pay-address.sh <wallet-origin> <wallet-destination> <amount> "; exit 1; fi
# Get wallet name
wallet_origin=${1}
# Get wallet destination
wallet_dest=${2}
# Get amount to send
amount=${3}

# Verify if wallet skey exists
[[ -f ${key_path}/${wallet_origin}.skey ]] && info "OK ${wallet_origin}.skey exists" || { error "${wallet_origin}.skey missing"; exit 1; }

#--------- Run program

# Query utxos
${cardano_script_path}/query-utxo.sh ${wallet_origin}
# Get the total balance, and all utxos so they can be consumed when building the transaction
info "Getting all utxos from ${wallet_origin}"
readarray results <<< "$(generate_UTXO ${wallet_origin})"
# Set total balance
total_balance=${results[0]}
# Set utxo inputs
tx_in=${results[1]}

info "Building transaction"
${cardanocli} transaction build \
    --babbage-era \
    ${tx_in} \
    --tx-out $(cat ${key_path}/${wallet_dest}.addr)+${amount} \
    --change-address $(cat ${key_path}/${wallet_origin}.addr) \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/tx.build

info "Signing transaction"
${cardanocli} transaction sign \
    --tx-body-file ${key_path}/tx.build \
    --signing-key-file ${key_path}/${wallet_origin}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."
