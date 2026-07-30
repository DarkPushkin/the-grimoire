---
name: shared-package-monorepo-development
description: "Flutter/Go monorepo with path deps for blocked pub.dev."
trigger: Monorepo with shared Dart packages (models, api_client, widgets) where pub.dev is blocked, requiring path dependencies and model-first development.
---

# Shared Package Monorepo Development

## Context
Monorepos with:
- **Flutter apps** (citizen + admin)
- **Shared Dart packages**: `models`, `api_client`, `widgets`
- **Go backend** with HTTP API
- **Network constraints**: Tor proxy blocks `pub.dev` -> must use `path:` dependencies
- **Static analysis**: `flutter analyze --no-pub` times out -> use `dart analyze <file>` per-file

## Core Patterns

### 1. Model-First Development
**Define shared models before screens that consume them.**
- Backend Go handlers define JSON response shape
- Dart models in `shared/models/lib/src/` must match both:
  - Backend JSON field names (snake_case to camelCase via manual `fromJson`)
  - Frontend screen field access patterns
- Missing models cause cascade of `undefined_class` / `undefined_getter` errors

### 2. Path Dependencies (Tor Proxy Workaround)
```yaml
# In each app's pubspec.yaml
dependencies:
  models:
    path: ../shared/models
  api_client:
    path: ../shared/api_client
  widgets:
    path: ../shared/widgets
```
- **Never use `git:` dependencies** -- Tor proxy blocks GitHub
- Run `flutter pub get` in each app directory after model changes
- If `flutter pub get` fails, `dart analyze` still works for syntax checking

### 3. Static Analysis Workflow
```bash
# Full analyze times out (120s+)
# Per-file analyze is fast (<2s)
dart analyze apps/isle_app/lib/screens/royal_screen.dart
dart analyze apps/isle_app/lib/screens/
```
- Fix errors screen-by-screen
- Warnings (unused imports, prefer_const) are non-blocking
- Exit code 0 = clean, 3 = errors

### 4. API Client Architecture
- **Single unified client**: `SimplexApiClient` in `shared/api_client`
- **Typed domain sub-clients**: `WalletApi`, `MarketApi`, `RoyalClient`, `SystemApi`, `ChatApi`, `RadioApi`, `VaultApi`, `PosApi`, `ParanoidXApi`, `TreasuryApi`, `GovernanceApi`, `EconomyApi`
- **Interceptors**: Auth (Ed25519 signatures), logging, timeout (30s), retry
- **WebSocket**: For real-time chat/radio
- **Offline cache**: Drift/SQLite for read-heavy endpoints

### 5. Phase-Based Evolution (simplex-node pattern)
| Phase | Focus | Status |
|-------|-------|--------|
| 0 | BIP39 identity, shared packages, iOS/Android build fix | Done |
| 1 | Unified SimplexApiClient (onion routing, typed endpoints, WS, cache) | Done |
| 2 | Isle citizen screens to SimplexApiClient + shared models | Done (11/11) |
| 3 | Royal admin screens to SimplexApiClient (migrate from legacy royal_api_service) | In Progress |
| 4 | Differentiators: pairing, TLR-TL, bonds, staking, POS, mesh | Pending |

## Pitfalls & Fixes

### Missing Model Fields
**Symptom**: `The getter 'fieldName' isn't defined for the type 'ModelClass'`
**Fix**: Check backend Go handler JSON output -> add field to Dart model -> run `dart analyze` on dependent screens

### Model/Backend Mismatch
**Symptom**: `type 'int' is not a subtype of type 'double'` or null errors
**Fix**: Go uses `int64` for ng amounts -> Dart `int`; optional fields -> nullable with `??` defaults in `fromJson`

### Screen Uses Fields Model Doesn't Have
**Symptom**: Screen references `model.serial`, `model.grade` but model has `id`, `itemId`
**Fix**: Either extend model with computed getters OR refactor screen to use actual model fields

### Unused Import Warnings After Model Moves
**Fix**: `dart fix --apply` on the app directory, or manually remove unused `show` clauses

### TabBarView Children Count Mismatch
**Symptom**: `TabBarView` children length != `TabBar` tabs length
**Fix**: Ensure `TabController(length: N)` matches both `TabBar(tabs: [...].length == N)` and `TabBarView(children: [...].length == N)`

### ⚠️ Private API Methods Not Visible Across Files (Dart Library Privacy)
**Symptom**: `The method '_get' isn't defined for the type 'SimplexApiClient'` in consumer files like `royal_client.dart`, `token_client.dart`. `SimplexApiClient` clearly defines `_get`/`_post` but they can't be found.

**Cause**: In Dart, the `_` prefix makes members **library-private** (file-scoped). Two `.dart` files in the same package are separate libraries by default. Methods declared as `_get`, `_post`, `_getBytes` in one file like `simplex_api_client.dart` are NOT accessible from another file like `royal_client.dart`.

**Fix**: Rename private methods to public:
```
// BEFORE (in simplex_api_client.dart):
Future<Map<String, dynamic>> _get(String path, ...) async { ... }
// AFTER:
Future<Map<String, dynamic>> get(String path, ...) async { ... }
```
Then update ALL callers: `_client._get(` → `_client.get(` across every file in the package.

**Alternative**: Use `part`/`part of` to share library scope. Not recommended — creates monolithic files.

### ⚠️ Missing Model Types in Typed API Clients
**Symptom**: `Type 'MintResult' not found`, `Type 'ReserveState' not found`, `The getter 'Token' isn't defined for the type 'TokenClient'` despite model files existing.

**Causes**:
1. **Missing import** in consumer file — the file uses types from `models` but doesn't import the package. Dart imports are NOT transitive unless re-exported. Fix: add `import 'package:models/models.dart';` directly.
2. **Missing model class** — the type is listed in a `show` import clause but doesn't exist yet. Fix: define the class (simple value class with `fromJson` factory) in the appropriate models file.
3. **Missing re-export** — a class was added to a models file but `models.dart` doesn't `export` it.

**Model class pattern:**
```
class BurnResult {
  final bool success;
  final String assetId;
  final int amountNg;
  final String message;
  BurnResult({this.success = false, this.assetId = '', this.amountNg = 0, this.message = ''});
  factory BurnResult.fromJson(Map<String, dynamic> json) => BurnResult(
    success: json['success'] ?? false, assetId: json['asset_id'] ?? '',
    amountNg: (json['amount_ng'] ?? 0).toInt(), message: json['message'] ?? '',
  );
}
```
Place by domain: treasury/gov → `treasury.dart`, vault → `vault.dart`, token → `token.dart`, system → `system_status.dart`.

### ⚠️ Flutter Build Stale Cache After Model Changes
**Symptom**: After fixing model files, `flutter build` still reports old errors.

**Fix**: `flutter clean && flutter pub get` before rebuilding.

## Verification Checklist
After model changes:
- [ ] `dart analyze apps/shared/models/lib/src/` -- models clean
- [ ] `dart analyze apps/isle_app/lib/screens/<changed_screen>.dart` -- each screen clean
- [ ] `dart analyze apps/royal_app/lib/screens/` -- admin screens clean (if migrated)
- [ ] Run `go build ./cmd/simplex-node/` -- backend compiles
- [ ] Check API client sub-clients use updated models

## References
- `references/error-patterns.md` — Flexible field access patterns
- `references/session-2026-07-25-model-screen-fixes.md` — Model-screen migration session
- `references/2026-07-30-private-api-and-missing-models.md` — Fixing Dart private API visibility across files + adding missing model types

## See Also
- `autonomous-ai-agents/simplex-node-opencode` — Project-specific OpenCode workflows for 20-cycle evolution
- `software-development/test-driven-development` — RED-GREEN-REFACTOR for new endpoints
- `software-development/systematic-debugging` — 4-phase root cause for analysis failures