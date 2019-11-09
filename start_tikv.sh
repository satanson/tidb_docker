#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

bootstrap=$1;shift
if [ -n "$bootstrap" ];then
  bootstrap_all_tikv_server
fi
start_all_tikv_server
