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

# Initial values for QPS and concurrency
CURRENT_QPS=${DEFAULT_QPS}
CURRENT_CONCURRENCY=${DEFAULT_CONCURRENCY}

echo "Load generator started."
echo "----------------------------------------"
echo "Configuration:"
echo "  Target URL:           ${TARGET_URL}"
echo "  Initial QPS:          ${DEFAULT_QPS}"
echo "  Initial Concurrency:  ${DEFAULT_CONCURRENCY}"
echo "  Cycle Length:         ${DEFAULT_CYCLE_LENGTH}"
echo "  Scale Factor:         ${SCALE_FACTOR}"
echo "  Number of Cycles:     ${NUMBER_OF_CYCLES}"
echo "  Wait Period:          ${WAIT_PERIOD}"
echo "----------------------------------------"

# Loop through the specified number of cycles
for i in $(seq 1 ${NUMBER_OF_CYCLES}); do
    echo "[$(date)] Starting Cycle ${i}/${NUMBER_OF_CYCLES} with QPS=${CURRENT_QPS}, Concurrency=${CURRENT_CONCURRENCY} for ${DEFAULT_CYCLE_LENGTH}..."
    hey -z "${DEFAULT_CYCLE_LENGTH}" -q "${CURRENT_QPS}" -c "${CURRENT_CONCURRENCY}" "${TARGET_URL}"

    # Scale up for the next cycle, if not the last cycle
    if [ "$i" -lt "${NUMBER_OF_CYCLES}" ]; then
        # Use 'bc' for floating point multiplication and 'cut' to truncate to integer
        CURRENT_QPS=$(echo "${CURRENT_QPS} * ${SCALE_FACTOR}" | bc | cut -d '.' -f 1)
        CURRENT_CONCURRENCY=$(echo "${CURRENT_CONCURRENCY} * ${SCALE_FACTOR}" | bc | cut -d '.' -f 1)
        
        echo "[$(date)] Scaling up for next cycle: New QPS=${CURRENT_QPS}, New Concurrency=${CURRENT_CONCURRENCY}"
        echo "[$(date)] Waiting for ${WAIT_PERIOD} before next cycle..."
        sleep "${WAIT_PERIOD}"
    fi
done

echo "[$(date)] All load cycles completed. The script will now exit. The pod will restart based on the 'restartPolicy'."
