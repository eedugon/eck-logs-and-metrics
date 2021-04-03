# eck-logs-and-metrics
Monitoring Kubernetes and Elasticsearch Clusters with ECK

Dependencies:

kube-state-metrics 2.0.0-rc.0
https://github.com/kubernetes/kube-state-metrics/releases/tag/v2.0.0-rc.0

## ECK and environment setup

### ECK Installation and environment setup

For GKE based clusters give your google account administration privileges on the cluster:

```
kubectl create clusterrolebinding \
cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
```

Deploy ECK, namespaces and global roles.
```
kubectl apply -f resources/01_infra
```

The previous command will create the following namespaces:
- monitoring
- dev
- prod

And the following roles:
- filebeat
- metricbeat


### Kube-state-metrics installation

Deploy Kube-state-metrics:
```
kubectl apply -f 01_infra/external/kube-state-metrics-v2.0.0-rc.0/standard
```

## Kubernetes Observability


```
kubectl apply -f resources/02_monitoring
```

The previous command will deploy the following:
- RBAC roles for filebeat and metricbeat service accounts on monitoring namespace
- `logs-and-metrics` Elasticsearch Cluster
- `logs-and-metrics` Kibana instance.
- `filebeat`
- `metricbeat` for Kubernetes monitoring with a DaemonSet strategy.

(more details?)


## Elastic Stack Monitoring

### Monitoring namespace


### Prod namespace


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
