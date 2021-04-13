# Default Kubernetes logs collection with Filebeat and autodiscover

This document explains the manifest available [here](/resources/02_k8s_monitoring/11_logs_k8s_all_autodiscover.yaml), which is intended to collect all Kubernetes pods logs in a flexible way, allowing the user to disable certain pods logs, adding customizations, etc.

### Manifest Highlights:

- Filebeat runs as a DaemonSet in the namespace `monitoring` (feel free to change that).

- `HostNetwork: true`: Provides better metadata (not really needed).

- Runs in privileged mode (`runAsUser: 0`): Needed for mounting host directories with logs and also for hostPath volume (persistent) for data path.

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

- Mounts: the following `hostPaths`:
  - /var/log/containers
  - /var/log/pods
  - /var/lib/docker/containers
  - /var/lib/filebeat-data-logs-k8s (filebeat data dir, mounted on `/usr/share/filebeat/data`) (__not needed, ECK takes care of it__)

- Monitoring (of the beat itself) enabled with [internal collection](https://www.elastic.co/guide/en/beats/filebeat/current/monitoring-internal-collection.html), and [HTTP/metricbeat based monitoring](https://www.elastic.co/guide/en/beats/filebeat/current/monitoring-metricbeat-collection.html) disabled (due to the usage of `hostNetwork`) to avoid listening on a port at host level:

- Logs collection of this pod disabled with the pod level annotation `co.elastic.logs/enabled: "false"`.

### Extra Considerations:

- With this proposed configuration the logs from ALL pods will be retrieved. If you want some pods to not be considered, the pods should include the following annotation:

```
co.elastic.logs/enabled: "false"
```

- If you don't want all pods logs to be collected by default you can add `hints.default_config.enabled: false` and then only the pods with annotation `co.elastic.logs/enabled: "true"` will be retrieved.

More details at:
- [Filebeat autodiscover](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-autodiscover.html)
- [Filebeat hints based autodiscover](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-autodiscover-hints.html)

### Customizations

As this DaemonSet is using `hints based autodiscover`, in case of needing extra input configuration for specific pods there are 2 choices:
- Add the relevant annotations to the pods, so hints based autodiscover will apply the changes.
- For those pods, disable the logs fetching with `co.elastic.logs/enabled: "false"` annotation and add conditional based templates to the filebeat autodiscover configuration.

More examples of this type of customizations available at [custom_log_formats](custom_log_formats.md) document and examples.
