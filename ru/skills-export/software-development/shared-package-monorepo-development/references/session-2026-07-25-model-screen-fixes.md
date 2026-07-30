# Session 2026-07-25: Model-Screen Fixes for Isle App

## Summary
Fixed all static analysis errors across 11 Isle citizen app screens by aligning models with screen expectations and cleaning up syntax errors.

## Errors Fixed by Screen

### 1. `market_screen.dart`
**Error**: Unused `_createListing` method
**Fix**: Removed dead code method that was never called

### 2. `wallet_screen.dart`
**Errors**: 
- Missing fields on `WalletBalance`: `stakedNg`, `silverNg`, `totalValueUsd`
- Missing `receive()` method on `WalletApi`
- Null safety on `substring()` calls
**Fixes**:
- Added computed getters to `WalletBalance` in `wallet_models.dart`
- Added `receive()` method to `WalletApi` in `simplex_api_client.dart`
- Changed `tx.fromPubkey.substring(0, 12)` to `tx.fromPubkey?.substring(0, 12) ?? '...'`

### 3. `vault_screen.dart`
**Error**: `f.modifiedAt` doesn't exist on `VaultFile`
**Fix**: Changed to `f.createdAt` (model only has `createdAt`)

### 4. `simplex_chat_screen.dart`
**Errors**:
- Missing `intl` import for `DateFormat`
- Syntax: extra `]` in children list
- Non-existent `ChatContactList` widget usage
- `msg.message` field doesn't exist (should be `msg.text`)
**Fixes**:
- Added `import 'package:intl/intl.dart';`
- Removed extra `]`
- Replaced `ChatContactList` with inline `ListView.builder`
- Changed `msg.message` to `msg.text`

### 5. `welcome_screen.dart`
**Errors**:
- Undefined `Platform` (missing `dart:io` import)
- Undefined `http`/`Client` (missing `package:http/http.dart` import)
- `SecurePrefs`/`IdentityService` API mismatch (no unnamed constructor, different method names)
- Duplicate `WelcomeMode` enum definition
- Unused enums: `HandshakeStatus`, `HandshakeStep`, `NodeHealth`
- Unused fields: `_verifyComplete`, `_mnemonicSaved`, `_bgTorOk`, etc.
- Unused `_setStep` method
**Fixes**:
- Added required imports
- Rewrote to use actual `SecurePrefs.instance` (factory) and `SecureIdentityService.instance` APIs
- Removed unused enums and fields
- Cleaned up imports

### 6. `pos_screen.dart`
**Error**: Extra positional argument / missing parenthesis
**Fix**: Fixed nested widget structure

### 7. `royal_screen.dart`
**Warnings only** (no errors):
- Unused `ContainerStatus` import
- Unused local variable `sys`

## Model Files Created/Updated

### `shared/models/lib/src/wallet_models.dart` (NEW)
Complete wallet model definitions:
- `WalletBalance` with `totalNg`, `availableNg`, `reservedNg`, `stakedNg`, `silverNg`, `totalValueUsd`
- `TokenBalance` with `symbol`, `name`, `amountNg`, `decimals`, `usdValue`
- `WalletTransaction` with proper nullable fields and `createdAt`
- `SendRequest`, `ReceiveInfo`, `SwapRequest`, `SwapQuote`, `StakeRequest`, `UnstakeRequest`
- `Banknote`, `BanknoteResult`, `MintResult`, `RedeemResult`, `DividendResult`, `TransferResult`

### `shared/models/lib/src/treasury.dart` (EXTENDED)
Added economy models matching Go backend:
- `OraclePrice`, `DeflationState`, `AutoMintConfig`, `DividendPool`, `DividendHistory`
- `MintResult`, `BurnResult`, `ProofOfReserve`, `ReserveState`, `Tokenomics`, `Forecast`, `Rates`

### `shared/models/lib/src/vault.dart` (REWRITTEN)
- `VaultFile` with `id`, `name`, `size`, `mimeType`, `hash`, `createdAt`, `updatedAt`, `encrypted`, `isEncrypted`, `path`
- `VaultListing` with `files`, `usedBytes`, `quotaBytes`, `updatedAt`

### `shared/models/lib/src/market_item.dart` (EXTENDED)
- `MarketListing` with fields matching both screen expectations and API response
- `MarketOrder` with `id`, `listingId`, `buyer`, `seller`, `amountNg`, `status`, `createdAt`

### `shared/models/lib/models.dart` (UPDATED)
Exports all new model files

## API Client Updates

### `shared/api_client/lib/src/simplex_api_client.dart`
- Added `Future<ReceiveInfo> receive({required String pubkey})` to `WalletApi`
- Fixed `claimDividend` return type handling

## Verification Commands Used

```bash
# Per-screen analysis (fast, ~2s each)
dart analyze apps/isle_app/lib/screens/market_screen.dart
dart analyze apps/isle_app/lib/screens/wallet_screen.dart
dart analyze apps/isle_app/lib/screens/vault_screen.dart
dart analyze apps/isle_app/lib/screens/simplex_chat_screen.dart
dart analyze apps/isle_app/lib/screens/welcome_screen.dart
dart analyze apps/isle_app/lib/screens/pos_screen.dart
dart analyze apps/isle_app/lib/screens/royal_screen.dart

# Full screens directory
dart analyze apps/isle_app/lib/screens/

# Model package
dart analyze apps/shared/models/lib/src/
```

## Key Pattern: Model-First Development
When screens reference fields that don't exist on models:
1. **Add to model** (computed getters or actual fields) - preferred for backward compatibility
2. **Update screen** to use actual model fields - when model structure changed significantly
3. **Add missing API methods** to `SimplexApiClient` sub-clients

## Remaining Warnings (Non-Blocking)
- Unused imports/fields/variables
- `prefer_const_constructors`, `deprecated_member_use` style hints
- `use_build_context_synchronously` hints (need mounted checks)

These don't block compilation or execution.