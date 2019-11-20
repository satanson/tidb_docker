#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
test  ${basedir} == ${PWD}
tidbLocalRoot=$(cd ${basedir}/../tidb_all;pwd)
tidbDockerRoot=/home/tidb/tidb_all

pd_server_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+pd_server\d+\s*$/' ${PWD}/hosts |wc -l);
tikv_server_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+tikv_server\d+\s*$/' ${PWD}/hosts |wc -l);
tidb_server_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+tidb_server\d+\s*$/' ${PWD}/hosts |wc -l);
binlog_pump_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+binlog_pump\d+\s*$/' ${PWD}/hosts |wc -l);
binlog_drainer_num=$(perl -ne 'print if /^\s*\d+(\.\d+){3}\s+binlog_drainer\d+\s*$/' ${PWD}/hosts |wc -l);

dockerFlags="-tid --rm -u tidb --privileged --net static_net0 -v ${PWD}/hosts:/etc/hosts -v ${tidbLocalRoot}:${tidbDockerRoot}"

stop_node(){
  local name=$1;shift
  set +e +o pipefail
  docker kill ${name}
  docker rm ${name}
  set -e -o pipefail
}

## pd-server

bootstrap_pd_server(){
  local node=${1:?"undefined 'pd_server'"};shift
  stop_node ${node}
  rm -fr ${basedir:?"undefined"}/${node}_data/*
  rm -fr ${basedir:?"undefined"}/${node}_logs/*
}

bootstrap_all_pd_server(){
  for node in $(eval "echo pd_server{0..$((${pd_server_num}-1))}") ;do
    bootstrap_pd_server ${node}
  done
}

stop_pd_server(){
  local node=${1:?"undefined 'pd_server'"};shift
  stop_node ${node}
}

stop_all_pd_server(){
  for node in $(eval "echo pd_server{0..$((${pd_server_num}-1))}") ;do
    stop_pd_server ${node}
  done
}

start_pd_server(){
  local node=${1:?"undefined 'pd_server'"};shift
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"$_=http://$h{$_}:2380"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:${tidbDockerRoot}/pd/data
  -v ${PWD}/${node}_logs:${tidbDockerRoot}/pd/logs
  -v ${PWD}/pd_server_conf:${tidbDockerRoot}/pd/conf
  --name $node
  --hostname $node
  --ip $ip
  "
  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    ${tidbDockerRoot}/pd/bin/pd-server \
    --name=${node} \
    --client-urls=http://${ip}:2379 \
    --advertise-client-urls=http://${ip}:2379 \
    --peer-urls=http://${ip}:2380 \
    --advertise-peer-urls=http://${ip}:2380 \
    --data-dir=${tidbDockerRoot}/pd/data \
    --config=${tidbDockerRoot}/pd/conf/pd.toml \
    --log-file=${tidbDockerRoot}/pd/logs/pd.log \
    --initial-cluster=${cluster}
}

start_all_pd_server(){
  for node in $(eval "echo pd_server{0..$((${pd_server_num}-1))}") ;do
    start_pd_server ${node}
  done
}

restart_pd_server(){
  local node=${1:?"undefined 'pd_server'"};shift
  stop_pd_server ${node}
  start_pd_server ${node}
}

restart_all_pd_server(){
  for node in $(eval "echo pd_server{0..$((${pd_server_num}-1))}") ;do
    restart_pd_server ${node}
  done
}

#################################################################
## tikv-server

bootstrap_tikv_server(){
  local name=$1;shift
  stop_node ${name}
  rm -fr ${basedir:?"undefined"}/${name}_data/*
  rm -fr ${basedir:?"undefined"}/${name}_logs/*
}

bootstrap_all_tikv_server(){
  for node in $(eval "echo tikv_server{0..$((${tikv_server_num}-1))}") ;do
    bootstrap_tikv_server ${node}
  done
}

stop_tikv_server(){
  local name=$1;shift
  stop_node ${name}
}

stop_all_tikv_server(){
  for node in $(eval "echo tikv_server{0..$((${tikv_server_num}-1))}") ;do
    stop_node ${node}
  done
}

start_tikv_server(){
  local name=$1;shift
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"http://$h{$_}:2379"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:${tidbDockerRoot}/tikv/data
  -v ${PWD}/${node}_logs:${tidbDockerRoot}/tikv/logs
  -v ${PWD}/tikv_server_conf:${tidbDockerRoot}/tikv/conf
  --name $node
  --hostname $node
  --ip $ip
  "
  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    ${tidbDockerRoot}/tikv/bin/tikv-server \
    --addr 0.0.0.0:20171 \
    --advertise-addr ${ip}:20171 \
    --pd ${cluster} \
    --data-dir ${tidbDockerRoot}/tikv/data \
    --config ${tidbDockerRoot}/tikv/conf/tikv.toml \
    --log-file ${tidbDockerRoot}/tikv/logs/tikv.log 
}

start_all_tikv_server(){
  for node in $(eval "echo tikv_server{0..$((${tikv_server_num}-1))}") ;do
    start_tikv_server ${node}
  done
}

restart_tikv_server(){
  local node=$1;shift
  stop_node ${node}
  start_tikv_server ${node}
}

restart_all_tikv_server(){
  for node in $(eval "echo tikv_server{0..$((${tikv_server_num}-1))}") ;do
    restart_tikv_server ${node}
  done
}

###############################################################################
# tidb

bootstrap_tidb_server(){
  local node=${1:?"undefined tidb_server"};shift
  stop_node ${node}
  rm -fr ${basedir:?"undefined"}/${node}_data/*
  rm -fr ${basedir:?"undefined"}/${node}_logs/*
}

bootstrap_all_tidb_server(){
  for node in $(eval "echo tidb_server{0..$((${tidb_server_num}-1))}") ;do
    bootstrap_tidb_server ${node}
  done
}

stop_tidb_server(){
  local node=${1:?"undefined tidb_server"};shift
  stop_node ${node}
}

stop_all_tidb_server(){
  for node in $(eval "echo tidb_server{0..$((${tidb_server_num}-1))}") ;do
    stop_tidb_server ${node}
  done
}

start_tidb_server(){
  local node=${1:?"undefined tidb_server"};shift
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"$h{$_}:2379"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:${tidbDockerRoot}/tidb/data
  -v ${PWD}/${node}_logs:${tidbDockerRoot}/tidb/logs
  -v ${PWD}/tidb_server_conf:${tidbDockerRoot}/tidb/conf
  --name $node
  --hostname $node
  --ip $ip
  "

  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    ${tidbDockerRoot}/tidb/bin/tidb-server \
    -P 4000 \
    --status=10080 \
    --advertise-address=${ip} \
    --path=${cluster} \
    --config=${tidbDockerRoot}/tidb/conf/tidb.toml \
    --log-slow-query=${tidbDockerRoot}/tidb/log/tidb_slow_query.log \
    --log-file=${tidbDockerRoot}/tidb/logs/tidb.log 
}

start_all_tidb_server(){
  for node in $(eval "echo tidb_server{0..$((${tidb_server_num}-1))}") ;do
    start_tidb_server ${node}
  done
}

restart_tidb_server(){
  local node=${1:?"undefined tidb_server"};shift
  stop_tidb_server ${node}
  start_tidb_server ${node}
}

restart_all_tidb_server(){
  for node in $(eval "echo tidb_server{0..$((${tidb_server_num}-1))}") ;do
    restart_tidb_server ${node}
  done
}

start_binlog_pump(){
  local node=${1:?"undefined pump"};shift
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"http://$h{$_}:2379"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:${tidbDockerRoot}/binlog_pump/data
  -v ${PWD}/${node}_logs:${tidbDockerRoot}/binlog_pump/logs
  -v ${PWD}/binlog_pump_conf:${tidbDockerRoot}/binlog_pump/conf
  --name $node
  --hostname $node
  --ip $ip
  "
  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    bash -c "${tidbDockerRoot}/tidb-binlog/bin/pump \
    -L debug \
    --config=${tidbDockerRoot}/binlog_pump/conf/pump.toml \
    --log-file=${tidbDockerRoot}/binlog_pump/logs/pump.log \
    --data-dir=${tidbDockerRoot}/binlog_pump/data \
    --addr=${ip}:8250 \
    --advertise-addr=${ip}:8250 \
    --pd-urls=${cluster} \
    >${tidbDockerRoot}/binlog_pump/logs/stdout \
    2>${tidbDockerRoot}/binlog_pump/logs/stderr"
}

start_binlog_drainer(){
  local node=${1:?"undefined drainer"};shift
	ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  cluster=$(perl -aF'\s+' -lne '$h{$F[1]}=$F[0] if /pd_server/}{print join ",", map{"http://$h{$_}:2379"} sort keys %h' hosts)
  flags="
  -v ${PWD}/${node}_data:${tidbDockerRoot}/binlog_drainer/data
  -v ${PWD}/${node}_logs:${tidbDockerRoot}/binlog_drainer/logs
  -v ${PWD}/binlog_drainer_conf:${tidbDockerRoot}/binlog_drainer/conf
  --name $node
  --hostname $node
  --ip $ip
  "
  rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs
  docker run ${dockerFlags} ${flags} pingcap/rust:latest \
    ${tidbDockerRoot}/tidb-binlog/bin/drainer \
    -L debug \
    --config=${tidbDockerRoot}/binlog_drainer/conf/drainer.toml \
    --log-file=${tidbDockerRoot}/binlog_drainer/logs/drainer.log \
    --data-dir=${tidbDockerRoot}/binlog_drainer/data  \
    --addr=${ip}:8249 \
    --advertise-addr=${ip}:8249 \
    --pd-urls=${cluster} 
}

stop_binlog_pump(){
  local node=${1:?"undefined pump"};shift
  stop_node ${node}
}

stop_binlog_drainer(){
  local node=${1:?"undefined drainer"};shift
  stop_node ${node}
}

restart_binlog_pump(){
  local node=${1:?"undefined pump"};shift
  stop_binlog_pump ${node}
  start_binlog_pump ${node}
}

restart_binlog_drainer(){
  local node=${1:?"undefined drainer"};shift
  stop_binlog_drainer ${node}
  start_binlog_drainer ${node}
}

bootstrap_binlog_pump(){
  local node=${1:?"undefined pump"};shift
  stop_node ${node}
  [ -d ${PWD}/${node}_data ] && rm -fr ${PWD}/${node}_data/*
  [ -d ${PWD}/${node}_logs ] && rm -fr ${PWD}/${node}_logs/*
}

bootstrap_binlog_drainer(){
  local node=${1:?"undefined drainer"};shift
  stop_node ${node}
  [ -d ${PWD}/${node}_data ] && rm -fr ${PWD}/${node}_data/*
  [ -d ${PWD}/${node}_logs ] && rm -fr ${PWD}/${node}_logs/*
}

start_all_binlog_pump(){
  for node in $(eval "echo binlog_pump{0..$((${binlog_pump_num}-1))}") ;do
    start_binlog_pump ${node}
  done
}

start_all_binlog_drainer(){
  for node in $(eval "echo binlog_drainer{0..$((${binlog_drainer_num}-1))}") ;do
    start_binlog_drainer ${node}
  done
}

stop_all_binlog_pump(){
  for node in $(eval "echo binlog_pump{0..$((${binlog_pump_num}-1))}") ;do
    stop_binlog_pump ${node}
  done
}

stop_all_binlog_drainer(){
  for node in $(eval "echo binlog_drainer{0..$((${binlog_drainer_num}-1))}") ;do
    stop_binlog_drainer ${node}
  done
}

restart_all_binlog_pump(){
  for node in $(eval "echo binlog_pump{0..$((${binlog_pump_num}-1))}") ;do
    restart_binlog_pump ${node}
  done
}

restart_all_binlog_drainer(){
  for node in $(eval "echo binlog_drainer{0..$((${binlog_drainer_num}-1))}") ;do
    restart_binlog_drainer ${node}
  done
}

bootstrap_all_binlog_pump(){
  for node in $(eval "echo binlog_pump{0..$((${binlog_pump_num}-1))}") ;do
    bootstrap_binlog_pump ${node}
  done
}

bootstrap_all_binlog_drainer(){
  for node in $(eval "echo binlog_drainer{0..$((${binlog_drainer_num}-1))}") ;do
    bootstrap_binlog_drainer ${node}
  done
}

stop_pushgateway(){
  stop_node tidb_pushgateway
}

stop_prometheus(){
  stop_node tidb_prometheus
}


stop_grafana(){
  stop_node tidb_grafana
}

start_pushgateway(){
  node=tidb_pushgateway
  ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b${node}\b/" hosts)
  docker run -dit --name ${node} --hostname ${node} --rm --net static_net0 --ip ${ip} prom/pushgateway:v0.3.1 --log.level=error
}

start_prometheus(){
  ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\btidb_prometheus\b/" hosts)
  dockerFlags="-tid --rm --name tidb_prometheus --hostname tidb_prometheus --net static_net0 --ip ${ip} -u root 
  -v ${PWD}/hosts:/etc/hosts
  -v ${PWD}/tidb_prometheus_conf/prometheus.yml:/etc/prometheus/prometheus.yml
  -v ${PWD}/tidb_prometheus_conf/pd.rules.yml:/etc/prometheus/pd.rules.yml
  -v ${PWD}/tidb_prometheus_conf/tikv.rules.yml:/etc/prometheus/tikv.rules.yml
  -v ${PWD}/tidb_prometheus_conf/tidb.rules.yml:/etc/prometheus/tidb.rules.yml
  -v ${PWD}/tidb_prometheus_data:/data
  "
  docker run  ${dockerFlags} prom/prometheus:v2.2.1 --log.level=error --storage.tsdb.path=/data/prometheus --config.file=/etc/prometheus/prometheus.yml
}

start_grafana(){
  node=tidb_grafana
  ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b${node}\b/" hosts)
  dockerFlags="-tid --rm --name ${node} --hostname ${node} --net static_net0 --ip ${ip} -u root 
  -e GF_LOG_LEVEL=error
  -e GF_PATHS_PROVISIONING=/etc/grafana/provisioning
  -e GF_PATHS_CONFIG=/etc/grafana/grafana.ini
  -v ${PWD}/tidb_grafana_conf:/etc/grafana
  -v ${PWD}/tidb_grafana_conf/dashboards:/tmp/dashboards
  -v ${PWD}/tidb_grafana_data/grafana:/var/lib/grafana
  -v ${PWD}/hosts:/etc/hosts
  "

  docker run ${dockerFlags} grafana/grafana:6.0.1 
}

restart_pushgateway(){
  stop_pushgateway
  start_pushgateway
}

restart_prometheus(){
  stop_prometheus
  start_prometheus
}

restart_grafana(){
  stop_grafana
  start_grafana
}

stop_pushgateway_prometheus_grafana(){
  stop_pushgateway
  stop_prometheus
  stop_grafana
}

start_pushgateway_prometheus_grafana(){
  start_pushgateway
  start_prometheus
  start_grafana
}

restart_pushgateway_prometheus_grafana(){
  restart_pushgateway
  restart_prometheus
  restart_grafana
}
