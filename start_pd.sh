#!/bin/bash
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
pdRoot=${basedir}/../tidb_all/pd

bootstrap=$1;shift
set -e -o pipefail
if [ -n "${bootstrap}" ];then
  rm -fr ${basedir:?"undefined"}/pd_server?_data/*
  rm -fr ${basedir:?"undefined"}/pd_server?_logs/*
fi

pdNum=3

for node in $(eval "echo pd_server{0..$((${pdNum}-1))}") ;do
  set +e +o pipefail
  docker kill ${node}
  docker rm ${node}
  set -e -o pipefail
done

cd ${basedir}

dockerFlags="-tid --rm -w /home/tidb/pd -u tidb --privileged --net static_net0
  -v ${PWD}/hosts:/etc/hosts -v ${pdRoot}:/home/tidb/pd -v ${PWD}/pd_server_conf:/home/tidb/pd/conf"

for node in $(eval "echo pd_server{0..$((${pdNum}-1))}") ;do
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"$_=http://$h{$_}:2380"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:/home/tidb/pd/data
  -v ${PWD}/${node}_logs:/home/tidb/pd/logs
  --name $node
  --hostname $node
  --ip $ip
  "
  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    bin/pd-server \
    --name=${node} \
    --client-urls=http://${ip}:2379 \
    --advertise-client-urls=http://${ip}:2379 \
    --peer-urls=http://${ip}:2380 \
    --advertise-peer-urls=http://${ip}:2380 \
    --data-dir=/home/tidb/pd/data \
    --config=/home/tidb/pd/conf/pd.toml \
    --log-file=/home/tidb/pd/logs/pd.log \
    --initial-cluster=${cluster}
done
