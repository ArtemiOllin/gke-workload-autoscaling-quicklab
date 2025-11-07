#!/bin/sh
#
# Description: Generates traffic in a stepped pattern to the target service.
#

set -e

# Configuration is now driven by environment variables with sensible defaults.
TARGET_URL="${TARGET_URL:-http://workload-1-svc:8080/calculate}"

# Load generation parameters for stepped load
DEFAULT_QPS="${DEFAULT_QPS:-25}"
DEFAULT_CONCURRENCY="${DEFAULT_CONCURRENCY:-10}"
DEFAULT_CYCLE_LENGTH="${DEFAULT_CYCLE_LENGTH:-60s}"
SCALE_FACTOR="${SCALE_FACTOR:-2}" # Multiplier for QPS and concurrency each cycle
NUMBER_OF_CYCLES="${NUMBER_OF_CYCLES:-3}" # Total number of load steps
WAIT_PERIOD="${WAIT_PERIOD:-5s}" # Wait period between cycles

echo "--------------------------------------------------------------"
echo "Load generator started. Configuration:"
echo "   Target URL:             ${TARGET_URL}"
echo "   Initial cycle:          ${DEFAULT_QPS} qps / ${DEFAULT_CONCURRENCY}" workers
echo "   Cycle length / number:  ${DEFAULT_CYCLE_LENGTH} / ${NUMBER_OF_CYCLES}"
echo "   Scale factor:           ${SCALE_FACTOR}x"
echo "   Wait period:            ${WAIT_PERIOD}"
echo "--------------------------------------------------------------"

while true; do
    # Reset variables for this run
    CURRENT_QPS=${DEFAULT_QPS}
    CURRENT_CONCURRENCY=${DEFAULT_CONCURRENCY}
    TOTAL_RESPONSES=0

    # Loop through the specified number of cycles
    for i in $(seq 1 ${NUMBER_OF_CYCLES}); do
        # Run hey and capture its output
        HEY_OUTPUT=$(hey -z "${DEFAULT_CYCLE_LENGTH}" -q "${CURRENT_QPS}" -c "${CURRENT_CONCURRENCY}" "${TARGET_URL}" 2>&1)
        
        # Extract metrics from hey output
        CURRENT_QPS_ACTUAL=$(echo "${HEY_OUTPUT}" | grep "Requests/sec" | awk '{print $2}')
        CURRENT_TOTAL_DURATION_SECONDS=$(echo "${HEY_OUTPUT}" | grep "Total:" | awk '{print $2}')

        # Calculate responses for this cycle (handle potential empty output from hey)
        if [ -n "${CURRENT_QPS_ACTUAL}" ] && [ -n "${CURRENT_TOTAL_DURATION_SECONDS}" ]; then
            CYCLE_RESPONSES=$(echo "${CURRENT_QPS_ACTUAL} * ${CURRENT_TOTAL_DURATION_SECONDS}" | bc | cut -d '.' -f 1)
            TOTAL_RESPONSES=$(echo "${TOTAL_RESPONSES} + ${CYCLE_RESPONSES}" | bc | cut -d '.' -f 1)
        fi

        # Scale up for the next cycle, if not the last cycle
        if [ "$i" -lt "${NUMBER_OF_CYCLES}" ]; then
            CURRENT_QPS=$(echo "${CURRENT_QPS} * ${SCALE_FACTOR}" | bc | cut -d '.' -f 1)
            CURRENT_CONCURRENCY=$(echo "${CURRENT_CONCURRENCY} * ${SCALE_FACTOR}" | bc | cut -d '.' -f 1)
            
            sleep "${WAIT_PERIOD}"
        fi
    done

    echo "Test cycle completed, total responses processed: ${TOTAL_RESPONSES}"

done
