#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

node=tidb_pushgateway
ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b${node}\b/" hosts)
docker run -dit --name ${node} --hostname ${node} --rm --net static_net0 --ip ${ip} prom/pushgateway:v0.3.1 --log.level=error
