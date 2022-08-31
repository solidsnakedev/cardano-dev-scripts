#!/bin/bash

#--------- Import common paths and functions ---------
source common.sh

# Verify correct number of arguments
if [[ "$#" -eq 0 || "$#" -ne 2 ]]; then error "Missing parameters" && info "Usage: pay-address-metadata.sh <wallet-name> <json-file>"; exit 1; fi
# Get wallet name
wallet_origin=${1}
# Get json file name
json_file=${2}

# Verify if wallet skey exists
[[ -f ${key_path}/${wallet_origin}.skey ]] && info "OK ${wallet_origin}.skey exists" || { error "${wallet_origin}.skey missing"; exit 1; }
# Verify if json file exists
[[ -f ${data_path}/${json_file}.json ]] && info "OK ${json_file}.json exists" || { error "${json_file}.json missing"; exit 1; }

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

info "Building transaction \n  Note: wallet origin and change address are the same"
${cardanocli} transaction build \
    --babbage-era \
    ${tx_in} \
    --change-address $(cat ${key_path}/${wallet_origin}.addr) \
    --metadata-json-file ${data_path}/${json_file}.json \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/metadata-tx.build

info "Signing transaction"
${cardanocli} transaction sign \
    --tx-body-file ${key_path}/metadata-tx.build \
    --signing-key-file ${key_path}/${wallet_origin}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/metadata-tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/metadata-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."
