#!/bin/bash
set -o pipefail

#--------- Import common paths and functions ---------
source common.sh

#--------- Verification  ---------

# Verify correct number of arguments
if [[ "$#" -eq 0 ]]; then error "Missing parameters" && info "Usage: gen-key.sh <wallet-name> <stake-name> | gen-key.sh <wallet-name>"; exit 1; fi
# Get wallet name
wallet_name=${1}

#--------- Run program ---------

${cardanocli} address key-gen \
    --verification-key-file ${key_path}/${wallet_name}.vkey \
    --signing-key-file ${key_path}/${wallet_name}.skey

info "Keys ${wallet_name}.vkey and ${wallet_name}.skey saved in ${key_path}/"

if [[ -z ${2} ]]; then exit 0; fi
stake_name=${2}

${cardanocli} stake-address key-gen \
    --verification-key-file ${key_path}/${stake_name}.vkey \
    --signing-key-file ${key_path}/${stake_name}.skey

info "Keys ${stake_name}.vkey and ${stake_name}.skey saved in ${key_path}/"