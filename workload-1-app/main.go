package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"runtime"
	"time"
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

	// The number to calculate. 36 is high enough to cause significant CPU load.
	fibNumber := 36
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

func main() {
	// Limit the Go runtime to use only one CPU core.
	// This fulfills the lab requirement to constrain the application at the code level.
	runtime.GOMAXPROCS(1)

	http.HandleFunc("/calculate", calculateHandler)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "CPU-intensive workload is running. Hit /calculate to trigger a calculation.")
	})

	port := "8080"
	log.Printf("Server starting on port %s...", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
