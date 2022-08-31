#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common.sh

# Verify correct number of arguments
if [[ "$#" -eq 0 || "$#" -ne 4 ]]; then error "Missing parameters" && info "Usage: pay-plutus-script.sh <wallet-origin> <script-name> <amount> <datum> "; exit 1; fi
# Get wallet name
wallet_origin=${1}
# Get plutus script name
script_name=${2}
# Get amount to send
amount=${3}
# Get datum value 
datum_value=${4}

# Verify if wallet skey exists
[[ -f ${key_path}/${wallet_origin}.skey ]] && info "OK ${wallet_origin}.skey exists" || { error "${wallet_origin}.skey missing"; exit 1; }
# Verify if plutus script exists
[[ -f ${script_path}/${script_name}.plutus ]] && info "OK ${script_name}.plutus exists" || { error "${script_name}.plutus missing"; exit 1; }

#--------- Run program ---------

# Query utxos
${cardano_script_path}/query-utxo.sh ${wallet_origin}
# Get the total balance, and all utxos so they can be consumed when building the transaction
info "Getting all utxos from ${wallet_origin}"
readarray results <<< "$(generate_UTXO ${wallet_origin})"
# Set total balance
total_balance=${results[0]}
# Set utxo inputs
tx_in=${results[1]}

datum_hash=$(${cardanocli} transaction hash-script-data --script-data-value ${datum_value})
info "Datum Hash : ${datum_hash}"

info "Building transaction"
${cardanocli} transaction build \
    --babbage-era \
    ${tx_in} \
    --tx-out $(cat ${key_path}/${script_name}.addr)+${amount} \
    --tx-out-datum-hash ${datum_hash} \
    --change-address $(cat ${key_path}/${wallet_origin}.addr) \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/plutus-tx.build

info "Signing transaction"
${cardanocli} transaction sign \
    --tx-body-file ${key_path}/plutus-tx.build \
    --signing-key-file ${key_path}/${wallet_origin}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/plutus-tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/plutus-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."