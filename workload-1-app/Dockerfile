# --- Build Stage ---
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy source code
COPY main.go go.mod ./

# Build the Go app
# CGO_ENABLED=0 is important for a clean static binary
# -ldflags="-s -w" strips debugging information to reduce binary size
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o cpu-intensive-app .

# --- Final Stage ---
FROM alpine:latest

WORKDIR /app

# Copy the built binary from the builder stage
COPY --from=builder /app/cpu-intensive-app .

# Expose the port the app runs on
EXPOSE 8080

# Set the binary as the entrypoint
ENTRYPOINT ["./cpu-intensive-app"]
