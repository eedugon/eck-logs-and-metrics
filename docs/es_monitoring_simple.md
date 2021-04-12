# Monitoring Elasticsearch and Kibana with Metricbeat on Kubernetes

This document explains the manifest available [here](/resources/02_k8s_monitoring/stack_monitoring/02_monitoring_logging-and-metrics_cluster_metrics.yaml), which is intended to deploy Metricbeat on Kubernetes to perform monitoring of __a single Elasticsearch cluster__ (all nodes of the cluster, but not multiple clusters).

In this example the monitored cluster is called `prod-es1`, and the monitoring cluster is called `logging-and-metrics`.

### Manifest Highlights:

- Metricbeat runs as a Deployment

- Metricbeat output referended to the monitoring cluster (in this case the `logging-and-metrics` cluster):
```
  elasticsearchRef:
    name: logging-and-metrics
```

- Metricbeat modules configured with `conditional templates based autodiscover` (hints totally disabled).
```
      autodiscover:
        providers:
          - type: kubernetes
            scope: cluster
            hints.enabled: false # there's no need to enable hints if we don't have annotations for the metrics
            templates:
```

- Conditional template for `elasticsearch` module pointing to the cluster to monitor:
```
              - condition:
                  equals.kubernetes.labels.elasticsearch_k8s_elastic_co/cluster-name: prod-es1
                config:
                  - module: elasticsearch
                    metricsets:
                      - ccr
                      - cluster_stats
                      - enrich
                      - index
                      - index_recovery
                      - index_summary
                      - ml_job
                      - node_stats
                      - shard
                    period: 10s
                    hosts: "https://${data.host}:${data.ports.https}"
                    username: ${MONITORED_ES_USERNAME}
                    password: ${MONITORED_ES_PASSWORD}
                    # WARNING: disables TLS as the default certificate is not valid for the pod FQDN
                    # TODO: switch this to "certificate" when available: https://github.com/elastic/beats/issues/8164
                    ssl.verification_mode: "none"
                    xpack.enabled: true
```

- Conditional template for `kibana` module pointing to the `monitored cluster`.
```
              - condition:
                  equals.kubernetes.labels.kibana_k8s_elastic_co/name: prod-es1
                config:
                  - module: kibana
                    metricsets:
                      - stats
                      - status
                    period: 10s
                    hosts: "https://${data.host}:${data.ports.https}"
                    username: ${MONITORED_ES_USERNAME}
                    password: ${MONITORED_ES_PASSWORD}
                    # WARNING: disables TLS as the default certificate is not valid for the pod FQDN
                    # TODO: switch this to "certificate" when available: https://github.com/elastic/beats/issues/8164
                    ssl.verification_mode: "none"
                    xpack.enabled: true
```

- User and password are provided as environment variables mounted from a secret.
```
          - name: MONITORED_ES_USERNAME
            value: elastic
          - name: MONITORED_ES_PASSWORD
            valueFrom:
              secretKeyRef:
                key: elastic
                name: prod-es1-es-elastic-user
```

Note: The `elastic` user account (`superuser`) is not really needed for monitoring purposes. __Create a different user with the built-in role `remote_monitoring_collector`__ as explained in [this doc](https://www.elastic.co/guide/en/elasticsearch/reference/current/configuring-metricbeat.html), and use that user instead.

- Monitoring (of the beat itself) enabled via [HTTP/Metricbeat collection](https://www.elastic.co/guide/en/beats/metricbeat/current/monitoring-metricbeat-collection.html).

```
    # Metricbeat based monitoring
    http.enabled: true
    http.port: 5066
    http.host: 0.0.0.0
    monitoring.enabled: false
...
...
    # Label added to be used at a later stage with metricbeat autodiscover)
    podTemplate:
      metadata:
        labels:
          # allow metricbeat based monitoring of this beat
          mb_collection_enabled: "true"
...
          # port published with name "monitoring" at container level (it will be used in metricbeat later on)
          ports:
          - containerPort: 5066
            name: monitoring
            protocol: TCP
```

More details at:

- [Monitoring Elasticsearch with Metricbeat](https://www.elastic.co/guide/en/elasticsearch/reference/current/configuring-metricbeat.html)
- [Monitoring Kibana with Metricbeat](https://www.elastic.co/guide/en/kibana/current/monitoring-metricbeat.html)
