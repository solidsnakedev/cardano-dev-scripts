#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common.sh

#--------- Run program ---------
info "This program requires 2 witnesses to sign the transaction in order to spend the utxo"

info "List of Addresses" && ls -1 ${key_path}/*.addr

read -p "Insert origin 1 address (example payment1) : " wallet_origin1 && ${cardano_script_path}/query-utxo.sh ${wallet_origin1}
read -p "Insert tx-in : " txIn1
read -p "Insert tx-in id : " txInId1

read -p "Insert origin 2 address (example payment2) : " wallet_origin2 && ${cardano_script_path}/query-utxo.sh ${wallet_origin2}
read -p "Insert tx-in : " txIn2
read -p "Insert tx-in id : " txInId2

read -p "Insert wallet destination address to pay (example payment2) : " wallet_dest
read -p "Insert wallet change address (example payment1) : " wallet_change

read -p "Insert amount to send (example 500 ADA = 500,000,000 lovelace) : " amount

info "Building transaction \n  Note: tx-in consumed from 2 origin addresses, and 1 txout to destination address"
${cardanocli} transaction build \
    --babbage-era \
    --tx-in "${txIn1}#${txInId1}" \
    --tx-in "${txIn2}#${txInId2}" \
    --tx-out $(cat ${key_path}/${wallet_dest}.addr)+${amount} \
    --change-address $(cat ${key_path}/${wallet_change}.addr) \
    --witness-override 2 \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/multisig-tx.build

info "Signing transaction witness 1"
${cardanocli} transaction witness \
    --tx-body-file ${key_path}/multisig-tx.build \
    --signing-key-file ${key_path}/${wallet_origin1}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/${wallet_origin1}.witness

info "Signing transaction witness 2"
${cardanocli} transaction witness \
    --tx-body-file ${key_path}/multisig-tx.build \
    --signing-key-file ${key_path}/${wallet_origin2}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/${wallet_origin2}.witness

info "Assembling transaction witness 1 and 2"
${cardanocli} transaction assemble \
    --tx-body-file ${key_path}/multisig-tx.build \
    --witness-file ${key_path}/${wallet_origin1}.witness \
    --witness-file ${key_path}/${wallet_origin2}.witness \
    --out-file ${key_path}/multisig-tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/multisig-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."
