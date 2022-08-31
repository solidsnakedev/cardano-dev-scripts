#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common.sh

# Verify correct number of arguments  ---------
if [[ "$#" -eq 0 || "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: recycle-utxo.sh <wallet-origin> "; exit 1; fi
# Get wallet name
wallet_origin=${1}

# Verify if wallet skey exists
[[ -f ${key_path}/${wallet_origin}.skey ]] && info "OK ${wallet_origin}.skey exists" || { error "${wallet_origin}.skey missing"; exit 1; }


#--------- Run program ---------
info "Queryng adddress: $(cat ${key_path}/${wallet_origin}.addr)"
${cardano_script_path}/query-utxo.sh ${wallet_origin}

#--------- Query utxos and save it in fullUtxo.out ---------
${cardanocli} query utxo \
    --address $(cat ${key_path}/${wallet_origin}.addr) \
    --testnet-magic ${TESTNET_MAGIC} > ${data_path}/fullUtxo.out

#--------- Remove 3 first rows, and sort balance ---------
tail -n +3 ${data_path}/fullUtxo.out | sort -k3 -nr > ${data_path}/balance.out

#--------- Print balance ---------
cat ${data_path}/balance.out

#--------- Read balance.out file and compose utxo inputs ---------
tx_in=""
total_balance=0
while read -r utxo; do
    in_addr=$(awk '{ print $1 }' <<< "${utxo}")
    idx=$(awk '{ print $2 }' <<< "${utxo}")
    utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
    total_balance=$((${total_balance}+${utxo_balance}))
    info "TxHash: ${in_addr}#${idx}"
    info "Lovelace: ${utxo_balance}"
    tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
    info ${tx_in}
done < ${data_path}/balance.out
txcnt=$(cat ${data_path}/balance.out | wc -l)
info "Total ADA balance: ${total_balance}"
info "Number of UTXOs: ${txcnt}"
echo ${tx_in}

#--------- Build transaction ---------
info "Building transaction"
${cardanocli} transaction build \
    --babbage-era \
    ${tx_in} \
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