# ed25519_hd_key 2.3.0 API Reference (from pub cache)

## Key Classes

### ED25519_HD_KEY (singleton)
```dart
const ED25519_HD_KEY = _ED25519HD();

class _ED25519HD {
  // Derive child key from path
  Future<KeyData> derivePath(String path, List<int> seedBytes, {int offset = HARDENED_OFFSET})
  
  // Get master key from seed
  Future<KeyData> getMasterKeyFromSeed(List<int> seedBytes, {String masterSecret = ED25519_CURVE})
  
  // Get public key from private key
  Future<List<int>> getPublicKey(List<int> privateKey, [bool withZeroByte = true])
  
  // Child key derivation (private)
  Future<KeyData> _getCKDPriv(KeyData data, int index)
}
```

### KeyData
```dart
class KeyData {
  final List<int> key;        // Private key bytes (32 bytes)
  final List<int> chainCode;  // Chain code (32 bytes)
  
  const KeyData({required this.key, required this.chainCode});
}
```
**Important:** `KeyData` has NO `.publicKey` getter. Use pinenacl to derive public key.

### Constants
```dart
const String ED25519_CURVE = 'ed25519 seed';
const int HARDENED_OFFSET = 0x80000000;
```

## Usage Patterns

### Derive Key from Seed with BIP44 Path
```dart
import 'package:ed25519_hd_key/ed25519_hd_key.dart' as ed25519_hd_key;
import 'package:pinenacl/ed25519.dart' as pinenacl;

final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
final keyData = await ed25519_hd_key.ED25519_HD_KEY.derivePath(
  "m/44'/1337'/0'/0/0",  // BIP44 path for SMP (coin type 1337)
  seed,
);

// keyData.key is List<int> (private key)
final privateKey = Uint8List.fromList(keyData.key);

// Derive public key via pinenacl
final signingKey = pinenacl.SigningKey.fromSeed(privateKey);
final publicKey = await signingKey.publicKey;  // Uint8List(32)
```

### Verify Mnemonic Matches Public Key
```dart
final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
final keyData = await ed25519_hd_key.ED25519_HD_KEY.derivePath(path, seed);
final signingKey = pinenacl.SigningKey.fromSeed(Uint8List.fromList(keyData.key));
final derivedPubKey = await signingKey.publicKey;
final derivedPubKeyHex = hex.encode(derivedPubKey);
return derivedPubKeyHex == storedPubKeyHex;
```

## Breaking Changes from 1.x

| 1.x API | 2.3.0 API |
|---------|-----------|
| `Ed25519HdKey.fromSeed(seed)` | `ED25519_HD_KEY.derivePath(path, seed)` |
| `key.derive(path)` | `ED25519_HD_KEY.derivePath(path, seed)` |
| `key.publicKey` | N/A - use pinenacl |
| `key.key` (Uint8List) | `KeyData.key` (List<int>) |

## Integration with pinenacl

```dart
import 'package:pinenacl/ed25519.dart' as pinenacl;

// Sign
final signingKey = pinenacl.SigningKey.fromSeed(privateKey);  // Uint8List(32)
final signed = signingKey.sign(message);  // SignedMessage
final signature = signed.signature.asTypedList;  // Uint8List(64)

// Verify
final verifyKey = pinenacl.VerifyKey(publicKey);  // Uint8List(32)
final sig = pinenacl.Signature(signatureBytes);   // Uint8List(64)
final valid = verifyKey.verify(signature: sig, message: message);
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Method not found: 'fromSeed'` | Using old API | Use `ED25519_HD_KEY.derivePath()` |
| `Getter 'publicKey' not found` | KeyData has no publicKey | Use pinenacl to derive |
| `List<int> not assignable to Uint8List` | keyData.key is List<int> | Wrap: `Uint8List.fromList(keyData.key)` |
| `The argument type 'List<int>' can't be assigned to 'Uint8List'` | Same as above | Same fix |