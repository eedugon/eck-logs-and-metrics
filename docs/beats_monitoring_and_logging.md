(WIP...)
# Monitoring Beats with Metricbeat and Filebeat on Kubernetes

## Metrics

Beats monitoring (metrics) can be achieved via 2 different methods:
- [Internal monitoring](): Monitoring will be done directly by the running beat, sending its own metricst to an Elasticsearch cluster.
- [Metricbeat based monitoring](): An external metricbeat will connect to the beat via HTTP to retrieve metrics and ship them to an Elasticsearch cluster.

description here...

### beats monitoring with autodiscovery and using metricbeat collection

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
