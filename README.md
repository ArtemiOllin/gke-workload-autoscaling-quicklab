# GKE Autoscaling Lab: Right-Sizing and Performance Tuning

Welcome! This hands-on lab demonstrates the real-world impact of resource right-sizing and autoscaling on application performance using Google Kubernetes Engine (GKE).

## Lab Overview

This repository contains a complete environment to explore GKE autoscaling features. It includes:

*   **Infrastructure Script:** A `setup.sh` script to provision a GKE cluster with all necessary components.
*   **CPU-Intensive Application (`workload-1`):** A web application that performs CPU-intensive calculations. It is intentionally limited to use only **one CPU core** per replica to simulate a resource-bound service.
*   **Stepped Load Generator (`workload-2`):** An application that uses `hey` to generate a progressively increasing load against `workload-1`, allowing us to observe how the system behaves under stress.
*   **Kubernetes Manifests:** A full set of pre-configured manifests for the applications, Vertical Pod Autoscaler (VPA), and Horizontal Pod Autoscaler (HPA).

## Lab Objectives

*   Observe and identify a misconfigured, over-provisioned workload in the GKE UI.
*   Use VPA recommendations to right-size the workload's CPU and memory requests.
*   Witness the HPA scaling a correctly configured application in response to load.
*   Measure and validate the significant performance improvement after tuning.

---

## Prerequisites

*   `gcloud` CLI installed and configured.
*   `kubectl` CLI installed.
*   `docker` installed and configured to push to a container registry (or ensure Cloud Build API is enabled).
*   A GCP project where you have permissions to create GKE clusters and Artifact Registry repositories.

---

## Step 1: Deploy the Environment

First, provision the GKE cluster and deploy all the lab components from the root `gke-autoscaling-lab` directory.

1.  **Provision the Cluster:**
    The provided script creates a GKE Standard cluster with VPA enabled.
    ```bash
    # From the gke-autoscaling-lab directory
    chmod +x infrastructure/setup.sh
    infrastructure/setup.sh
    ```
    This command will take several minutes. Once finished, `kubectl` will be configured to point to your new cluster.

2.  **Build and Push Docker Images (using Google Cloud Build):**
    Our lab uses two custom applications. We need to build their Docker images and push them to a container registry. We will use Google Artifact Registry.

    First, ensure the Cloud Build API is enabled and create a repository (if not already done by `setup.sh`):
    ```bash
    # Set a variable for your project ID
    export PROJECT_ID=$(gcloud config get-value project)

    # Set a variable for the region (must match your cluster's region)
    export REGION="us-central1" # Or your cluster's region

    # Enable Cloud Build API
    gcloud services enable cloudbuild.googleapis.com --project "${PROJECT_ID}"

    # Create the Docker repository in Artifact Registry (if it doesn't exist)
    gcloud artifacts repositories create gke-lab-repo \
        --repository-format=docker \
        --location=${REGION} \
        --description="Docker repository for GKE autoscaling lab" || true
    ```

    Now, build and push the two images using Cloud Build. **Ensure the image tags match those in `kubernetes-manifests/01-workload-1-deployment.yaml` and `kubernetes-manifests/03-workload-2-deployment.yaml` (currently `v13.0.0` for both).**

    ```bash
    # Define image paths (adjust version tags if you've made further changes)
    export WORKLOAD_1_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-lab-repo/cpu-intensive-app:v13.0.0"
    export WORKLOAD_2_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-lab-repo/load-generator:v13.0.0"

    # Build and push workload-1-app
    echo "Building workload-1-app with Cloud Build..."
    gcloud builds submit gke-autoscaling-lab/workload-1-app \
        --tag ${WORKLOAD_1_IMAGE} \
        --project "${PROJECT_ID}"

    # Build and push workload-2-loadgen
    echo "Building workload-2-loadgen with Cloud Build..."
    gcloud builds submit gke-autoscaling-lab/workload-2-loadgen \
        --tag ${WORKLOAD_2_IMAGE} \
        --project "${PROJECT_ID}"
    ```

3.  **Deploy Applications and Autoscalers:**
    Apply all the Kubernetes manifests at once. This will deploy `workload-1`, `workload-2`, the VPA configuration, and the HPA configuration.
    ```bash
    # From the gke-autoscaling-lab directory
    kubectl apply -f kubernetes-manifests/
    ```

---

## Step 2: Observe the Initial Misconfiguration and Performance

Now, let's see how the inefficient, over-provisioned application behaves.

1.  **Check CPU Waste:**
    *   In the Google Cloud Console, navigate to **Kubernetes Engine -> Workloads**.
    *   Click on the `workload-1-deployment`.
    *   Go to the **Observability** tab.
    *   In the **CPU** chart, notice that the **Requested CPU** is **4 cores**, but the actual **CPU Usage** is only around **1 core**. This is a massive waste of reserved resources, and it's preventing the HPA from working correctly.

2.  **Measure Baseline Performance:**
    The load generator (`workload-2`) runs in a continuous loop. Let's find the performance result from its first full run.
    *   Navigate back to the **Workloads** screen.
    *   Click on `workload-2-loadgen`.
    *   Go to the **Logs** tab.
    *   In the "Filter" box, enter `"Total Responses Processed"`.
    *   You will see the output from the load test. Note down the number. This is your baseline performance with the misconfigured deployment.

---

## Step 3: Right-Size the Application using VPA

Let's use the VPA's recommendation to fix our CPU request.

1.  **Find the VPA Recommendation:**
    *   In the GKE navigation menu, go to **Workloads -> Vertical Pod Autoscalers**.
    *   Click on `workload-1-vpa`.
    *   Observe the **Recommended CPU** and **Recommended Memory** in the summary panel. They will be much lower than what is currently requested.

2.  **Apply the Recommendation:**
    *   Navigate back to **Workloads -> `workload-1-deployment`**.
    *   Click **Edit**.
    *   Switch to the **YAML** tab.
    *   Find the `resources` section for the `workload-1-app` container.
    *   For simplicity, change both `requests` and `limits` to more appropriate values based on the VPA recommendation:
        ```yaml
        resources:
          requests:
            cpu: "1"
            memory: "512Mi"
          limits:
            cpu: "1"
            memory: "512Mi"
        ```
    *   Click **Save**. GKE will trigger a rolling update of your deployment with the corrected resource requests.

---

## Step 4: Observe HPA Actuation and Performance Improvement

With the resource request corrected, the HPA can now accurately measure CPU utilization as a percentage and begin to scale the application.

1.  **Watch the HPA Scale:**
    *   Wait for the `workload-1-deployment` to finish its rolling update.
    *   Observe the deployment's details page. You will see the number of running pods increase from 1 up to the HPA's maximum of 5 as the load generator runs.

2.  **Check for Performance Improvement:**
    *   Go back to the logs for the `workload-2-loadgen` workload.
    *   Filter again for `"Total Responses Processed"`.
    *   Note the new number of processed responses. It should be significantly higher than your baseline, demonstrating the power of horizontal scaling.

---

## Step 5: Unleash the HPA for Maximum Performance

Our application is now efficient, but the HPA is limited to only 5 replicas. Let's increase that limit to see how much performance we can really get.

1.  **Increase HPA `maxReplicas`:**
    *   In the GKE navigation menu, go to **Workloads -> Horizontal Pod Autoscalers**.
    *   Click on `workload-1-hpa`.
    *   Click **Edit**.
    *   Switch to the **YAML** tab.
    *   Change `maxReplicas` from `5` to `20`.
    *   Click **Save**.

2.  **Measure Final Performance:**
    *   The load generator will start a new test run automatically.
    *   Go back to the logs for `workload-2-loadgen` one last time and filter for `"Total Responses Processed"`.
    *   Observe the final number. You should see another dramatic improvement in the number of total requests the application can handle.

**Congratulations!** You have successfully diagnosed a misconfigured application, used VPA recommendations to right-size it, and configured HPA to scale it for significantly improved performance.

---

## Cleanup

To avoid incurring ongoing charges, delete the resources you created.

```bash
# From the gke-autoscaling-lab directory
infrastructure/setup.sh cleanup
```
