#!/bin/bash
set -euo pipefail

#--------- Import common paths and functions ---------
source common.sh

${cardanocli} query tip --testnet-magic $TESTNET_MAGIC