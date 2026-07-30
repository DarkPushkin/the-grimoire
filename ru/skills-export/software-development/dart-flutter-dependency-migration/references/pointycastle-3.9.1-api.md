# pointycastle 3.9.1 API Reference (from pub cache)

## Key Classes and Changes

### AEADCipher
```dart
// Factory constructor - REQUIRES algorithm name
factory AEADCipher(String algorithmName)
```
Usage: `final cipher = pc_api.AEADCipher('ChaCha20-Poly1305');`

### AEADParameters
```dart
class AEADParameters implements CipherParameters {
  final CipherParameters key;      // KeyParameter
  final int macSize;               // in bits (e.g., 128)
  final Uint8List nonce;           // IV/nonce
  final Uint8List associatedData;  // REQUIRED - use Uint8List(0) for empty
}
```

### KeyParameter
```dart
// In package:pointycastle/api.dart
class KeyParameter implements CipherParameters {
  final Uint8List key;
  const KeyParameter(this.key);
}
```
Import: `import 'package:pointycastle/api.dart' as pc_api;`
Usage: `pc_api.KeyParameter(keyBytes)`

### CipherParameters (base)
```dart
abstract class CipherParameters {}
```

### AEADCipher Methods
```dart
void init(bool forEncryption, CipherParameters params);
int getOutputSize(int inputLength);
int processBytes(Uint8List input, int inOff, int len, Uint8List out, int outOff);
void doFinal(Uint8List out, int outOff);
```

## Migration from Old API

| Old (pre-3.x) | New (3.9.1) |
|---------------|-------------|
| `ChaCha20Poly1305Engine()` | `pc_api.AEADCipher('ChaCha20-Poly1305')` |
| `AeadParameters(key, macSize, nonce)` | `pc_api.AEADParameters(key, macSize, nonce, associatedData)` |
| `KeyParameter(key)` | `pc_api.KeyParameter(key)` |
| `cipher.init(false, params)` | Same |
| `cipher.doFinal(out, len)` | Same |

## Example: ChaCha20-Poly1305 Decryption
```dart
import 'package:pointycastle/api.dart' as pc_api;

final cipher = pc_api.AEADCipher('ChaCha20-Poly1305');
final params = pc_api.AEADParameters(
  pc_api.KeyParameter(key),
  128,                    // MAC size in bits
  nonce,                  // Uint8List(12)
  Uint8List(0),           // associatedData - empty
);
cipher.init(false, params);

final plaintext = Uint8List(cipher.getOutputSize(ciphertext.length));
final len = cipher.processBytes(ciphertext, 0, ciphertext.length, plaintext, 0);
cipher.doFinal(plaintext, len);
return plaintext.sublist(0, len);
```