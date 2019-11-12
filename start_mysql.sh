#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}
dockerFlags="--rm --name mysql_tidb_client0 --hostname mysql_tidb_client0 --net static_net0 --ip 192.168.173.80 -v ${PWD}/hosts:/etc/hosts"
docker run -it ${dockerFlags} mysql:5.7 mysql -h tidb_server0 -P 4000 -u root -p
