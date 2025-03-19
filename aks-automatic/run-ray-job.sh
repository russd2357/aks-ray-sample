#!/bin/bash

# Download the PyTorch MNIST job YAML file
curl -LO https://raw.githubusercontent.com/ray-project/kuberay/master/ray-operator/config/samples/pytorch-mnist/ray-job.pytorch-mnist.yaml

# Train a PyTorch Model on Fashion MNIST
kubectl apply -n $kuberay_namespace -f ray-job.pytorch-mnist.yaml

# Output the pods in the kuberay namespace
kubectl get pods -n $kuberay_namespace

# Get the status of the Ray job
job_status=$(kubectl get rayjobs -n $kuberay_namespace -o jsonpath='{.items[0].status.jobDeploymentStatus}')

echo "Job Status: $job_status"
# Wait for the Ray job to complete
while [ "$job_status" != "Complete" ]; do
    echo -e "\e[1A\e[KJob Status: $job_status\\r"
    sleep 30
    job_status=$(kubectl get rayjobs -n $kuberay_namespace -o jsonpath='{.items[0].status.jobDeploymentStatus}')
done
echo "Job Status: $job_status"

# Check if the job succeeded
job_status=$(kubectl get rayjobs -n $kuberay_namespace -o jsonpath='{.items[0].status.jobStatus}')

if [ "$job_status" != "SUCCEEDED" ]; then
    echo "Job Failed!"
    exit 1
fi
echo "Job Succeeded!"