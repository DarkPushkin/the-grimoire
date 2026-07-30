# Flutter Tor Proxy Workaround — pub.dev 501 Error

## Problem
On systems routing all traffic through Tor (v2ray/Xray with Tor outbound), `flutter pub get` and `flutter build` fail because:
- pub.dev connections go through Tor SOCKS proxy
- Tor is not an HTTP proxy — it speaks SOCKS5
- Flutter's HTTP client tries CONNECT tunnel via HTTP proxy
- Tor returns `501 Tor is not an HTTP Proxy`
- Error: `Proxy failed to establish tunnel (501 Tor is not an HTTP Proxy), uri=//pub.dev:443`

## Root Cause
Environment variables `http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `all_proxy` point to Tor SOCKS port (typically `socks5://127.0.0.1:10808` or similar). Flutter's `http` package treats them as HTTP proxies.

## Solution: Unset All Proxy Variables for Flutter Commands

### Inline (Per Command)
```bash
# pub get
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
flutter pub get

# build
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
flutter build linux --release
```

### Shell Function (Reusable)
```bash
flutter_no_proxy() {
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
  flutter "$@"
}

# Usage
flutter_no_proxy pub get
flutter_no_proxy build linux --release
flutter_no_proxy doctor
```

### Persistent (Current Shell)
```bash
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
# Then run flutter commands normally
flutter pub get
flutter build linux --release
```

## Common Dependency Fixes When Behind Proxy

### bip32 Version Downgrade
```yaml
# pubspec.yaml
dependencies:
  bip32: ^2.0.0  # Was ^3.0.0 — newer version 403s via proxy
```

### Clean Before Retry
```bash
rm -rf apps/*/build .dart_tool
flutter_no_proxy pub get
flutter_no_proxy build linux --release
```

## Build Output Location
```
apps/<app_name>/build/linux/x64/release/bundle/
├── <app_name>           # Main binary
├── lib/                 # Flutter engine .so files (libflutter_linux_gtk.so, etc.)
└── data/                # icudtl.dat, assets, fonts
```

## Required for Binary Execution
The binary needs its `lib/` and `data/` directories alongside it:
```bash
# Deploy structure
~/.local/bin/the-isle/
├── isle_app
├── lib/
└── data/

~/.local/bin/the-royal/
├── royal_app
├── lib/
└── data/
```

## Verification
```bash
# Should show "cursor theme" Gdk message (GUI launched, timed out = success in headless)
timeout 10 ~/.local/bin/the-isle/isle_app 2>&1 | grep -q "cursor theme" && echo "OK"

# Check binary type
file ~/.local/bin/the-isle/isle_app
# ELF 64-bit LSB executable, x86-64, dynamically linked
```

## Notes
- This is a **build-time** workaround only — runtime Tor proxy still works for app network traffic
- The app itself uses `tor_aware_client.dart` for onion connections at runtime
- Only `flutter pub get` and `flutter build` need clean environment
- Go builds (`go build`) may also need proxy unset for module downloads