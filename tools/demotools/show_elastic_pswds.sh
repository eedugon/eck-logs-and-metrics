#!/bin/bash

clusters_ns="logging-and-metrics|monitoring prod-es1|prod prod-monitoring|prod dev-es1|dev dev-monitoring|dev"
secret_suffix="-es-elastic-user"

#hosts_file="/etc/hosts"
#test "$#" -eq 1 || { echo "Pass a domain name as a parameter"; exit 1; }

for clns in ${clusters_ns}; do
  ip=""
  cluster="$(echo ${clns} | awk -F"|" '{ print $1}')"
  namespace="$(echo ${clns} | awk -F"|" '{ print $2}')"
  #echo "$cluster.$domain"
  if pass="$(kubectl get secret ${cluster}${secret_suffix} -n ${namespace} -o=jsonpath={.data.elastic} 2>&1 | base64 --decode 2>&1)"; then
    echo "# elastic password of $cluster"
    echo "${pass}"
  else
    echo "# secret not found for $cluster"
  fi
  echo
done
