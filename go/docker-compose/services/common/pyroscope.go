package common

import (
	"log"
	"os"

	"github.com/grafana/pyroscope-go"
)

// initProfiling starts the Pyroscope continuous profiler, pushing CPU,
// allocation, in-use heap, and goroutine profiles to PYROSCOPE_SERVER_ADDRESS
// (Grafana Alloy, set in docker-compose.yml). When that variable is unset —
// e.g. the k8s deployment reusing these images — profiling is a clean no-op.
// Returns a stop function and whether the profiler is running (which decides
// whether the tracer provider is wrapped for span↔profile correlation).
func initProfiling(serviceName string) (func() error, bool) {
	noop := func() error { return nil }
	addr := os.Getenv("PYROSCOPE_SERVER_ADDRESS")
	if addr == "" {
		log.Print("pyroscope: PYROSCOPE_SERVER_ADDRESS not set, continuous profiling disabled")
		return noop, false
	}
	name := os.Getenv("PYROSCOPE_APPLICATION_NAME")
	if name == "" {
		name = serviceName
	}
	profiler, err := pyroscope.Start(pyroscope.Config{
		ApplicationName: name,
		ServerAddress:   addr,
		Tags:            map[string]string{"service_namespace": "bookstore"},
		ProfileTypes: []pyroscope.ProfileType{
			pyroscope.ProfileCPU,
			pyroscope.ProfileAllocObjects,
			pyroscope.ProfileAllocSpace,
			pyroscope.ProfileInuseObjects,
			pyroscope.ProfileInuseSpace,
			pyroscope.ProfileGoroutines,
		},
	})
	if err != nil {
		// Profiling must never take the service down; run without it.
		log.Printf("pyroscope: start failed, continuing without profiling: %v", err)
		return noop, false
	}
	log.Printf("pyroscope: pushing profiles for %s to %s", name, addr)
	return profiler.Stop, true
}
