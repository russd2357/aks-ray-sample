#!/bin/bash

#
# TODO - This needs to be added to the deployment script
# This script installs the PodMonitor CRD for KubeRay on AKS.
# It assumes that the user has already logged into Azure CLI and has AKS credentials.
# It also assumes that the user has already created an enviorment variable for the Kuberay namespace.

cat <<EOF | kubectl apply -f -
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  labels:
    release: prometheus
  name: ray-head-monitor
  namespace: ${kuberay_namespace}
spec:
  jobLabel: ray-head
  # Only select Kubernetes Pods in the "${kuberay_namespace}" namespace.
  namespaceSelector:
    matchNames:
      - ${kuberay_namespace}
  # Only select Kubernetes Pods with "matchLabels".
  selector:
    matchLabels:
      ray.io/node-type: head
  # A list of endpoints allowed as part of this PodMonitor.
  podMetricsEndpoints:
    - port: metrics
      relabelings:
        - action: replace
          sourceLabels:
            - __meta_kubernetes_pod_label_ray_io_cluster
          targetLabel: ray_io_cluster
    - port: as-metrics # autoscaler metrics
      relabelings:
        - action: replace
          sourceLabels:
            - __meta_kubernetes_pod_label_ray_io_cluster
          targetLabel: ray_io_cluster
    - port: dash-metrics # dashboard metrics
      relabelings:
        - action: replace
          sourceLabels:
            - __meta_kubernetes_pod_label_ray_io_cluster
          targetLabel: ray_io_cluster
EOF

# Create a pod monitor for the worker nodes
cat <<EOF | kubectl apply -f -
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: ray-workers-monitor
  namespace: ${kuberay_namespace}
  labels:
    release: prometheus
spec:
  jobLabel: ray-workers
  # Only select Kubernetes Pods in the "${kuberay_namespace}" namespace.
  namespaceSelector:
    matchNames:
      - ${kuberay_namespace}
  # Only select Kubernetes Pods with "matchLabels".
  selector:
    matchLabels:
      ray.io/node-type: worker
  # A list of endpoints allowed as part of this PodMonitor.
  podMetricsEndpoints:
  - port: metrics
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_label_ray_io_cluster]
      targetLabel: ray_io_cluster
EOF