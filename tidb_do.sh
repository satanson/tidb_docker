#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

source ${basedir}/functions.sh
source ${basedir}/tidb_ops.sh

echo "service: "
service=$(selectOption "pd_server" "tikv_server" "tidb_server" "sre" "binlog")

if isIn ${service} "pd_server|tikv_server|tidb_server";then
  echo "cmd: "
  cmd=$(selectOption "restart" "restart_all" "stop" "stop_all" "start" "start_all")
  if isIn ${cmd} "restart_all|stop_all|start_all";then
    echo "exec: ${cmd}_${service}"
    confirm
    ${cmd}_${service}
  elif isIn ${cmd} "restart|stop|start";then
    echo "node: "
    if isIn ${service} "pd_server";then
      node=$(selectOption $(eval "echo pd_server{0..$((${pd_server_num}-1))}"))
    elif isIn ${service} "tikv_server";then
      node=$(selectOption $(eval "echo tikv_server{0..$((${tikv_server_num}-1))}"))
    elif isIn ${service} "tidb_server";then
      node=$(selectOption $(eval "echo tidb_server{0..$((${tidb_server_num}-1))}"))
    fi
    echo "exec: ${cmd}_${service} ${node}"
    confirm
    ${cmd}_${service} ${node}
  elif isIn ${cmd} "metrics";then
    :
  fi
elif isIn ${service} "sre";then
  echo "service of sre: "
  service=$(selectOption "pushgateway_prometheus_grafana" "pushgateway" "prometheus" "grafana")
  echo "cmd: "
  cmd=$(selectOption "stop" "start" "restart")
  echo "exec: ${cmd}_${service}"
  confirm
  ${cmd}_${service}
elif isIn ${service} "binlog";then
  echo "service of binlog: "
  service=$(selectOption "binlog_pump" "binlog_drainer")
  echo "cmd: "
  cmd=$(selectOption "restart" "start" "stop" "bootstrap" "restart_all" "start_all" "stop_all" "bootstrap_all")
  if isIn ${cmd} "restart_all|start_all|stop_all|bootstrap_all";then
    echo "exec: ${cmd}_${service}"
    confirm
    ${cmd}_${service}
  elif isIn ${cmd} "restart|start|stop|bootstrap";then
    num=$(eval "${service}_num")
    node=$(selectOption $(eval "echo ${service}{0..$((${num}-1))}"))
    echo "exec ${cmd}_${service} ${node}"
    confirm
    ${cmd}_${service} ${node}
  fi
fi
