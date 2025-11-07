#!/bin/bash
#
# Description: Provisions the GKE cluster for the autoscaling lab.
#

set -eo pipefail

# ##################################################################
# CONFIGURATION
# ##################################################################

# GCP Project ID. Change this to your project ID.
export PROJECT_ID=$(gcloud config get-value project)

# GKE Cluster Configuration
export CLUSTER_NAME="autoscaling-lab-cluster"
export REGION="us-central1"
export MACHINE_TYPE="e2-standard-16"
export NUM_NODES="1"

# ##################################################################
# SCRIPT LOGIC
# ##################################################################

echo "----------------------------------------------------"
echo "Starting GKE Cluster Provisioning..."
echo "Project:       ${PROJECT_ID}"
echo "Cluster Name:  ${CLUSTER_NAME}"
echo "Region:        ${REGION}"
echo "----------------------------------------------------"

# Enable necessary APIs
echo "Enabling required GCP APIs..."
gcloud services enable \
    container.googleapis.com \
    artifactregistry.googleapis.com --project "${PROJECT_ID}"

# Create the GKE cluster
echo "Creating GKE Standard cluster '${CLUSTER_NAME}'..."
echo "This will take several minutes..."

gcloud container clusters create "${CLUSTER_NAME}" \
    --project "${PROJECT_ID}" \
    --region "${REGION}" \
    --machine-type "${MACHINE_TYPE}" \
    --num-nodes "${NUM_NODES}" \
    --enable-vertical-pod-autoscaling \
    --no-enable-autoupgrade \
    --cluster-version=latest

echo "✅ GKE Cluster '${CLUSTER_NAME}' created successfully."
echo "----------------------------------------------------"

# Configure kubectl
echo "Configuring kubectl to connect to the new cluster..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"

echo "✅ kubectl is configured."
echo "----------------------------------------------------"


echo "Lab infrastructure setup is complete!"
echo "----------------------------------------------------"
