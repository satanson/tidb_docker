#!/bin/bash
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
bootstrap=$1;shift
tidbRoot=${basedir}/../tidb_all/tidb

set -e -o pipefail
if [ -n "${bootstrap}" ];then
  rm -fr ${basedir:?"undefined"}/tidb_server?_data/*
  rm -fr ${basedir:?"undefined"}/tidb_server?_logs/*
fi

tidbNum=3
for node in $(eval "echo tidb_server{0..$((${tidbNum}-1))}") ;do
  set +e +o pipefail
  docker kill ${node}
  docker rm ${node}
  set -e -o pipefail
done

cd ${basedir}

dockerFlags="-tid --rm -w /home/tidb/tidb -u tidb --privileged --net static_net0
  -v ${PWD}/hosts:/etc/hosts -v ${tidbRoot}:/home/tidb/tidb -v ${PWD}/tidb_server_conf:/home/tidb/tidb/conf"

for node in $(eval "echo tidb_server{0..$((${tidbNum}-1))}") ;do
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"$h{$_}:2379"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:/home/tidb/tidb/data
  -v ${PWD}/${node}_logs:/home/tidb/tidb/logs
  --name $node
  --hostname $node
  --ip $ip
  "

  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    /home/tidb/tidb/bin/tidb-server \
    -P 4000 \
    --status=10080 \
    --advertise-address=${ip} \
    --path=${cluster} \
    --config=/home/tidb/tidb/conf/tidb.toml \
    --log-slow-query=/home/tidb/tidb/tidb_slow_query.log \
    --log-file=/home/tidb/tidb/logs/tidb.log
done
