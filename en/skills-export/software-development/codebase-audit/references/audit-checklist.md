# Codebase Audit Checklist

Comprehensive pattern checklist for Go + Flutter/Dart + Script audits.

## Go Patterns

### Build & Compile
- [ ] `go build ./...` passes
- [ ] `go vet ./...` passes
- [ ] `go test ./...` passes
- [ ] `go test -race ./...` passes (CGO enabled)
- [ ] `golangci-lint run` passes (if available)

### Concurrency
- [ ] All `go func()` have context cancellation or stop channel
- [ ] No bare `go io.Copy()` without lifecycle management
- [ ] `sync.WaitGroup` used correctly (Add before goroutine, Done in defer)
- [ ] No channel operations on nil channels
- [ ] No goroutine leaks on shutdown (signal handling)

### File I/O
- [ ] `os.Create`/`os.OpenFile` followed by `defer f.Close()`
- [ ] No `f.Close()` at end of function without defer
- [ ] `os.Remove`/`os.Rename` errors checked
- [ ] Temp files cleaned up (`os.Remove` in defer)

### Error Handling
- [ ] No `_ =` ignoring errors in critical paths
- [ ] `fmt.Errorf` with `%w` for wrapping
- [ ] Sentinel errors for expected failures
- [ ] Panic recovery in HTTP handlers (`defer recover()`)

### Security
- [ ] No hardcoded passwords, API keys, secrets
- [ ] No SQL injection (use parameterized queries)
- [ ] No path traversal (`filepath.Clean`, prefix checks)
- [ ] Input validation on all public endpoints
- [ ] Rate limiting on public APIs
- [ ] TLS for external connections

### Memory/Performance
- [ ] No unbounded slice/map growth
- [ ] `sync.Pool` for frequent allocations
- [ ] Proper buffer sizing (not 1-byte reads)
- [ ] Context timeouts on external calls

## Flutter/Dart Patterns

### Static Analysis
- [ ] `flutter analyze` passes (0 errors)
- [ ] Warnings reviewed (unused fields, dead code, etc.)

### Memory
- [ ] `TextEditingController` not created in `build()`
- [ ] `AnimationController`/`StreamController` disposed in `dispose()`
- [ ] `StreamSubscription` cancelled in `dispose()`
- [ ] `Timer` cancelled in `dispose()`

### Network
- [ ] `Uri.resolve()` used instead of string interpolation
- [ ] `Content-Length` set for POST bodies
- [ ] Timeouts on all HTTP clients
- [ ] Certificate pinning for sensitive connections

### State Management
- [ ] No `setState` after dispose
- [ ] `FutureBuilder`/`StreamBuilder` handle error states
- [ ] Keys used correctly in lists

## Shell/Scripts
- [ ] `set -euo pipefail` at top
- [ ] Variables quoted: `"$VAR"`
- [ ] No `eval` with user input
- [ ] Temp files with `mktemp`
- [ ] Cleanup traps: `trap 'cleanup' EXIT`

## Flutter/Dart Security (Added from royal_app audit)
- [ ] **No plaintext HTTP** — all endpoints use HTTPS/TLS with certificate pinning
- [ ] **Authentication on all requests** — token/JWT/API key in headers, stored securely (`flutter_secure_storage`)
- [ ] **No hardcoded base URLs** — config via env vars or secure preferences
- [ ] **Input validation client-side** — positive amounts, valid prices, non-empty strings before API calls
- [ ] **HTTP timeout configured** — `http.Client` with explicit timeout (15-30s)
- [ ] **Retry/backoff for idempotent calls** — exponential backoff on GET, safe POST
- [ ] **BuildContext async safety** — `if (mounted)` guards after every `await`
- [ ] **Certificate pinning** — `SecurityContext` with pinned SHA256 for sensitive backends
- [ ] **No unused dependencies** — `shared_preferences` or similar actually used if declared

## Cross-Cutting

### Configuration
- [ ] No hardcoded IPs/ports (env vars or config files)
- [ ] Secrets via env vars or secret manager
- [ ] Config validation at startup

### Logging
- [ ] Structured logging (JSON/slog)
- [ ] No secrets in logs
- [ ] Log levels appropriate (debug/info/warn/error)

### Testing
- [ ] Unit tests for business logic
- [ ] Integration tests for API endpoints
- [ ] Race detector in CI
- [ ] Coverage > 70% for critical paths