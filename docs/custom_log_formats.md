# Custom logging formats

This document shows and explain some use cases to customize pods logs processing with Filebeat on Kubernetes.

## JSON Logging processing

If your application writes logs directly in json format, the easiest option to process and create fields based on your json logs is to call directly the [decode_json_fields]() filebeat processor from Filebeat.

Do not use the `json` options already available in the `container` input because


For example, if `hints based` autodiscover is in place you could add the following annotations to the pods:
```
      co.elastic.logs/enabled: false # uncomment that if you don't want hints based autodiscover to fetch these logs
      co.elastic.logs/processors.1.decode_json_fields.fields: ["message"]
      co.elastic.logs/processors.1.decode_json_fields.target: ""
      co.elastic.logs/processors.1.decode_json_fields.overwrite_keys: "true"
      co.elastic.logs/processors.1.decode_json_fields.add_error_key: "true"
      co.elastic.logs/processors.1.decode_json_fields.max_depth: 1
```

A similar configuration with `conditional templates based` autodiscover could look like:

```
            - condition:
                equals:
                  kubernetes.labels.purpose: "demonstrate-command-json"
              config:
                - type: container
                  paths:
                    - /var/log/containers/*${data.kubernetes.container.id}.log
                  # This won't work
                  #json.keys_under_root: false
                  #json.add_error_key: true
                  #json.message_key: message
                  # This works
                  tags: ["customformat"]
                  processors:
                    - decode_json_fields:
                        fields: ["message"]
                        process_array: false
                        max_depth: 1
                        target: ""
                        overwrite_keys: true
                        add_error_key: true
```

Note: watch out for field mappings explosion if your json content has too many fields.

## Calling specific elasticsearch pipelines for specific logs processing

If your pod is writting logs in plain text you can rely on an [elasticsearch pipeline]() to process and enrich the data before indexing.

#### Hints based autodiscover

Include the following annotations in the pods:

```
      co.elastic.logs/enabled: false
      co.elastic.logs/pipeline: ["custom-text-example"]
```

#### Conditional templates based autodiscover

Example of configuration to add a custom pipeline in the input.

```
            - condition:
                equals:
                  kubernetes.labels.purpose: "demonstrate-command-text"
              config:
                - type: container
                  paths:
                    - /var/log/containers/*${data.kubernetes.container.id}.log
                  tags: ["customformat"]
                  pipeline: custom-text-example
```

## Practical example

[This manifest](/resources/02_k8s_monitoring/extras/custom-formats/01_pods.yaml) defines 2 pods that write logs every 10 seconds with the following formats:

- `command-demo-json` pod logs:
```
{"stream":"custom_stream_name","customfield1":"field-value-example"}
{"stream":"custom_stream_name","customfield1":"field-value-example"}
```

- `command-demo-text` pod logs:
```
2021-04-13T09:54:36Z|field1value|field2value
2021-04-13T09:54:46Z|field1value|field2value
```

- Logs parsing solution: [manifest](/resources/02_k8s_monitoring/extras/custom-formats/filebeat-daemonset-customformat.yaml)
  - For the `json` pod (which is labeled with `purpose: demonstrate-command-json`) we apply the following template with autodiscover:
  
```
            - condition:
                equals:
                  kubernetes.labels.purpose: "demonstrate-command-json"
              config:
                - type: container
                  paths:
                    - /var/log/containers/*${data.kubernetes.container.id}.log
                  # This won't work
                  #json.keys_under_root: false
                  #json.add_error_key: true
                  #json.message_key: message
                  # This works
                  tags: ["customformat"]
                  processors:
                    - decode_json_fields:
                        fields: ["message"]
                        process_array: false
                        max_depth: 1
                        target: ""
                        overwrite_keys: true
                        add_error_key: true
```


  - For the `text` pod (which is labeled with `purpose: demonstrate-command-json`) we apply a `pipeline` option to the input via another autodiscover template and we create the pipeline in Elasticsearch (as a separate activity):

```
           - condition:
                equals:
                  kubernetes.labels.purpose: "demonstrate-command-text"
              config:
                - type: container
                  paths:
                    - /var/log/containers/*${data.kubernetes.container.id}.log
                  tags: ["customformat"]
                  pipeline: custom-text-example
```
