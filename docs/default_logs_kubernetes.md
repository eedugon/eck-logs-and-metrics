(pending review...)

# Default logging with Filebeat and autodiscover

This document explains the current manifest available [here](/resources/02_k8s_monitoring/11_filebeat_logs_all_autodiscover.yaml).

### Manifest Highlights:

- Filebeat runs as a DaemonSet
- `HostNetwork: true`
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

- HTTP based monitoring disabled (due to the usage of `hostNetwork`) to avoid listening on a port at host level.
- Logs collection of this pod disabled with the pod level annotation `co.elastic.logs/enabled: "false"`.

### Extra Considerations:

- With this proposed configuration the logs from ALL pods will be retrieved. If you want some pods to not be considered, the pods should include the following annotation:

```
co.elastic.logs/enabled: "false"
```

- If you don't want all pods logs to be collected as default you can add `hints.default_config.enabled: false` and then only pods with annotation `co.elastic.logs/enabled: "true"` will be considered.

More details at:
- Filebeat autodiscover
- Filebeat hints based autodiscover.

- For custom logging formats take a look at [custom_log_formats](custom_log_formats.md) document and examples.
