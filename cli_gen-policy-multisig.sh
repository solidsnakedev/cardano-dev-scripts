#!/bin/bash
set -o pipefail

#--------- Import common paths and functions ---------
source common.sh

#--------- Verification  ---------

# Verify correct number of arguments
if [[ "$#" -eq 0 || "$#" -ne 3 ]]; then error "Missing parameters" && info "Usage: gen-policy-multisig.sh <wallet-witness-1> <wallet-witness-2> <policy-name>"; exit 1; fi
# Get wallet name
wallet_origin1=${1}
wallet_origin2=${2}
# Get policy name
policy_name=${3}

# Verify if wallet vkey exists
[[ -f ${key_path}/${wallet_origin1}.vkey ]] && info "OK ${wallet_origin1}.vkey exists" || { error "${wallet_origin1}.vkey missing"; exit 1; }
[[ -f ${key_path}/${wallet_origin2}.vkey ]] && info "OK ${wallet_origin2}.vkey exists" || { error "${wallet_origin2}.vkey missing"; exit 1; }

#--------- Run program ---------

# Create policy script

info "Creating ${script_path}/${policy_name}.script from 2 witnesses ${wallet_origin1} and ${wallet_origin2}"

cat > ${script_path}/${policy_name}.script << EOF
{
  "type": "all",
  "scripts":
  [
    {
      "type": "sig",
      "keyHash": "$(${cardanocli} address key-hash --payment-verification-key-file ${key_path}/${wallet_origin1}.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(${cardanocli} address key-hash --payment-verification-key-file ${key_path}/${wallet_origin2}.vkey)"
    }
  ]
}
EOF
cat ${script_path}/${policy_name}.script

info "This policy requires 2 witnesses in order to spend the utxo from the native script"