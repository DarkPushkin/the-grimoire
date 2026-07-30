---
name: dart-flutter-dependency-migration
description: Fix Flutter/Dart build breaks from package API changes.
trigger: Flutter/Dart build fails due to dependency version conflicts or deprecated APIs.
---

# Dart/Flutter Dependency Migration Patterns

## Common Package Migrations

### pointycastle 3.x → 3.9.1
- `AEADCipher()` → `AEADCipher('ChaCha20-Poly1305')`
- `AeadParameters` → `AEADParameters`
- `KeyParameter` → import from `package:pointycastle/api.dart` as `pc_api.KeyParameter`
- `ChaCha20Poly1305Engine` removed; use `AEADCipher('ChaCha20-Poly1305')`
- `AEADParameters` requires `associatedData` (use `Uint8List(0)`)

### bip39 1.x
- `entropyToMnemonic(Uint8List)` → `entropyToMnemonic(String)` — pass hex: `hex.encode(entropyBytes)`

### bip32 2.x (not 3.x)
- Use `bip32: ^2.0.0` — 3.x may not exist on pub.dev
- For Ed25519, prefer `ed25519_hd_key` package

### ed25519_hd_key 2.3.0
- `Ed25519HdKey.fromSeed(seed)` removed
- Use `ED25519_HD_KEY.derivePath(path, seed)` → returns `KeyData { key, chainCode }`
- `KeyData` has `.key` (private, `List<int>`) but NO `.publicKey`
- Derive public key via pinenacl:
  ```dart
  import 'package:pinenacl/ed25519.dart' as pinenacl;
  final signingKey = pinenacl.SigningKey.fromSeed(Uint8List.fromList(keyData.key));
  final publicKey = await signingKey.publicKey;
  ```

### pinenacl 0.6.0
- `SigningKey.fromSeed(Uint8List).sign(message)` → `SignedMessage { signature, message }`
- `VerifyKey(Uint8List).verify(signature: Signature, message: Uint8List)` → bool
- `Signature(Uint8List)` wraps signature bytes

### convert 3.x
- `hex.encode(List<int>)` / `hex.decode(String)` via `import 'package:convert/convert.dart' as hex;`

## Migration Workflow

1. Run `flutter pub get` and `flutter build` — collect errors
2. Check pub cache: `~/.pub-cache/hosted/pub.dev/<package>-<version>/lib/`
3. Fix imports first, then API calls
4. Test with `flutter analyze` then `flutter build`

## Pitfalls

- ❌ Don't assume `^3.0.0` exists — check pub.dev versions
- ❌ `KeyData.key` is `List<int>`, wrap: `Uint8List.fromList()`
- ❌ `AEADCipher` factory requires algorithm string
- ❌ `AEADParameters` requires `associatedData` param

## Verification

```bash
flutter pub deps --style=compact | grep -E "(pointycastle|bip39|bip32|ed25519_hd_key|pinenacl|convert)"
flutter analyze --no-fatal-infos 2>&1 | head -50
```

## References
- `references/pointycastle-3.9.1-api.md`
- `references/ed25519_hd_key-2.3.0-api.md`
- `references/bip39-1.0.6-api.md`