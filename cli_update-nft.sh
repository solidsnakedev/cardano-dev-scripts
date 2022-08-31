#!/bin/bash
set -o pipefail

#--------- Import common paths and functions ---------
source common.sh

#--------- Verification  ---------

# Verify correct number of arguments
if [[ "$#" -eq 0 || "$#" -ne 5 ]]; then error "Missing parameters" && info "Usage: update-asset.sh <wallet-name> <token-name> <amount-to-burn> <policy-name> <slot-number> "; exit 1; fi
# Get wallet name
wallet_origin=${1}
# Convert token name to Hex
# Note that asset names are now output in hex format when querying UTxO entries.
token_name=$(echo -n ${2} | xxd -ps | tr -d '\n')
# Get token amount to burn
amount_to_burn=${3}
# Get token amount to burn
policy_name=${4}
# Get slot number from policy script/
slot_number=${5}

# Verify if wallet skey exists
[[ -f ${key_path}/${wallet_origin}.skey ]] && info "OK ${wallet_origin}.skey exists" || { error "${wallet_origin}.skey missing"; exit 1; }
# Verify if policy vkey exists
[[ -f ${key_path}/${policy_name}.vkey ]] && info "OK ${policy_name}.vkey exists" || { error "${policy_name}.vkey missing"; exit 1; }
# Verify if policy script exists
[[ -f ${script_path}/${policy_name}.script ]] && info "OK ${policy_name}.script exists" || { error "${policy_name}.script missing"; exit 1; }
# Verify if protocol exists
[[ -f ${config_path}/protocol.json ]] && info "OK protocol.json exists" || { error "protocol.json missing"; exit 1; }

#--------- Run program ---------

# Compute policy id
asset_policy_id=$(${cardanocli} transaction policyid --script-file ${script_path}/${policy_name}.script)
info "Policy ID: ${asset_policy_id}"

# Query utxos from wallet
info "Queryng adddress: $(cat ${key_path}/${wallet_origin}.addr)"
${cardano_script_path}/query-utxo.sh ${wallet_origin}
# Get the total balance, and all utxos so they can be consumed when building the transaction
info "Getting all UTxO from ${wallet_origin}"
readarray results <<< "$(generate_UTXO ${wallet_origin})"
# Get total balance
total_balance=${results[0]}
# Get utxo inputs
tx_in=${results[1]}
# Get number of utxos inputs
tx_cnt=${results[2]}
# Get all native assets
native_assets=${results[3]}

# Filter native assets
readarray filter_asset_result <<< "$(filter_asset "${native_assets}" "${token_name}")"
# Get filtered native asset balance
native_asset_balance=${filter_asset_result[0]}
# Get filtered native asset name
native_asset_name=${filter_asset_result[1]}
# Calculate change of the native asset to be burnt
native_asset_change=$((native_asset_balance - amount_to_burn))
# Get remainders native assets
remainder_assets=${filter_asset_result[2]}
# Construct assets for tx outputs
if [[ -z ${remainder_assets} ]]; then
all_native_assets="${native_asset_change} ${native_asset_name}"
info ${all_native_assets}
else
all_native_assets="${remainder_assets} + ${native_asset_change} ${native_asset_name}"
info ${all_native_assets}
fi

#min_amount=$(${cardanocli} transaction calculate-min-required-utxo \
#    --babbage-era \
#    --protocol-params-file ${config_path}/protocol.json \
#    --tx-out-reference-script-file ${script_path}/${policy_name}.script \
#    --tx-out $(cat ${key_path}/${wallet_origin}.addr)+0+"${amount_to_burn} ${asset_policy_id}.${token_name}" | awk '{print $2}')
#
#info "Minimum UTxO: ${min_amount}"

info "Building Raw transaction"
${cardanocli} transaction build-raw \
    --babbage-era \
    --fee 0 \
    ${tx_in} \
    --tx-out "$(cat ${key_path}/${wallet_origin}.addr)+${total_balance}+${all_native_assets}" \
    --mint="-${amount_to_burn} ${native_asset_name}" \
    --minting-script-file ${script_path}/${policy_name}.script \
    --metadata-json-file ${data_path}/mint-nft-metadata.json \
    --invalid-hereafter ${slot_number} \
    --out-file ${key_path}/${policy_name}-tx.raw

fee=$(${cardanocli} transaction calculate-min-fee \
    --tx-body-file ${key_path}/${policy_name}-tx.raw \
    --tx-in-count ${tx_cnt} \
    --tx-out-count 1 \
    --witness-count 2 \
    --testnet-magic ${TESTNET_MAGIC} \
    --protocol-params-file ${config_path}/protocol.json | cut -d " " -f1)

info "Calc fee: ${fee}"
final_balance=$((total_balance - fee))

info "Building transaction"
${cardanocli} transaction build-raw \
    --babbage-era \
    --fee ${fee} \
    ${tx_in} \
    --tx-out "$(cat ${key_path}/${wallet_origin}.addr)+${final_balance}+${all_native_assets}" \
    --mint="-${amount_to_burn} ${native_asset_name}" \
    --minting-script-file ${script_path}/${policy_name}.script \
    --metadata-json-file ${data_path}/mint-nft-metadata.json \
    --invalid-hereafter ${slot_number} \
    --out-file ${key_path}/${policy_name}-tx.build

info "Signing transaction"
${cardanocli} transaction sign \
    --tx-body-file ${key_path}/${policy_name}-tx.build \
    --signing-key-file ${key_path}/${wallet_origin}.skey \
    --signing-key-file ${key_path}/${policy_name}.skey \
    --testnet-magic ${TESTNET_MAGIC} \
    --out-file ${key_path}/${policy_name}-tx.signed

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/${policy_name}-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."