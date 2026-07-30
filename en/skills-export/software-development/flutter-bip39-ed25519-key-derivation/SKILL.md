---
name: flutter-bip39-ed25519-key-derivation
description: Use for BIP39 Ed25519 key derivation in Flutter.
trigger: Working with BIP39 mnemonics, Ed25519 HD key derivation, or encrypted mnemonic storage in Flutter/Dart.
---

# Flutter/Dart BIP39/BIP44 Ed25519 Key Derivation

## Overview
Patterns, pitfalls, and working implementations for BIP39 mnemonic generation, BIP32/BIP44 Ed25519 hierarchical deterministic key derivation, and encrypted mnemonic storage in Flutter/Dart. Based on simplex-node project's `shared/models` package.

## Key Libraries & Versions (Known Working)

| Package | Version | Purpose |
|---------|---------|---------|
| `bip39` | ^1.0.6 | Mnemonic generation, validation, seed derivation |
| `bip32` | ^2.0.0 | BIP32 key derivation (downgraded from ^3.0.0) |
| `ed25519_hd_key` | ^2.3.0 | Ed25519 HD key derivation (SLIP-0010) |
| `pinenacl` | ^0.6.0 | Ed25519 signing/verification, X25519 key agreement |
| `pointycastle` | ^3.8.0 | AEAD encryption (ChaCha20-Poly1305) |
| `convert` | ^3.1.1 | Hex encoding/decoding |

## Critical Pitfall: ed25519_hd_key Requires Fully Hardened Paths

**The library's `derivePath()` method CANNOT parse non-hardened path segments.**

### Broken (causes "invalid number" error):
```dart
static const String identity = "m/44'/1337'/0'/0/0";  // Last two '0' are non-hardened
```

### Fixed (all segments hardened):
```dart
static const String identity = "m/44'/1337'/0'/0'/0'";  // All 5 levels hardened
static const String encryption = "m/44'/1337'/0'/1'/0'";
```

**Why:** Parser splits on `/`, calls `int.parse(segment.substring(0, segment.length - 1))` for hardened segments. Non-hardened segments (no `'`) produce empty strings -> `int.parse("")` -> "invalid number" ArgumentError.

**Impact:** Seed recovery fails with "invalid number" error even with correct mnemonic.

## Derivation Paths for SMP (Coin Type 1337)

```dart
class DerivationPaths {
  static const String identity = "m/44'/1337'/0'/0'/0'";
  static const String encryption = "m/44'/1337'/0'/1'/0'";
  static const String auth = "m/44'/1337'/0'/2'/0'";
  static const String storage = "m/44'/1337'/0'/3'/0'";
}
```

## Mnemonic Generation & Verification

```dart
import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart' show hex;

final entropyBytes = _generateEntropy(32);
final mnemonic = bip39.entropyToMnemonic(hex.encode(entropyBytes));

if (!bip39.validateMnemonic(mnemonic)) {
  throw ArgumentError('Invalid BIP39 mnemonic');
}

final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
```

### 3-Word Verification Challenge

```dart
final verifyIndices = List.generate(3, (_) => random.nextInt(24)).toSet().toList();
verifyIndices.sort();
final verifyWords = verifyIndices.map((i) => mnemonicWords[i]).toList();
// User enters these 3 words - compare case-insensitive
```

## Ed25519 Key Derivation with ed25519_hd_key

```dart
import 'package:ed25519_hd_key/ed25519_hd_key.dart' as ed25519_hd_key;
import 'package:pinenacl/ed25519.dart' as pinenacl_ed25519;

final edKey = await ed25519_hd_key.ED25519_HD_KEY.derivePath(
  DerivationPaths.identity, 
  seed
);

final signingKey = await pinenacl_ed25519.SigningKey.fromSeed(
  Uint8List.fromList(edKey.key)
);
final publicKey = await signingKey.publicKey;
final publicKeyHex = hex.encode(publicKey);
```

### KeyData Structure (v2.3.0)

```dart
class KeyData {
  final List<int> key;       // 32-byte private key
  final List<int> chainCode; // 32-byte chain code
}
```

## ChaCha20-Poly1305 Encryption (pointycastle v3.8+)

```dart
import 'package:pointycastle/api.dart' as pc_api;

final cipher = pc_api.AEADCipher('ChaCha20-Poly1305');
final params = pc_api.AEADParameters(
  pc_api.KeyParameter(key),
  128,
  nonce,
  Uint8List(0),
);
cipher.init(true, params);

final plaintext = utf8.encode(mnemonic);
final ciphertext = Uint8List(cipher.getOutputSize(plaintext.length));
final len = cipher.processBytes(plaintext, 0, plaintext.length, ciphertext, 0);
cipher.doFinal(ciphertext, len);

// Store: nonce (12 bytes) + ciphertext
final combined = Uint8List(nonce.length + ciphertext.length);
combined.setAll(0, nonce);
combined.setAll(nonce.length, ciphertext);
return base64.encode(combined);
```

**Note:** pointycastle 3.9+ uses `pc_api.AEADCipher`, `pc_api.AEADParameters`, `pc_api.KeyParameter`.

## PIN-Based Identity Encryption

```dart
final combinedKey = _deviceKey + pin;
final hash = sha256.convert(utf8.encode(combinedKey));
final key = Uint8List.fromList(hash.bytes);
```

## PBKDF2 PIN Hashing (for storage)

```dart
Future<String> hashPin(String pin) async {
  const iterations = 100000;
  const keyLength = 32;
  
  final pbkdf2 = PBKDF2(
    mac: Hmac(sha256, Uint8List(32)),
    iterations: iterations,
    bits: keyLength * 8,
  );
  
  final hash = pbkdf2.generate(utf8.encode(pin));
  return base64.encode(hash);
}

Future<bool> verifyPin(String pin, String storedHash) async {
  final computed = await hashPin(pin);
  return computed == storedHash;
}
```

## Identity Service Pattern (Singleton)

```dart
class SecureIdentityService {
  static Future<SecureIdentityService> get instance async {
    _instance ??= SecureIdentityService._();
    await _instance!._init();
    return _instance!;
  }
  
  // Methods:
  // - generateIdentity({label?, passphrase?}) -> Identity
  // - createIdentityFromMnemonic({mnemonic, passphrase?, label?}) -> Identity
  // - decryptIdentity(encryptedB64, pin) -> Identity
  // - encryptIdentity({mnemonic, pin}) -> encryptedB64
  // - hashPin(pin) -> pinHash
  // - verifyPin(pin, pinHash) -> bool
  // - exportMnemonic(identityId, passphrase) -> mnemonic
}
```

## Profile Storage (SharedPreferences)

```dart
// 'profile_ids' -> List<String>
// 'active_profile' -> String
// '${profileId}_name' -> String
// '${profileId}_encrypted' -> String (base64 encrypted mnemonic)
// '${profileId}_pin_hash' -> String (base64 PBKDF2 hash)
// '${profileId}_created' -> String (ISO8601)
// '${profileId}_panic_mode' -> bool
```

## Panic Mode

- Sets `${profileId}_panic_mode = true`
- Lock screen hides PIN field, shows "PANIC MODE - Seed recovery required"
- Only seed recovery can reset panic mode
- Exponential backoff still applies to seed recovery attempts

## Exponential Backoff (PIN Errors)

```dart
int _calculateLockoutDuration(int errorCount) {
  return 30 * (1 << (errorCount - 1));  // 30 * 2^(n-1) seconds
}
```

## Build & Deploy Commands

```bash
cd apps/royal_app
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
  flutter build linux --release

cp build/linux/x64/release/bundle/royal_app ~/.local/bin/the-royal/royal_app
cp -r build/linux/x64/release/bundle/lib/* ~/.local/bin/the-royal/lib/
cp -r build/linux/x64/release/bundle/data/* ~/.local/bin/the-royal/data/
```

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "invalid number" in derivePath | Non-hardened path segments | Make ALL segments hardened (`'`) |
| "Invalid BIP39 mnemonic" | Wrong wordlist, extra spaces, wrong count | `mnemonic.trim().split(RegExp(r'\s+'))` -> validate count |
| pointycastle AEAD init fails | Wrong parameter types | Use `pc_api.KeyParameter`, `pc_api.AEADParameters` with `macSize=128` |
| bip32 ^3.0.0 resolution fails | API breaking changes | Downgrade to `bip32: ^2.0.0` |
| ChaCha20Poly1305 not found | Import path changed | Use `pc_api.AEADCipher('ChaCha20-Poly1305')` |

## References

- SLIP-0010: Universal private key derivation for ed25519
- BIP39: Mnemonic code for generating deterministic keys
- BIP44: Multi-account hierarchy for deterministic wallets