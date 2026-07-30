# Derivation Path Fix for "invalid number" Error

## Problem
Seed recovery failed with "invalid number" error even with correct mnemonic phrase.

## Root Cause
The `ed25519_hd_key` library's `derivePath()` method cannot parse non-hardened path segments (segments without `'`).

### Broken Path (Standard BIP44):
```
m/44'/1337'/0'/0/0
```
The last two segments (`0` and `0`) are non-hardened. The parser calls:
```dart
int.parse(segment.substring(0, segment.length - 1))
```
For non-hardened `0`, this becomes `int.parse("")` → "invalid number" ArgumentError.

## Solution
Make ALL derivation path segments hardened for Ed25519 (since Ed25519 doesn't support public derivation per SLIP-0010).

### Fixed Paths:
```dart
class DerivationPaths {
  static const String identity = "m/44'/1337'/0'/0'/0'";      // All 5 levels hardened
  static const String encryption = "m/44'/1337'/0'/1'/0'";    // All 5 levels hardened
  static const String auth = "m/44'/1337'/0'/2'/0'";          // All 5 levels hardened
  static const String storage = "m/44'/1337'/0'/3'/0'";       // All 5 levels hardened
}
```

## Files Changed
- `/home/tomas/simplex-node/apps/shared/models/lib/src/identity.dart` - Updated `DerivationPaths` class constants

## Verification
- Build: `flutter build linux --release` ✅
- Seed recovery flow now works with correct mnemonic ✅
- No more "invalid number" error ✅