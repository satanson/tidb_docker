#!/bin/bash

set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

source ${basedir}/functions.sh

echo "action: "
action=$(selectOption "start" "bootstrap" "restart" "stop")

services="pd-server tikv-server binlog-pump tidb-server mysqld0 binlog-drainer pushgateway-prometheus-grafana"
if isIn ${action} "stop";then
  services=$(perl -e "print join qq( ), reverse qw(${services})")
fi

phase=0
for serv in ${services};do
  phase=$((phase+1))
  serv_name=$(replace ${serv} "-" "_")
  echo ""
  yellow_print "phase ${phase}: ${action} ${serv} ..."
  if isIn ${serv_name} "mysqld0";then
    ${basedir}/local_scoped_args.sh mysqld_ops.sh ${action}_mysqld mysqld0
  elif isIn ${serv_name} "pushgateway_prometheus_grafana";then
    if isIn ${action} "bootstrap";then
      ${basedir}/local_scoped_args.sh tidb_ops.sh stop_pushgateway_prometheus_grafana
    else
      ${basedir}/local_scoped_args.sh tidb_ops.sh ${action}_pushgateway_prometheus_grafana
    fi
  else
    ${basedir}/local_scoped_args.sh tidb_ops.sh ${action}_all_${serv_name}
  fi
  green_print "phase ${phase}: ... ${action} ${serv} done"
  sleep 2
done
