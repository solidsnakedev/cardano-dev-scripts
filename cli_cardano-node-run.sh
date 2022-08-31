#!/bin/bash

#--------- Import common paths and functions ---------
source common.sh

HOSTADDR="0.0.0.0"
PORT="6000"
TOPOLOGY="/node/configuration/topology.json"
CONFIG="/node/configuration/config.json"
DBPATH="/node/db"
SOCKETPATH="/node/ipc/node.socket"

${cardanonode} run \
        --topology ${TOPOLOGY} \
        --database-path ${DBPATH} \
        --socket-path ${SOCKETPATH} \
        --host-addr ${HOSTADDR} \
        --port ${PORT} \
        --config ${CONFIG}