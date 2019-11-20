#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}
ops_script=${1:?"undefined ops_script"};shift
source ${basedir}/${ops_script}
$*
