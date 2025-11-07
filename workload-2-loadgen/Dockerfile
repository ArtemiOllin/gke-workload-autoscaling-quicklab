# Use a Go image to easily install 'hey'
FROM golang:1.21-alpine

# Install hey and git (required for go install)
RUN apk add --no-cache git && \
    git clone https://github.com/rakyll/hey.git /tmp/hey && \
    cd /tmp/hey && \
    go build -o /usr/local/bin/hey . && \
    rm -rf /tmp/hey

WORKDIR /app

# Copy the load generation script
COPY load-script.sh .

# Make the script executable
RUN chmod +x load-script.sh

# Set the script as the entrypoint
ENTRYPOINT ["/app/load-script.sh"]

