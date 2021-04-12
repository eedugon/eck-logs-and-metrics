(pending review...)

# Default logging with Filebeat and autodiscover

This document explains the current manifest available [here](/resources/02_k8s_monitoring/10_kube-system_metrics_K8S.yaml).

### Manifest Highlights:

- Metricbeat runs as a DaemonSet
- Two types of metrics
  - Host level metrics: These metrics needs to be fetched by all nodes, which is the main reason to run this as a DaemonSet.

```
      - module: system
        period: 10s
        metricsets:
        - cpu
        - load
        - memory
        - network
        - process
        - process_summary
        process:
          include_top_n:
            by_cpu: 5
            by_memory: 5
        processes:
        - .*
      - module: system
        period: 1m
        metricsets:
        - filesystem
        - fsstat
        processors:
        - drop_event.when.regexp:
            system.filesystem.mount_point: '^/(sys|cgroup|proc|dev|etc|host|lib|snap)($|/)'
      - module: kubernetes
        period: 10s
        host: ${NODE_NAME}
        hosts:
        - https://${NODE_NAME}:10250
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        ssl:
          verification_mode: none
        metricsets:
        - node
        - system
        - pod
        - container
        - volume
```

  - Cluster level metrics: These metrics needs to be feched just once, not per node. Originally these were proposed in a Deployment and not in a DaemonSet, but we have recently included support for `unique` inputs. I personally like more the `DaemonSet + Deployment` original proposal because it allows better dimensioning of the resources (CPU and memory request / limits). With this approach, one pod of the DaemonSet will always show more load than the others.

```
      autodiscover:
        providers:
        - type: kubernetes
          node: ${NODE_NAME}
          hints:
            default_config: {}
            enabled: true # double check if this is wanted
        # I like the following section (cluster level metrics) more in a Deployment than in a daemonSet with unique = true
        # But anyway this shows the new __unique__ functionality of autodiscover in metricbeat
        - type: kubernetes
          scope: cluster
          node: ${NODE_NAME}
          unique: true
          identifier: leader-election-metricbeat
          templates:
            - config:
                - module: kubernetes
                  hosts: ["kube-state-metrics:8080"]
                  period: 30s
                  add_metadata: true
                  metricsets:
                    - state_node
                    - state_deployment
                    - state_daemonset
                    - state_replicaset
                    - state_statefulset
                    - state_pod
                    - state_container
                    - state_cronjob
                    - state_resourcequota
                    - state_service
                    - state_persistentvolume
                    - state_persistentvolumeclaim
                    - state_storageclass
                - module: kubernetes
                  metricsets:
                    - apiserver
                  hosts: ["https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"]
                  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
                  ssl.certificate_authorities:
                    - /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                  period: 30s
                # Uncomment this to get k8s events:
                - module: kubernetes
                  metricsets:
                    - event
```

- `HostNetwork: true`: needed for Network related metrics.
- HTTP based monitoring disabled (due to the usage of `hostNetwork`) to avoid listening on a port at host level.
- Logs collection of this pod disabled with the pod level annotation `co.elastic.logs/enabled: "false"`.

More details at:

- Metricbeat autodiscover
- Metricbeat hints based autodiscover.

(TBD)- For custom metrics take a look at [custom_metrics](custom_metrics.md) document and examples.
