#!/bin/sh
#
# Description: Generates traffic in waves to the target service.
#

set -e

# Configuration is now driven by environment variables with sensible defaults.
TARGET_URL="${TARGET_URL:-http://workload-1-svc:8080/calculate}"

# Load generation parameters
HEAVY_TRAFFIC_DURATION="${HEAVY_TRAFFIC_DURATION:-60s}"
LIGHT_TRAFFIC_DURATION="${LIGHT_TRAFFIC_DURATION:-60s}"
HEAVY_TRAFFIC_QPS="${HEAVY_TRAFFIC_QPS:-25}"
LIGHT_TRAFFIC_QPS="${LIGHT_TRAFFIC_QPS:-5}"
HEAVY_TRAFFIC_CONCURRENCY="${HEAVY_TRAFFIC_CONCURRENCY:-10}"
LIGHT_TRAFFIC_CONCURRENCY="${LIGHT_TRAFFIC_CONCURRENCY:-5}"


echo "Load generator started."
echo "----------------------------------------"
echo "Configuration:"
echo "  Target URL: ${TARGET_URL}"
echo "  Heavy Traffic:"
echo "    Duration:    ${HEAVY_TRAFFIC_DURATION}"
echo "    QPS:         ${HEAVY_TRAFFIC_QPS}"
echo "    Concurrency: ${HEAVY_TRAFFIC_CONCURRENCY}"
echo "  Light Traffic:"
echo "    Duration:    ${LIGHT_TRAFFIC_DURATION}"
echo "    QPS:         ${LIGHT_TRAFFIC_QPS}"
echo "    Concurrency: ${LIGHT_TRAFFIC_CONCURRENCY}"
echo "----------------------------------------"


# Infinite loop to generate waves of traffic
while true; do
    echo "[$(date)] Starting HEAVY traffic wave..."
    hey -z "${HEAVY_TRAFFIC_DURATION}" -q "${HEAVY_TRAFFIC_QPS}" -c "${HEAVY_TRAFFIC_CONCURRENCY}" "${TARGET_URL}"

    echo "[$(date)] Starting LIGHT traffic wave..."
    hey -z "${LIGHT_TRAFFIC_DURATION}" -q "${LIGHT_TRAFFIC_QPS}" -c "${LIGHT_TRAFFIC_CONCURRENCY}" "${TARGET_URL}"
done
