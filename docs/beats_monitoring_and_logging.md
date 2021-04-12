# Monitoring Beats with Metricbeat and Filebeat on Kubernetes

## Metrics

Beats monitoring (metrics) can be achieved via 2 different methods:
- [Internal monitoring collection](https://www.elastic.co/guide/en/beats/filebeat/current/monitoring-internal-collection.html): Monitoring will be done directly by the running beat, sending its own metrics to an Elasticsearch cluster.
- [Metricbeat based monitoring](https://www.elastic.co/guide/en/beats/filebeat/current/monitoring-metricbeat-collection.html): An external metricbeat will connect to the beat via HTTP to retrieve metrics and ship them to an Elasticsearch cluster.

This document is focused on the `Metricbeat based monitoring` and explains the manifest available [here](/resources/02_k8s_monitoring/stack_monitoring/03_monitoring_all-beats.yaml), which is intended to deploy metricbeat in order to monitor itself + any other beat pod configured with a given label.

### Beats monitoring with autodiscovery and using metricbeat collection

The beat to monitor needs to achieve the following goals:

- Enable http and disable internal monitoring
```
    # Metricbeat based monitoring
    http.enabled: true
    http.port: 5066
    http.host: 0.0.0.0
    monitoring.enabled: false
```

- Publish the port at container level
```
          # port published with name "monitoring" at container level (it will be used in metricbeat later on)
          ports:
          - containerPort: 5066
            name: monitoring
            protocol: TCP

```

- Add a label (optional) that will be used by the monitoring agent (Metricbeat)
```
    # Label added to be used at a later stage with metricbeat autodiscover)
    podTemplate:
      metadata:
        labels:
          # allow metricbeat based monitoring of this beat
          mb_collection_enabled: "true"
```

The Metricbeat instance in charge of monitoring needs to:

- Configure `beat module` with a conditional autodiscover template:

```
      autodiscover:
        providers:
          - type: kubernetes
            scope: cluster
            hints.enabled: false
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

## Logs

For beats logging there isn't any predefined Beat module in Filebeat, so the logs must be analyzed and considered like any other pod, however take in mind the following recommendations:

- Do not ship filebeat logs to the same Elasticsearch cluster where the main inputs are sending the data (the same would apply to other beats).



### logging

explain json logging + include annotations + config example:

```
co.elastic.logs/enabled: "true"
co.elastic.logs/processors.1.decode_json_fields.fields: ["message"]
co.elastic.logs/processors.1.decode_json_fields.target: ""
co.elastic.logs/processors.1.decode_json_fields.overwrite_keys: "true"
co.elastic.logs/processors.1.decode_json_fields.add_error_key: "true"
co.elastic.logs/processors.1.decode_json_fields.max_depth: 1
```
