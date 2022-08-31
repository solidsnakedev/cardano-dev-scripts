#!/bin/bash
set -o pipefail

#--------- Import common paths and functions ---------
source common.sh

#--------- Verification  ---------

# Verify correct number of arguments
if [[ "$#" -eq 0 || "$#" -ne 1 ]]; then error "Missing parameters" && info "Usage: gen-policy-asset.sh <policy-name> "; exit 1; fi
# Get policy name
policy_name=${1}

# Verify if policy vkey exists
[[ -f ${key_path}/${policy_name}.vkey ]] && info "OK ${policy_name}.vkey exists" || { error "${policy_name}.vkey missing"; exit 1; }

#--------- Run program ---------

# Create policy script
info "Creating ${script_path}/${policy_name}.script"

cat > ${script_path}/${policy_name}.script << EOF
{
  "type": "sig",
  "keyHash": "$(${cardanocli} address key-hash --payment-verification-key-file ${key_path}/${policy_name}.vkey)"
}
EOF

cat ${script_path}/${policy_name}.script