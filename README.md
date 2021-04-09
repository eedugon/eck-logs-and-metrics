(Work in progres...)

# eck-logs-and-metrics
Monitoring Kubernetes and Elasticsearch Clusters with ECK

Dependencies:

kube-state-metrics 2.0.0-rc.0: https://github.com/kubernetes/kube-state-metrics/releases/tag/v2.0.0-rc.0

Load Balancers integration. For those systems without load balancers available consider exposing the services for external traffic in any other way (`kubectl port-forward`, ingress controller, ...).

## ECK Installation and environment setup

### GKE special permissions

For GKE based clusters give your google account administration privileges on the cluster:

```
kubectl create clusterrolebinding \
cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
```

### ECK, namespaces and generic roles

[Deploy ECK](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html), namespaces and global roles.
```
kubectl apply -f resources/01_infra
```

The previous command will install ECK with the default official manifest (in `elastic-system` namespace) and will also create the following namespaces:
- monitoring
- dev
- prod

And the following roles:
- filebeat
- metricbeat

### Kube-state-metrics installation

Deploy [Kube-state-metrics](https://github.com/kubernetes/kube-state-metrics):
```
kubectl apply -f resources/01_infra/external/kube-state-metrics-v2.0.0-rc.0/standard
```

### Ingress controller and ingress example installation (optional)

[Ingress controller](https://github.com/kubernetes/ingress-nginx) is only used as an example for Filebeat and Metricbeat modules configuration.

Deploy ingress-controller with:

```
kubectl apply -f resources/01_infra/external/ingress-controller-0.45.0
kubectl apply -f resources/01_infra/external/ingress_app_example
```

### Trial License (Optional)

If you want to test Enterprise level features enable the trial at ECK level:

```
kubectl apply -f resources/01_infra/enterprise-trial
```

## Kubernetes Observability

### Basic components

```
kubectl apply -f resources/02_monitoring
```

The previous command will deploy the following components:
- Role bindings for filebeat and metricbeat service accounts on monitoring namespace
- `logs-and-metrics` Elasticsearch Cluster
- `logs-and-metrics` Kibana instance.
- `filebeat` DaemonSet configured to fetch **all pods** logs.
- `metricbeat` for Kubernetes monitoring with a DaemonSet strategy.

(more details?) self-monitoring in that cluster? (custom metrics example)

Useful commands to monitor creation of components:
```
kubectl -n kube-system get pod # check for k8s-metrics metricbeat pods
kubectl -n monitoring get elasticsearch
kubectl -n monitoring get pod # check for ES, Kibana, Filebeat and Metricbeat pods
kubectl -n monitoring get beat
...
...
(describe components, check logs, etc)
```

### Obtain elastic password

```
echo $(kubectl get secret -n monitoring logging-and-metrics-es-elastic-user -o=jsonpath={.data.elastic} | base64 --decode)
```

Another quick way to obtain elastic password of all deployed clusters consists of using the provided `show_elastic_pswds.sh` script:

```
./tools/demotools/show_elastic_pswds.sh
# elastic password of logging-and-metrics
LT6uD5ty74349X1Rr15Zy9og
...
...
```

### Prepare local URLs and obtain passwords:

The script `prepare_hostnames.sh` will

```
./tools/demotools/prepare_hostnames.sh mydomain
# Adding logging-and-metrics.mydomain pointing to IP_ADDRESS
IP_ADDRESS logging-and-metrics.mydomain

# Add the previous content to your /etc/hosts (or similar) file for local names resolution
```

Note: this is not needed at all, the only intention is to simplify access to the lab. You can still use the LoadBalancer IP address directly to log into Kibana, or if LoadBalancers are not used, use whatever method you follow (`kubectl port-forward`, etc.).

### Kibana custom dashboard:

The provided dashboard is designed to "monitor" and overview the previous data flows (logs and metrics), not to monitor Kubernetes itself. The dashboard contains the following visualizations:
- Number of metrics received by metricset
- Number of logs received by pod name
- Logs distribution per Kubernetes namespace.
- Kubernetes events overview (probably this saved search should be in a real Kubernetes monitoring dashboard).

(There's an extra `saved search` for custom logs processing example)

To install the custom dashboard and associated resources:

```
curl -u elastic -k -X POST "https://logging-and-metrics.edudemo:5601/api/saved_objects/_import?overwrite=true" -H "kbn-xsrf: true" --form 'file=@kibana/kibana-resources.ndjson'
```

Check the output of the previous command for errors.

(you will need elastic password, which is available in `logging-and-metrics-es-elastic-user` secret and can be retrieved with `tools/demotools/show_elastic_pswds.sh`).



### Optional components / examples




## Elastic Stack Monitoring

### Prod namespace environment setup

Before showing
Main / data cluster in the namespace (imaginary, example)
This should be cluster with real data.

```
kubectl apply -f resources/03_prod
```

#### Option 1: Self-monitoring (basic license)

```
kubectl apply -f resources/03_prod/basic/self-monitoring
```

self monitoring --> shipping logs not recommended.

shipping filebeat logs to same cluster not recommended.


self monitoring:
  - metrics
  - logs


dedicated monitoring cluster:
 - metrics
 - logs


#### Option 2: Dedicated monitoring cluster (basic license, only allows 1 monitored cluster)

```
kubectl apply -f resources/03_prod/basic/dedicated-monitoring
```

#### Option 3: Centralized monitoring cluster (enterprise license)


```
kubectl apply -f resources/03_prod/enterprise/central-monitoring
```

## Uninstall

Important resources to delete before destroying the Kubernetes cluster.

- Persistent Volumes (created via PersistentVolumeClaims)
- External Load Balancers

```
kubectl delete -f resources/01_infra
# That will also delete all created namespaces: monitoring, prod and dev
```

Uninstalling ECK will also take care of destroying all owned resources (Elasticsearch clusters, Kibana instances, Beats, etc).

If you delete the Kubernetes cluster (GKE) before uninstalling ECK you will end up with orphan resources in the cloud (Loab Balancers and Disks)

### WIP

Discussion topics, and configuration options:

- hostNetwork
https://github.com/elastic/beats/issues/15013#issuecomment-596428967


Test access:

Obtain Elastic password for logging and metrics cluster:

```
kubectl get secret -n monitoring logging-and-metrics-es-elastic-user -o=jsonpath={.data.elastic} | base64 --decode
```

```
kubectl get secret -n prod prod-es1-es-elastic-user -o=jsonpath={.data.elastic} | base64 --decode
```

```
kubectl get secret -n prod prod-monitoring-es-elastic-user -o=jsonpath={.data.elastic} | base64 --decode
```

Prepare local hostnames
```
k get service logging-and-metrics-kb-http -n monitoring --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```


ADD AND INCLUDE THE OPTION OF SINGLE METRICBEAT FOR ALL ES & KIBANA NODES:
  - With shared user
  - Accessing the secret of every namespace....?
  - finding a better way... secrets based on autodiscovery data? (interesting!)



CURRENT CHALLENGES:

- beats mandan datos cada uno con su cluster ID

- Logs de beats, se mandan o no se mandan? no mandar al mismo cluster....
beats hints para logs?

- Logs de elasticsearch contra él mismo.... mejor no: ejemplo audit logs + crecimiento exponencial.

- logs de metricbeat que recoge datos de cluster X hacia cluster Y : si
- logs de metricbeat que recoge datos de cluster X hacia cluster X (self) : NO.

- Logs de filebeat

(hecho)- Desactivamos logs de filebeat general hacia cluster de logs centralizados (evitar loops raros)


- Meter logs y metricas customizados, algun ejemplo, todo a logging-and-metrics, claro.

system module disable metricbeat: not done.

### slide: beats monitoring with autodiscovery and using metricbeat collection

for monitored beats:
- enable http
- publish the port
- add a label (optional)

in monitoring metricbeat:
- same as before +
- configure the module based on conditions:

```
            templates:
              - condition:
                  and:
                    - equals.kubernetes.labels.common_k8s_elastic_co/type: "beat"
                    - equals.kubernetes.labels.mb_collection_enabled: "true"
                config:
                  - module: beat
                    metricsets:
                      - stats
                      - state
                    period: 10s
                    hosts: "http://${data.host}:${data.ports.monitoring}"
                    xpack.enabled: true
```

Complete example of monitoring beat that will monitor itself + any other beat with the label:

.....



## Improvement Areas

- Usage of `elastic` user account for metrics gathering --> use more restricted users (remote_monitoring_user)
