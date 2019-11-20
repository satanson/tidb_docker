#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

goycsb_basedir=$(cd ${basedir}/../tidb_all/go-ycsb;pwd)

${goycsb_basedir}/bin/go-ycsb load mysql -p mysql.host=tidb_server0 -p mysql.port=4000 -p mysql.user=root -p mysql.password="" -p mysql.db=test -p insertproportion=1.0 -p recordcount=2000000 -p operationcount=20000000sb load mysql -p mysql.host=tidb_server0 -p mysql.port=4000 -p mysql.user=root -p mysql.password="" -p mysql.db=test -p insertproportion=1.0
