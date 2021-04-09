#!/bin/bash

clusters_ns="logging-and-metrics|monitoring prod-es1|prod prod-monitoring|prod dev-es1|dev dev-monitoring|dev"
service_suffix="-kb-http"
#hosts_file="/etc/hosts"

test "$#" -eq 1 || { echo "Pass a domain name as a parameter"; exit 1; }

domain=$1

for clns in ${clusters_ns}; do
  ip=""
  cluster="$(echo ${clns} | awk -F"|" '{ print $1}')"
  namespace="$(echo ${clns} | awk -F"|" '{ print $2}')"
  #echo "$cluster.$domain"
  if ip="$(kubectl get service ${cluster}${service_suffix} -n ${namespace} --output jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>&1)"; then
    echo "# Adding $cluster.$domain pointing to $ip"
    echo "${ip} ${cluster}.${domain}"
    # echo "${ip} ${cluster}.${domain}" >> ${hosts_file}
    echo
  else
    :
  fi
done
