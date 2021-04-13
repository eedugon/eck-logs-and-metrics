# Sending all Kubernetes logs towards different indices splitted by namespace (and data streams)

This document explains the manifest available [here](/resources/02_k8s_monitoring/extras/ns_data_streams/filebeat_K8s_logs_all_namespaces_data_streams.yaml), which is intended to collect all Kubernetes pods logs sending them to different indices divided by namespace.

### Challenges:

- Doing this with filebeat and autodiscover is technically easy if we don't want to use any kind of ILM associated to the final destination. In such case we only need to configure something like that in our filebeat:

```
output.elasticsearc.index: "filebeat-%{[agent.version]}-%{[kubernetes.namespace]:missing}-%{+yyyy.MM.dd}"
```

- If we want to perform this integration with __standard ILM__ it's critical to know the namespaces in advance, as we must perform the [bootstrapping]() of the initial index + the alias before shipping any data (filebeat automatic ILM setup doesn't work for multiple indices). Also, if we create a new namespace and Elasticsearch index + alias wasn't bootstrapped problems will occur as we will end up having real indices instead of using aliases for writting the data, so ILM won't really work.

- With [data streams]() this will work perfectly fine, as `data streams` are internally using ILM and they don't require the initial index to be bootstrapped.

For this example we are not converting `filebeat*` to data streams as I don't want to interfere with the standard indices. We will be relying on the default `logs-*-*` pattern that by default comes associated with data streams in Elasticsearch `7.10+`.

### Manifest Highlights:

- Filebeat runs as a DaemonSet in the namespace `monitoring` (feel free to change that).

- Runs in privileged mode (`runAsUser: 0`): Needed for mounting host directories with logs and also for hostPath volume (persistent) for data path.

- ILM setup disabled as we will be writing into multiple `places`:
```
    setup.ilm.enabled: false
    setup.template.enabled: true
    setup.template.name: "logs-fb-%{[agent.version]}"
    setup.template.pattern: "logs-fb-%{[agent.version]}-*"
```

- Template setup enabled to load the mappings to the final indices / data streams
```
    setup.template.enabled: true
    setup.template.name: "logs-fb-%{[agent.version]}"
    setup.template.pattern: "logs-fb-%{[agent.version]}-*"
```

When creating in Elasticsearch 7.10+ something like `logs-fb-abc-def`, there's a default template for `logs-*-*` that will force the creation of a `data stream` with the provided name, in this case we would end up with a data stream called `logs-fb-abc-def` and internally it will be pointing to some `.ds-xxxx` indices, all handled by ILM.

- Elasticsearch output overwrite: In this case we don'w want ECK to configure the output automatically so we provide the following values:

```
    output:
      elasticsearch:
        # default ECK created users don't have enough privileges to write or create other index names than filebeat-*
        username: ${ES_USERNAME}
        password: ${ES_PASSWORD}
        index: "logs-fb-%{[agent.version]}-%{[kubernetes.namespace]:missing}"
```

- User used is `elastic` because the default user created by ECK only has privileges to create `filebeat-*` stuff. Of course the super user shouldn't be used for this purpose, so feel free to update the environment variables and secret to use a more restricted user:

```
          env:
            - name: ES_USERNAME
              value: elastic
            - name: ES_PASSWORD
              valueFrom:
                secretKeyRef:
                  key: elastic
                  name: logging-and-metrics-es-elastic-user
```

- Hints based autodiscover configured to fetch logs from all pods by default:

```
    filebeat:
      autodiscover:
        providers:
        - type: kubernetes
          node: ${NODE_NAME}
          hints:
            enabled: true
            default_config:
              type: container
              paths:
              - /var/log/containers/*${data.kubernetes.container.id}.log
```

- Monitoring disabled (feel free to enable it following the other docs of this project)

- Logs collection of this pod disabled with the pod level annotation `co.elastic.logs/enabled: "false"` (I usually avoid self collecting logs in a log collector)
