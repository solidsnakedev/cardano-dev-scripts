#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common-utils.sh

${cardanocli} query tip --testnet-magic $TESTNET_MAGIC