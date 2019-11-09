#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

source ${basedir}/functions.sh
source ${basedir}/tidb_ops.sh

echo "service: "
service=$(selectOption "pd_server" "tikv_server" "tidb_server" "sre")

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
      node=$(selectOption $(eval "echo pd_server{0..$((${pdNum}-1))}"))
    elif isIn ${service} "tikv_server";then
      node=$(selectOption $(eval "echo tikv_server{0..$((${tikvNum}-1))}"))
    elif isIn ${service} "tidb_server";then
      node=$(selectOption $(eval "echo tidb_server{0..$((${tidbNum}-1))}"))
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
fi
