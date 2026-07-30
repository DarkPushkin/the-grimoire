# Royal App Audit Reference — 2026-07-25

**Project:** Saint Mary Liberty Island / simplex-node  
**App:** royal_app (Isle Royal — AI Automatic Office Backend)  
**Date:** 2026-07-25  
**Auditor:** Hermes Agent using codebase-audit skill

---

## Key Findings Summary

| Severity | Count | Critical Items |
|----------|-------|----------------|
| 🔴 CRITICAL | 2 | Plaintext HTTP to sovereign backend, No authentication |
| 🟠 HIGH | 3 | Async context gaps (5 locations), No HTTP timeout, No cert pinning |
| 🟡 MEDIUM | 5 | Shared package divergence (~2000 LOC duplicated), No retry logic, Silent error swallowing |
| 🟢 LOW | 49 | Lint warnings (prefer_const_constructors, etc.) |

---

## Critical Security Gaps

### 1. Plaintext HTTP Transport
**File:** `lib/services/royal_api_service.dart:6`
```dart
static String defaultBaseUrl = 'http://127.0.0.1:8080';
```
**Impact:** All treasury operations (mint, burn, oracle, dividend, panic wipe) transmitted in cleartext over LAN/Tor. MITM can modify amounts, intercept keys.

**Fix:** 
- Configure HTTPS/TLS on simplex-node server (Let's Encrypt or self-signed with pinning)
- Update `defaultBaseUrl` to `https://...` or onion address
- Use `SecurityContext` with pinned certificate

### 2. Zero Authentication
**Files:** `lib/services/royal_api_service.dart` (all 87 methods)
```dart
Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};
```
**Impact:** Any network peer can execute treasury mutations.

**Fix:**
- Add `Authorization: Bearer <token>` header
- Store token in `flutter_secure_storage`
- Implement token refresh flow

---

## High-Risk Code Patterns

### 3. Async BuildContext Usage (5 locations)
```dart
// dashboard_screen.dart:41,43
await Future.wait([...]);
context.read<AppState>().setOffline(false);  // CRASH if disposed

// governance_screen.dart:55
await api.createProposal(...);
Navigator.pop(ctx);  // CRASH if disposed

// settings_screen.dart:59
await api.setEmergencyStop(...);
_refresh();  // CRASH if disposed
```
**Fix:** Wrap with `if (mounted)` or capture `context`/`mounted` before `await`.

### 4. No HTTP Timeout
```dart
final http.Client _client = http.Client();  // No timeout!
```
**Fix:** 
```dart
final http.Client _client = http.Client()..timeout = const Duration(seconds: 30);
```
Or use `IOClient` with custom timeout.

### 5. Silent Error Swallowing (7/8 screens)
```dart
catch (_) {}  // No user feedback, no logging
```
**Fix:** Show snackbar, error banner, retry button. Log to structured logger.

---

## Medium: Shared Package Divergence

### Unused Shared Packages (already built, used by isle_app)
| Package | Path | Purpose | royal_app Status |
|---------|------|---------|------------------|
| `api_client` | `apps/shared/api_client` | Typed HTTP client + transport envelope | ❌ Not used — 87 methods reimplemented |
| `models` | `apps/shared/models` | `Banknote`, `AppUser`, `SystemStatus`, etc. | ❌ Not used — raw `Map<String,dynamic>` everywhere |
| `widgets` | `apps/shared/widgets` | `SectionCard`, `StatusBadge`, `NgDisplay` | ❌ Not used — inline reimplementations |

**Estimated duplicate code:** ~2000 lines

**Migration path:**
1. Add to `pubspec.yaml`:
```yaml
dependencies:
  api_client: { path: ../shared/api_client }
  models: { path: ../shared/models }
  widgets: { path: ../shared/widgets }
```
2. Replace `RoyalApiService` with `RoyalClient` + `SimplexNodeClient`
3. Replace raw maps with `Banknote`, `SystemStatus`, `AppUser` models
4. Replace inline cards with `SectionCard`, `StatusBadge`

---

## Low: Lint Issues (49 total)

Run `dart fix --apply` for auto-fixable:
- `prefer_const_constructors` (~25)
- `prefer_const_literals_to_create_immutables` (1)
- `unnecessary_brace_in_string_interps` (4)

Manual fixes needed:
- `curly_braces_in_flow_control_structures` (4) — add braces to `if`/`else` single statements
- `use_build_context_synchronously` (5) — see Critical #3 above

---

## Test Coverage Gap

| File | Tests | Status |
|------|-------|--------|
| `test/widget_test.dart` | 1 smoke test | ⏱️ TIMEOUT (no Flutter SDK on server) |
| `royal_api_service.dart` | 0 | ❌ No unit tests |
| All screens | 0 | ❌ No widget tests |

**Recommendation:** Add `mockito` + `http_mock_adapter` for API service tests. Target 80% coverage on service layer.

---

## Build & Deployment Notes

- **Cannot build on netbook** — no Flutter SDK (per AGENTS.md hardware constraints)
- **Build on Lenovo (Windows 11)** or MacBook per build cycle
- **Platform support:** Android ✅, iOS ✅, Linux ✅, macOS ✅, Web ❌ (no `web/` dir)
- **Systemd service:** Not applicable (Flutter app, not Go binary)

---

## Commands for Future Audits

```bash
# From apps/royal_app/
flutter analyze                    # Static analysis (49 issues as of 2026-07-25)
flutter test                       # Unit/widget tests
dart fix --apply --dry-run         # Preview auto-fixes
flutter build linux --release      # Production build (requires Flutter SDK)

# Cross-check with shared packages
cd ../shared/api_client && flutter analyze
cd ../shared/models && flutter analyze
cd ../shared/widgets && flutter analyze

# Compare API endpoints with server
grep -r "api\." lib/ | grep -o '/api/[^'"'"'"\)]*' | sort -u
# Compare with server routes in cmd/simplex-node/main.go
```

---

## Related Files

- Full report: `/home/tomas/simplex-node/AUDIT-ROYAL-APP-2026-07-25.md`
- Project AGENTS.md: `/home/tomas/simplex-node/AGENTS.md` (build history, conventions)
- Shared packages: `/home/tomas/simplex-node/apps/shared/`
- Sister app (uses shared): `/home/tomas/simplex-node/apps/isle_app/`