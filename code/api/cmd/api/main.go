// Command api serves booth data and checks answers for the AR CTF app.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

const (
	addr              = ":8000"
	readHeaderTimeout = 5 * time.Second
)

func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(map[string]string{"message": "Hello World"}); err != nil {
			log.Printf("encode response: %v", err)
		}
	})
	return mux
}

func main() {
	srv := &http.Server{Addr: addr, Handler: newMux(), ReadHeaderTimeout: readHeaderTimeout}
	log.Fatal(srv.ListenAndServe())
}
