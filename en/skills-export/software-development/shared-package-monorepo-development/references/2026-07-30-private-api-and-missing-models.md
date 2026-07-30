# Session: Fixing Private API Visibility & Missing Models (2026-07-30)

## Context
`isle_app` failed to build after a shared-package refactor that created `SimplexApiClient` (in `simplex_api_client.dart`) with private `_get`/`_post`/`_getBytes` methods, and `royal_client.dart` trying to call them via `_client._get(...)`.

## Error Sequence

### 1. Private methods not visible across files
```
Error: The method '_get' isn't defined for the type 'SimplexApiClient'.
```
**Root cause**: Dart `_` = library-private. Consumer files in same package but different file = different library. `_get` not visible from `royal_client.dart`.

**Fix**: Rename to public `get`/`post`/`getBytes` in `simplex_api_client.dart`, update all callers.

### 2. Missing model types cascade
After fixing (1), ~30 new errors appeared:
```
Type 'ReserveState' not found.
Type 'MintResult' not found.
Type 'BurnResult' not found.
Type 'Token' not found.
Type 'UploadResult' not found.
```
Each typed API client method (in `simplex_api_client.dart` inline classes and `royal_client.dart`) returns a typed model class that either:
- Doesn't exist yet (must be created in `models/`)
- Exists but isn't imported in the consumer file

### 3. Missing import in consumer file
`token_client.dart` uses `Token` and `TokenBalance` which live in `models/lib/src/token.dart`. It only imported `simplex_api_client.dart` — which doesn't re-export models. Fix: add `import 'package:models/models.dart';`.

## Files Modified

| File | Change |
|------|--------|
| `shared/api_client/lib/src/simplex_api_client.dart` | `_get`→`get`, `_post`→`post`, `_getBytes`→`getBytes` + all internal callers |
| `shared/api_client/lib/src/royal_client.dart` | `_client._get`→`_client.get`, `_client._post`→`_client.post` |
| `shared/api_client/lib/src/token_client.dart` | Added `import 'package:models/models.dart';` + `_get`/`_post`→`get`/`post` |
| `shared/api_client/lib/src/external_wallet_client.dart` | Added models import + `_get`/`_post`→`get`/`post` |
| `shared/models/lib/src/treasury.dart` | Added: SystemStatus, ReserveState, BurnResult, ProofOfReserve, Rates, Tokenomics, Forecast, Constitution, Proposal, ProposalDraft, VoteResult, DelegationResult |
| `shared/models/lib/src/vault.dart` | Added: UploadResult, DeleteResult |
| `shared/models/lib/src/token.dart` | Added: TokenBalancesResponse, TokenOperationResult |
| `shared/models/lib/src/system_status.dart` | Added: ServiceActionResult, BackupResult, CleanupResult, Config, MaintenanceMode, EmergencyStop, RateLimitStats, ContainerActionResult |

## State After Fixes
- `royal_app` builds and deploys successfully
- `isle_app` still has ~30 app-layer errors (identity_service API mismatch, main.dart params, welcome_screen method names)