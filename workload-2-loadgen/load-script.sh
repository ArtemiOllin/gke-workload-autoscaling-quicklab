#!/bin/sh
#
# Description: Generates traffic in waves to the target service.
#

set -e

# URL of the target service. This will be resolved by Kubernetes DNS.
# The service name is 'workload-1-svc' as defined in the Kubernetes manifests.
TARGET_URL="http://workload-1-svc:8080/calculate"

# Load generation parameters
HEAVY_TRAFFIC_DURATION="60s" # Duration of the heavy traffic phase
LIGHT_TRAFFIC_DURATION="60s" # Duration of the light traffic (pause) phase
HEAVY_TRAFFIC_QPS=25        # Queries per second during heavy phase
LIGHT_TRAFFIC_QPS=5         # Queries per second during light phase
HEAVY_TRAFFIC_CONCURRENCY=10 # Number of concurrent workers

echo "Load generator started. Target: ${TARGET_URL}"

# Infinite loop to generate waves of traffic
while true; do
    echo "----------------------------------------"
    echo "[$(date)] Starting HEAVY traffic wave for ${HEAVY_TRAFFIC_DURATION}..."
    echo "----------------------------------------"
    # Use 'hey' to generate a heavy load.
    # -z: Duration
    # -q: QPS rate limit
    # -c: Concurrency level
    hey -z "${HEAVY_TRAFFIC_DURATION}" -q "${HEAVY_TRAFFIC_QPS}" -c "${HEAVY_TRAFFIC_CONCURRENCY}" "${TARGET_URL}"

    echo "----------------------------------------"
    echo "[$(date)] Starting LIGHT traffic wave for ${LIGHT_TRAFFIC_DURATION}..."
    echo "----------------------------------------"
    hey -z "${LIGHT_TRAFFIC_DURATION}" -q "${LIGHT_TRAFFIC_QPS}" -c 5 "${TARGET_URL}"
done
