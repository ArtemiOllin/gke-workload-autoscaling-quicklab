package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"time"
)

var (
	fibNumber  int
	gomaxprocs int
	port       string
)

// fib calculates the nth Fibonacci number recursively.
// This is intentionally inefficient to consume CPU.
func fib(n int) int {
	if n <= 1 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

// Response is the JSON structure returned by the handler.
type Response struct {
	FibResult         int    `json:"fib_result"`
	CalculationTimeMs int64  `json:"calculation_time_ms"`
	Message           string `json:"message"`
}

// calculateHandler handles requests to /calculate.
func calculateHandler(w http.ResponseWriter, r *http.Request) {
	startTime := time.Now()

	result := fib(fibNumber)

	duration := time.Since(startTime)

	response := Response{
		FibResult:         result,
		CalculationTimeMs: duration.Milliseconds(),
		Message:           fmt.Sprintf("Successfully calculated Fibonacci(%d)", fibNumber),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding JSON response: %v", err)
	}
}

// getEnv converts a string environment variable to an integer or returns a default value.
func getEnv(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		log.Printf("Invalid value for %s: %s. Using default %d", key, valueStr, defaultValue)
		return defaultValue
	}
	return value
}

func main() {
	// Read configuration from environment variables
	fibNumber = getEnv("FIB_NUMBER", 36)
	gomaxprocs = getEnv("GOMAXPROCS", 1)
	port = os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Limit the Go runtime to the configured number of CPU cores.
	runtime.GOMAXPROCS(gomaxprocs)

	log.Printf("Configuration: FIB_NUMBER=%d, GOMAXPROCS=%d, PORT=%s", fibNumber, gomaxprocs, port)

	http.HandleFunc("/calculate", calculateHandler)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "CPU-intensive workload is running. Hit /calculate to trigger a calculation.")
	})

	log.Printf("Server starting on port %s...", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
