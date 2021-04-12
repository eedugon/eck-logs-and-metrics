# Default Kubernetes Metrics with Metricbeat

This document explains the manifest available [here](/resources/02_k8s_monitoring/10_kube-system_metrics_K8S.yaml), which is intended to deploy Metricbeat on Kubernetes to perform monitoring of `Kubernetes nodes` and `Kubernetes cluster` state.

### Manifest Highlights:

- Metricbeat runs as a DaemonSet

- Two types of metrics
  - __Host level metrics__: These metrics needs to be retrieved `per node`, which is the main reason to run this as a DaemonSet.
    - Common metricsets from `system module`.
    - Kubelet related mericsets from `kubernetes module`.

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

  - __Cluster level metrics__: These metrics needs to be fetched just once, not per node. Originally these were proposed in a Deployment and not in a DaemonSet, but [Metricbeat autodiscover](https://www.elastic.co/guide/en/beats/metricbeat/current/configuration-autodiscover.html) has recently delivered the `unique` functionality, which allows to define an `autodiscover provider` that will run only once, acquiring a leader lease. I personally like more the `DaemonSet + Deployment` original proposal because it allows better dimensioning of the resources (CPU and memory request / limits). With this approach, one pod of the DaemonSet will always show significant more load than the others.

```
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

- An extra __autodiscover provider with Hints enabled__. This would allow metrics of pods with `co.elastic.metrics/*` annotations to be retrieved by this DaemonSet. Double check if that's what you want in your installation. I would prefer to keep that in a separate Deployment.

```
      autodiscover:
        providers:
        - type: kubernetes
          node: ${NODE_NAME}
          hints:
            default_config: {}
            enabled: true # double check if this is wanted
```

- `HostNetwork: true`: needed for Network interfaces related metrics.

- Monitoring (of the beat itself) enabled with [internal collection](https://www.elastic.co/guide/en/beats/metricbeat/current/monitoring-internal-collection.html), and [HTTP/metricbeat based monitoring](https://www.elastic.co/guide/en/beats/metricbeat/current/monitoring-metricbeat-collection.html) disabled (due to the usage of `hostNetwork`) to avoid listening on a port at host level:

```
    # Disabled mb based monitoring and enabled internal collection instead (because of hostNetwork)
    # http.enabled: true # defaults to false
    # http.port: 5066
    # http.host: 0.0.0.0
    monitoring.enabled: true
```

More details at:

- [Metricbeat autodiscover](https://www.elastic.co/guide/en/beats/metricbeat/current/configuration-autodiscover.html)
- [Metricbeat hints based autodiscover](https://www.elastic.co/guide/en/beats/metricbeat/current/configuration-autodiscover-hints.html)

(TBD)- For custom metrics take a look at [custom_metrics](custom_metrics.md) document and examples.
