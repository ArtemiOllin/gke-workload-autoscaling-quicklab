# GKE Autoscaling Lab: Mastering VPA and HPA

Welcome! This hands-on lab is designed for Site Reliability Engineers to learn how to effectively use Vertical Pod Autoscaler (VPA) and Horizontal Pod Autoscaler (HPA) on Google Kubernetes Engine (GKE).

We will simulate a common real-world scenario: a misconfigured, over-provisioned workload. We will first use VPA to find the correct resource requests ("right-sizing") and then use HPA to automatically scale the workload based on CPU demand.

**Lab Objectives:**

1.  **Provision a GKE Cluster** with VPA and Metrics Server enabled.
2.  **Deploy a Misconfigured Workload** with excessively high CPU requests.
3.  **Use VPA in "Recommendation Mode"** to determine the appropriate CPU and memory requests.
4.  **Manually Apply VPA Recommendations** to right-size the workload.
5.  **Use HPA to Horizontally Scale** the right-sized workload based on CPU utilization.
6.  **Observe Autoscaling in Action** in response to variable traffic.

---

## Prerequisites

- `gcloud` CLI installed and configured.
- `kubectl` CLI installed.
- `docker` installed and configured to push to a container registry.
- A GCP project where you have permissions to create GKE clusters and Artifact Registry repositories.

---

## Phase 1: Setup & Baseline Analysis

In this phase, we'll set up our infrastructure, build and deploy our applications, and observe the initial "misconfigured" state.

### Step 1.1: Provision the GKE Cluster

First, we need our Kubernetes cluster. The provided script creates a GKE Standard cluster with VPA enabled.

```bash
# Navigate to the infrastructure directory
cd infrastructure

# IMPORTANT: Set your GCP Project ID in the script if it's not
# already configured in your gcloud environment.
# Open setup.sh and edit the PROJECT_ID variable.

# Make the script executable and run it
chmod +x setup.sh
./setup.sh
```

This command will take several minutes to complete. Once finished, `kubectl` will be configured to point to your new cluster.

### Step 1.2: Build and Push Docker Images (using Google Cloud Build)

Our lab uses two custom applications. We need to build their Docker images and push them to a container registry. We will use Google Artifact Registry.

First, ensure the Cloud Build API is enabled and create a repository:

```bash
# Set a variable for your project ID
export PROJECT_ID=$(gcloud config get-value project)

# Set a variable for the region (must match your cluster's region)
export REGION="us-central1"

# Enable Cloud Build API
gcloud services enable cloudbuild.googleapis.com --project "${PROJECT_ID}"

# Create the Docker repository in Artifact Registry
gcloud artifacts repositories create gke-lab-repo \
    --repository-format=docker \
    --location=${REGION} \
    --description="Docker repository for GKE autoscaling lab"
```

Now, build and push the two images using Cloud Build:

```bash
# Define image paths
export WORKLOAD_1_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-lab-repo/cpu-intensive-app:v1.0.0"
export WORKLOAD_2_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-lab-repo/load-generator:v1.0.0"

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

### Step 1.3: Deploy the Applications

Now we need to update our Kubernetes manifests to use the images we just pushed.

**1. Update `01-workload-1-deployment.yaml`:**
   Open `gke-autoscaling-lab/kubernetes-manifests/01-workload-1-deployment.yaml` and replace the placeholder `image` with the path to your `cpu-intensive-app` image (`$WORKLOAD_1_IMAGE`).

**2. Update `03-workload-2-deployment.yaml`:**
   Open `gke-autoscaling-lab/kubernetes-manifests/03-workload-2-deployment.yaml` and replace the placeholder `image` with the path to your `load-generator` image (`$WORKLOAD_2_IMAGE`).

With the manifests updated, deploy all the resources:

```bash
# Navigate to the manifests directory
cd gke-autoscaling-lab/kubernetes-manifests

# Apply the initial set of manifests
kubectl apply -f 01-workload-1-deployment.yaml
kubectl apply -f 02-workload-1-service.yaml
kubectl apply -f 03-workload-2-deployment.yaml
```

### Step 1.4: Observe the Misconfiguration

Let's see why our setup is inefficient. We have two pods for `workload-1-deployment`, and we requested **4 CPU cores** for each. Let's check the actual usage.

```bash
# Wait for pods to be running
kubectl get pods -w

# Check the resource usage of the workload-1 pods
# The 'top' command may take a minute to become available
kubectl top pods -l app=workload-1
```

**Observation:**
You will see that the CPU usage is very low (e.g., `1m` or `2m`, which is 1 or 2 millicores), but the requested CPU is `4000m` (4 cores). This is a massive waste of resources. The GKE scheduler has reserved 8 cores on your nodes for these two pods that are doing almost nothing.

---

## Phase 2: Right-Sizing with VPA

Now, we'll use VPA to get recommendations for the correct CPU and memory requests.

### Step 2.1: Deploy VPA in Recommendation Mode

We will deploy a VPA resource that targets our `workload-1-deployment`. We'll use `updateMode: "Off"` so it only provides recommendations and doesn't change anything automatically.

```bash
# Apply the VPA manifest
kubectl apply -f 04-vpa.yaml
```

### Step 2.2: Let the Load Generator Run

The VPA needs to see the application under load to make good recommendations. The load generator we deployed in Phase 1 is already running, creating waves of traffic. Let it run for at least 5-10 minutes to allow VPA to collect sufficient data.

### Step 2.3: Inspect VPA Recommendations

After a few minutes, we can inspect the VPA object to see its recommendations.

```bash
# Describe the VPA object
kubectl describe vpa workload-1-vpa
```

Look for the `Recommendation` section in the output. It will look something like this:

```
Recommendation:
  Container Recommendations:
    Container Name:  workload-1-app
    Lower Bound:
      Cpu:     25m
      Memory:  262144k
    Target:
      Cpu:     850m
      Memory:  262144k
    Uncapped Target:
      Cpu:     850m
      Memory:  262144k
    Upper Bound:
      Cpu:     20
      Memory:  512Mi
```

**Analysis:**
- **`Target`**: This is the VPA's primary recommendation. In this example, it suggests we should be requesting `850m` CPU, not the `4000m` we originally set!
- **`Lower Bound` / `Upper Bound`**: These provide a safe range for resource requests.

### Step 2.4: Apply the VPA Recommendation

Now we will manually update our deployment to use the `Target` recommendation.

1.  **Open `01-workload-1-deployment.yaml`**.
2.  **Find the `resources.requests` section.**
3.  **Change `cpu` from `"4"` to the value recommended by the VPA `Target` (e.g., `"850m"`).**
4.  **Let's also update the memory to match the recommendation (e.g., `"256Mi"`).**

Your new resource block should look like this:

```yaml
        resources:
          requests:
            cpu: "850m" # <-- Updated from "4"
            memory: "256Mi"
          limits:
            # It's good practice to set limits higher than requests
            cpu: "1500m"
            memory: "512Mi"
```

Apply the change:

```bash
kubectl apply -f 01-workload-1-deployment.yaml
```

The deployment will perform a rolling update. We have now successfully **right-sized** our application!

---

## Phase 3: Scaling with HPA

Our application is now efficiently configured, but it can't handle traffic spikes. We'll now add an HPA to automatically scale the number of pods based on CPU load.

### Step 3.1: Deploy the HPA

The HPA is configured to maintain an average CPU utilization of 50% across all pods. If the average CPU load goes above 50% of the *requested* CPU, the HPA will add more pods.

```bash
# Apply the HPA manifest
kubectl apply -f 05-hpa.yaml
```

### Step 3.2: Observe the HPA in Action

Let's watch the HPA as our load generator continues its traffic waves.

```bash
# Watch the HPA status
kubectl get hpa -w
```

You will see the HPA's status change over a few minutes:

1.  **During a heavy traffic wave:** The CPU utilization will spike. You'll see the `TARGETS` column go above `50%` (e.g., `350%/50%`). In response, the HPA will increase the number of `REPLICAS`.

2.  **During a light traffic wave:** The CPU utilization will drop. The `TARGETS` will fall below `50%`. The HPA will then scale the `REPLICAS` back down to the minimum.

You can also watch the pods being created and terminated in another terminal:

```bash
kubectl get pods -l app=workload-1 -w
```

**Congratulations!** You have successfully used VPA to right-size a workload and HPA to automatically scale it based on real-time demand.

---

## Cleanup

To avoid incurring ongoing charges, delete the resources you created.

```bash
# Delete the GKE cluster
gcloud container clusters delete ${CLUSTER_NAME} --region ${REGION} --quiet

# Delete the Artifact Registry repository
gcloud artifacts repositories delete gke-lab-repo --location=${REGION} --quiet
```

You may also want to delete the Docker images from your local machine.

```
