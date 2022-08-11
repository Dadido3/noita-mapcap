// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	_ "net/http/pprof"
)

func init() {
	/*port := 1234

	go func() {
		http.ListenAndServe(fmt.Sprintf(":%d", port), nil)
	}()
	log.Printf("Profiler web server listening on port %d. Visit http://localhost:%d/debug/pprof", port, port)
	log.Printf("To profile the next 10 seconds and view the profile interactively:\n  go tool pprof -http :8080 http://localhost:%d/debug/pprof/profile?seconds=10", port)
	*/
}
