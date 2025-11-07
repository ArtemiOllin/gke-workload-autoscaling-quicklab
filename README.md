# GKE Autoscaling Lab: Right-Sizing and Performance Tuning

Welcome! This hands-on lab demonstrates the real-world impact of resource right-sizing and autoscaling on application performance using Google Kubernetes Engine (GKE).

## Lab Overview

This repository contains a complete environment to explore GKE autoscaling features. It includes:

*   **Infrastructure Script:** A `setup.sh` script to provision a GKE cluster with all necessary components.
*   **CPU-Intensive Application (`workload-1`):** A web application that performs CPU-intensive calculations. It is intentionally limited to use only **one CPU core** per replica to simulate a resource-bound service.
*   **Stepped Load Generator (`workload-2`):** An application that uses `hey` to generate a progressively increasing load against `workload-1`, allowing us to observe how the system behaves under stress.
*   **Kubernetes Manifests:** A full set of pre-configured manifests for the applications, Vertical Pod Autoscaler (VPA), and Horizontal Pod Autoscaler (HPA).

**Lab Goal:** You will deploy a misconfigured, over-provisioned application and observe its poor performance. Then, using VPA recommendations and HPA adjustments directly in the GKE UI, you will right-size the application and scale it out to dramatically improve its throughput.

---

## Step 1: Deploy the Environment

First, provision the GKE cluster and deploy all the lab components.

1.  **Provision the Cluster:**
    The provided script creates a GKE Standard cluster with VPA enabled.
    ```bash
    # Navigate to the infrastructure directory
    cd gke-autoscaling-lab/infrastructure

    # Make the script executable and run it
    chmod +x setup.sh
    ./setup.sh
    ```
    This command will take several minutes. Once finished, `kubectl` will be configured to point to your new cluster.

2.  **Deploy Applications and Autoscalers:**
    Apply all the Kubernetes manifests at once. This will deploy `workload-1`, `workload-2`, the VPA configuration, and the HPA configuration.
    ```bash
    # Navigate to the manifests directory from the repository root
    cd ../kubernetes-manifests

    # Apply all manifests
    kubectl apply -f .
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
    The load generator (`workload-2`) runs in cycles and reports the total number of successful requests at the end of each run. Let's find this number.
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
    *   Observe the **Recommended CPU** in the summary panel. It will be close to **1 core**, confirming our observation.

2.  **Apply the Recommendation:**
    *   Navigate back to **Workloads -> `workload-1-deployment`**.
    *   Click **Edit**.
    *   Switch to the **YAML** tab.
    *   Find the `resources` section for the `workload-1-app` container.
    *   For simplicity, change both `requests` and `limits` to the following:
        ```yaml
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "1"
            memory: "2Gi"
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
# Navigate to the infrastructure directory
cd gke-autoscaling-lab/infrastructure

# Run the cleanup portion of the script
./setup.sh cleanup
```