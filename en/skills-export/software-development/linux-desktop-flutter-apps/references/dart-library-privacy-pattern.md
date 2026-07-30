# Dart Library-Level Privacy in Flutter Monorepos

## The Problem
In Dart, the `_` prefix makes a member **library-private**, not class-private as in many other languages. Each `.dart` file is its own implicit library unless `library` / `part of` directives are used.

This means:
- `FileA.dart` defines `class X` with method `_get()` 
- `FileB.dart` instantiates `X` and calls `._get()`
- ❌ **Compile error**: `The method '_get' isn't defined for the type 'X'`

## Why It Happens in simplex-node
The shared `api_client` package has:
- `simplex_api_client.dart` — defines `SimplexApiClient` with private `_get()`, `_post()`, `_getBytes()`. Also defines inline sub-classes (`WalletApi`, `MarketApi`, `TreasuryApi`, etc.) that call `_client._get()` — **these work** because they're in the same file (same library).
- `royal_client.dart` — defines `RoyalClient` with `SimplexApiClient _client`, calls `_client._get()` — **fails** because it's a different file (different library).

## The Fix
Rename the methods from private to public by removing the underscore:
```dart
// Before
Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async { ... }

// After  
Future<Map<String, dynamic>> get(String path, {Map<String, String>? params}) async { ... }
```

Then update all consumers:
```dart
// Before (fails in royal_client.dart, works in simplex_api_client.dart's inline classes)
_client._get('/api/royal/nodes')

// After (works everywhere)
_client.get('/api/royal/nodes')
```

## Pattern: Missing Model Classes
When the shared api_client exposes typed return values (e.g. `Future<ServiceActionResult>`), the models package needs to define that type. Add:

```dart
/// Doc comment
class ClassName {
  final bool success;
  final String message;
  const ClassName({this.success = false, this.message = ''});
  factory ClassName.fromJson(Map<String, dynamic> json) => ClassName(
    success: json['success'] ?? false,
    message: json['message'] ?? '',
  );
}
```

**Files that need updating:**
1. `apps/shared/models/lib/src/<category>.dart` — Add the class
2. `apps/shared/models/lib/models.dart` — **Verify** it's exported (check `export 'src/<category>.dart';`)
3. Files in `api_client` that reference the type — Add `import 'package:models/models.dart';` if missing

## Common Missing Model Classes from This Session
| Category File | Missing Classes |
|--------------|-----------------|
| `system_status.dart` | SystemStatus, ServiceActionResult, BackupResult, CleanupResult, Config, MaintenanceMode, EmergencyStop, RateLimitStats, ContainerActionResult |
| `treasury.dart` | ReserveState, BurnResult, ProofOfReserve, Rates, Tokenomics, Forecast, Constitution, Proposal, ProposalDraft, VoteResult, DelegationResult |
| `vault.dart` | UploadResult, DeleteResult |
| `token.dart` | TokenBalancesResponse, TokenOperationResult |

## Dart Import Rule
Dart does NOT re-export transitive imports. If `token_client.dart` imports `simplex_api_client.dart` which imports `package:models/models.dart`, that does NOT make models types available to `token_client.dart`. Each file must import what it needs directly:
```dart
// ❌ Wrong — Token type not available even though simplex_api_client imports it
import 'simplex_api_client.dart';

// ✅ Correct — explicit import of the types package
import 'simplex_api_client.dart';
import 'package:models/models.dart';
```