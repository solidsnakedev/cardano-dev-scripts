#!/bin/bash
set -uo pipefail

#--------- Import common paths and functions ---------
source common.sh

# Verify if protocol exists
[[ -f ${config_path}/protocol.json ]] && info "OK protocol.json exists" || { error "protocol.json missing"; exit 1; }

#--------- Run program ---------
read -p "Insert Datum value (example 6666) : " datum_value
info "Calculating Datum Hash"
datum_hash=$(${cardanocli} transaction hash-script-data --script-data-value ${datum_value})
info "Datum Hash : ${datum_hash}"

read -p "Insert plutus script name (example AlwaysSucceeds) : " script_name
info "Querying script utxo and filter by Datum Hash"
${cardano_script_path}/query-utxo.sh ${script_name} | grep ${datum_hash}
if [[ $? -ne 0 ]]; then error "Could not find Datum Hash in script utxos!. Insert a different Datum value"; exit 1; fi

read -p "Insert TxHash from script utxo: " txIn_script
read -p "Insert TxIx id from script utxo: " txInId_script
read -p "Insert amount to send from script utxo (example 500 ADA = 500,000,000 lovelace) : " amount
ls -1 ${script_path}/*.plutus
read -p "Insert redeemer value (example 42) : " redeemer_value

info "Select a wallet to be used as tx-in and collateral"
ls -1 ${key_path}/*.addr
read -p "Insert wallet origin address (example payment1) : " wallet_origin
${cardano_script_path}/query-utxo.sh ${wallet_origin}
read -p "Insert TxHash : " txIn_origin
read -p "Insert TxIx id : " txInId_origin

read -p "Insert wallet destination address to pay (example payment2) : " wallet_dest


info "Building transaction"
${cardanocli} transaction build \
    --babbage-era \
    --testnet-magic ${TESTNET_MAGIC} \
    --tx-in "${txIn_origin}#${txInId_origin}" \
    --tx-in "${txIn_script}#${txInId_script}" \
    --tx-in-datum-value ${datum_value} \
    --tx-in-redeemer-value ${redeemer_value} \
    --tx-in-script-file ${script_path}/${script_name}.plutus \
    --tx-in-collateral "${txIn_origin}#${txInId_origin}" \
    --change-address $(cat ${key_path}/${wallet_origin}.addr) \
    --tx-out $(cat ${key_path}/${wallet_dest}.addr)+${amount} \
    --tx-out-datum-hash ${datum_hash} \
    --protocol-params-file ${config_path}/protocol.json \
    --out-file ${key_path}/${script_name}-tx.build

info "Signing transaction"
${cardanocli} transaction sign \
    --tx-body-file ${key_path}/${script_name}-tx.build \
    --signing-key-file ${key_path}/${wallet_origin}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/${script_name}-tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/${script_name}-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."