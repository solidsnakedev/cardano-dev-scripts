#!/bin/bash
set -o pipefail

#--------- Import common paths and functions ---------
source common.sh

#--------- Verification  ---------

# Verify correct number of arguments 
if [[ "$#" -eq 0 || "$#" -ne 6 ]]; then error "Missing parameters" && info "Usage: mint-asset.sh <wallet-name> <token-name> <amount> <policy-name> <slot-number> <ipfs-cid> "; exit 1; fi
# Get wallet name 
wallet_origin=${1}
# Convert token name to Hex 
# Note that asset names are now output in hex format when querying UTxO entries.
real_token_name=${2}
token_name=$(echo -n ${real_token_name} | xxd -ps | tr -d '\n')
# Get token amount to mint 
token_amount=${3}
# Get token policy name 
policy_name=${4}
# Get slot number from policy script/
slot_number=${5}
# Get ipfs cid number 
ipfs_cid=${6}

# Verify if wallet skey exists
[[ -f ${key_path}/${wallet_origin}.skey ]] && info "OK ${wallet_origin}.skey exists" || { error "${wallet_origin}.skey missing"; exit 1; }
# Verify if policy vkey exists
[[ -f ${key_path}/${policy_name}.vkey ]] && info "OK ${policy_name}.vkey exists" || { error "${policy_name}.vkey missing"; exit 1; }
# Verify if policy script exists
[[ -f ${script_path}/${policy_name}.script ]] && info "OK ${policy_name}.script exists" || { error "${policy_name}.script missing"; exit 1; }
# Verify if protocol exists
[[ -f ${config_path}/protocol.json ]] && info "OK protocol.json exists" || { error "protocol.json missing"; exit 1; }

#--------- Run program ---------

info "Printing policy script file"
cat ${script_path}/${policy_name}.script
# Compute policy id
asset_policy_id=$(${cardanocli} transaction policyid --script-file ${script_path}/${policy_name}.script)
info "Policy ID: ${asset_policy_id}"

info "Generating NFT metadata json file"

#base64 -w 64 ${data_path}/bitcoin.png > ${data_path}/bitcoin.base64

#read -d "\n" -r -a array < ${data_path}/bitcoin.base64
#data=$(
#for line in ${array[@]}; do
#echo ",\"${line}\""
#done
#)

#cat > ${data_path}/mint-nft-metadata.json << EOF
# {
#  "721": {
#    "${asset_policy_id}": {
#      "${real_token_name}": {
#        "name": "${real_token_name}",
#        "description": "Bitcoin image on chain",
#        "image": $(echo "[\"data:image/png;base64,\"${data}]")
#      }
#    }
#  }
# }
#EOF


cat > ${data_path}/mint-nft-metadata.json << EOF
{
  "721": {
    "${asset_policy_id}": {
      "${real_token_name}": {
        "name": "${real_token_name}",
        "description": "${real_token_name} image on ipfs",
        "image": "ipfs://${ipfs_cid}"
      }
    }
  }
}
EOF

info "Printing NFT metadata json file"
cat ${data_path}/mint-nft-metadata.json

# Query utxos from wallet
info "Queryng adddress: $(cat ${key_path}/${wallet_origin}.addr)"
${cardano_script_path}/query-utxo.sh ${wallet_origin}

# Get the total balance, and all utxos so they can be consumed when building the transaction
info "Getting all UTxO from ${wallet_origin}"
readarray results <<< "$(generate_UTXO "${wallet_origin}")"

# Get total balance
total_balance=${results[0]}
# Get utxo inputs
tx_in=${results[1]}
# Get number of utxos inputs
tx_cnt=${results[2]}
# Get all native assets
native_assets=${results[3]}
if [[ -z "${native_assets}" ]]; then
all_native_assets="${token_amount} ${asset_policy_id}.${token_name}"
else
all_native_assets="${native_assets} + ${token_amount} ${asset_policy_id}.${token_name}" 
fi

#min_amount=$(${cardanocli} transaction calculate-min-required-utxo \
#    --babbage-era \
#    --protocol-params-file ${config_path}/protocol.json \
#    --tx-out-reference-script-file ${script_path}/${policy_name}.script \
#    --tx-out $(cat ${key_path}/${wallet_origin}.addr)+0+"${token_amount} ${asset_policy_id}.${token_name}" | awk '{print $2}')
#
#info "Minimum UTxO: ${min_amount}"

info "Building Raw transaction"
${cardanocli} transaction build-raw \
    --babbage-era \
    --fee 0 \
    ${tx_in} \
    --tx-out "$(cat ${key_path}/${wallet_origin}.addr)+${total_balance}+${all_native_assets}" \
    --mint="${token_amount} ${asset_policy_id}.${token_name}" \
    --minting-script-file ${script_path}/${policy_name}.script \
    --metadata-json-file ${data_path}/mint-nft-metadata.json \
    --invalid-hereafter ${slot_number} \
    --out-file ${key_path}/${policy_name}-tx.raw

fee=$(${cardanocli} transaction calculate-min-fee \
    --tx-body-file ${key_path}/${policy_name}-tx.raw \
    --tx-in-count ${tx_cnt} \
    --tx-out-count 1 \
    --witness-count 1 \
    --testnet-magic ${TESTNET_MAGIC} \
    --protocol-params-file ${config_path}/protocol.json | cut -d " " -f1)

info "Calc fee: ${fee}"

final_balance=$((total_balance - fee))
info "Final balance: ${final_balance}"


info "Building transaction"
${cardanocli} transaction build-raw \
    --babbage-era \
    --fee ${fee} \
    ${tx_in} \
    --tx-out "$(cat ${key_path}/${wallet_origin}.addr)+${final_balance}+${all_native_assets}" \
    --mint="${token_amount} ${asset_policy_id}.${token_name}" \
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

#debug "exiting before submiting tx"

info "Submiting transaction"
${cardanocli} transaction submit \
    --tx-file ${key_path}/${policy_name}-tx.signed \
    --testnet-magic ${TESTNET_MAGIC}

info "Wait for ~20 seconds so the transaction is in the blockchain."