set -euo pipefail

#--------- Import common paths and functions ---------
source common-utils.sh

#--------- Run program ---------
info "The following program will consume all the utxos from the native script"

info "Select witnesses of the native script" && ls -1 ${address_path}/*.addr

read -p "Insert witness origin 1 address (example payment1) : " wallet_origin1
read -p "Insert witness origin 2 address (example payment2) : " wallet_origin2 

read -p "Insert native script name (example multisig-policy) : " policy_name

# Query utxos
${cardano_script_path}/cli-query-utxo.sh ${policy_name}
# Get the total balance, and all utxos so they can be consumed when building the transaction
info "Getting all utxos from ${policy_name}"
readarray results <<< "$(generate_UTXO ${policy_name})"
# Set total balance
total_balance=${results[0]}
# Set utxo inputs
tx_in=${results[1]}

info "Select the receiver of the utxo" && ls -1 ${address_path}/*.addr
info "Note: utxo is consumed from native script and total amount is sent to change address"
read -p "Insert change/receiver address (example payment3) : " wallet_change

info "Building transaction"
${cardanocli} transaction build \
    --babbage-era \
    ${tx_in} \
    --tx-in-script-file ${native_script_path}/${policy_name}.script \
    --change-address $(cat ${address_path}/${wallet_change}.addr) \
    --witness-override 2 \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${transaction_path}/${policy_name}-tx.build

info "Signing transaction witness 1"
${cardanocli} transaction witness \
    --tx-body-file ${transaction_path}/${policy_name}-tx.build \
    --signing-key-file ${key_path}/${wallet_origin1}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${transaction_path}/${wallet_origin1}.witness

info "Signing transaction witness 2"
${cardanocli} transaction witness \
    --tx-body-file ${transaction_path}/${policy_name}-tx.build \
    --signing-key-file ${key_path}/${wallet_origin2}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${transaction_path}/${wallet_origin2}.witness

info "Assembling transaction witness 1 and 2"
${cardanocli} transaction assemble \
    --tx-body-file ${transaction_path}/${policy_name}-tx.build \
    --witness-file ${transaction_path}/${wallet_origin1}.witness \
    --witness-file ${transaction_path}/${wallet_origin2}.witness \
    --out-file ${transaction_path}/${policy_name}-tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${transaction_path}/${policy_name}-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."