// BIP39/Ed25519 Key Derivation Templates
// Copy and modify for your project

// ============================================================
// 1. DERIVATION PATHS (All hardened for Ed25519)
// ============================================================
class DerivationPaths {
  // Coin type 1337 (SMP - SimpleX Messenger Protocol)
  // All levels hardened per SLIP-0010 (Ed25519 doesn't support public derivation)
  
  static const String identity = "m/44'/1337'/0'/0'/0'";      // Ed25519 signing
  static const String encryption = "m/44'/1337'/0'/1'/0'";    // X25519 encryption
  static const String auth = "m/44'/1337'/0'/2'/0'";          // Future: Ed25519 auth
  static const String storage = "m/44'/1337'/0'/3'/0'";       // Future: Encrypted storage
}

// ============================================================
// 2. MNEMONIC GENERATION
// ============================================================
import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart' show hex;
import 'dart:math';

Uint8List _generateEntropy(int bytes) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(bytes, (_) => random.nextInt(256)));
}

String generateMnemonic({int wordCount = 24}) {
  final entropyBytes = _generateEntropy(wordCount * 11 / 8 ~/ 1); // 32 bytes for 24 words
  return bip39.entropyToMnemonic(hex.encode(entropyBytes));
}

bool validateMnemonic(String mnemonic) {
  return bip39.validateMnemonic(mnemonic.trim());
}

Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) {
  return bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
}

// ============================================================
// 3. ED25519 KEY DERIVATION
// ============================================================
import 'package:ed25519_hd_key/ed25519_hd_key.dart' as ed25519_hd_key;
import 'package:pinenacl/ed25519.dart' as pinenacl_ed25519;

Future<KeyPair> deriveIdentityKey(Uint8List seed) async {
  final edKey = await ed25519_hd_key.ED25519_HD_KEY.derivePath(
    DerivationPaths.identity,
    seed,
  );
  
  final signingKey = await pinenacl_ed25519.SigningKey.fromSeed(
    Uint8List.fromList(edKey.key)
  );
  final publicKey = await signingKey.publicKey;
  
  return KeyPair(
    privateKey: Uint8List.fromList(edKey.key),
    publicKey: publicKey.asTypedList,
  );
}

Future<EncryptionKeyPair> deriveEncryptionKey(Uint8List seed) async {
  final encKey = await ed25519_hd_key.ED25519_HD_KEY.derivePath(
    DerivationPaths.encryption,
    seed,
  );
  
  final signingKey = await pinenacl_ed25519.SigningKey.fromSeed(
    Uint8List.fromList(encKey.key)
  );
  final publicKey = await signingKey.publicKey;
  
  return EncryptionKeyPair(
    privateKey: Uint8List.fromList(encKey.key),
    publicKey: publicKey.asTypedList,
  );
}

// ============================================================
// 4. CHACHA20-POLY1305 ENCRYPTION (pointycastle 3.8+)
// ============================================================
import 'package:pointycastle/api.dart' as pc_api;

Future<String> encryptMnemonic(String mnemonic, Uint8List key) async {
  final nonce = _generateNonce(12);
  
  final cipher = pc_api.AEADCipher('ChaCha20-Poly1305');
  final params = pc_api.AEADParameters(
    pc_api.KeyParameter(key),
    128,  // MAC size in bits
    nonce,
    Uint8List(0),  // associated data
  );
  cipher.init(true, params);
  
  final plaintext = utf8.encode(mnemonic);
  final ciphertext = Uint8List(cipher.getOutputSize(plaintext.length));
  final len = cipher.processBytes(plaintext, 0, plaintext.length, ciphertext, 0);
  cipher.doFinal(ciphertext, len);
  
  // Combine nonce + ciphertext for storage
  final combined = Uint8List(nonce.length + ciphertext.length);
  combined.setAll(0, nonce);
  combined.setAll(nonce.length, ciphertext);
  
  return base64.encode(combined);
}

Future<String?> decryptMnemonic(String encryptedB64, Uint8List key) async {
  try {
    final combined = base64.decode(encryptedB64);
    if (combined.length < 12) return null;
    
    final nonce = combined.sublist(0, 12);
    final ciphertext = combined.sublist(12);
    
    final cipher = pc_api.AEADCipher('ChaCha20-Poly1305');
    final params = pc_api.AEADParameters(
      pc_api.KeyParameter(key),
      128,
      nonce,
      Uint8List(0),
    );
    cipher.init(false, params);
    
    final plaintext = Uint8List(cipher.getOutputSize(ciphertext.length));
    final len = cipher.processBytes(ciphertext, 0, ciphertext.length, plaintext, 0);
    cipher.doFinal(plaintext, len);
    
    return utf8.decode(plaintext.sublist(0, len));
  } catch (_) {
    return null;
  }
}

Uint8List _generateNonce(int bytes) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(bytes, (_) => random.nextInt(256)));
}

// ============================================================
// 5. PBKDF2 PIN HASHING
// ============================================================
import 'package:crypto/crypto.dart';

Future<String> hashPin(String pin, {Uint8List? salt, int iterations = 100000}) async {
  final saltBytes = salt ?? Uint8List(32); // Use device key as salt
  final pbkdf2 = PBKDF2(
    mac: Hmac(sha256, saltBytes),
    iterations: iterations,
    bits: 256,
  );
  final hash = pbkdf2.generate(utf8.encode(pin));
  return base64.encode(hash);
}

Future<bool> verifyPin(String pin, String storedHash) async {
  final computed = await hashPin(pin);
  return computed == storedHash;
}

// ============================================================
// 6. SUPPORTING CLASSES
// ============================================================
class KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;
  
  const KeyPair({required this.privateKey, required this.publicKey});
  
  String get privateKeyHex => hex.encode(privateKey);
  String get publicKeyHex => hex.encode(publicKey);
}

class EncryptionKeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;
  
  const EncryptionKeyPair({required this.privateKey, required this.publicKey});
  
  String get privateKeyHex => hex.encode(privateKey);
  String get publicKeyHex => hex.encode(publicKey);
}

class Identity {
  final String id;
  final String encryptedMnemonic;
  final String derivationPath;
  final String ed25519PubKey;
  final String x25519PubKey;
  final int createdAt;
  final String? label;
  
  const Identity({
    required this.id,
    required this.encryptedMnemonic,
    required this.derivationPath,
    required this.ed25519PubKey,
    required this.x25519PubKey,
    required this.createdAt,
    this.label,
  });
  
  String get shortId => id.substring(0, 8);
  String get displayName => label ?? 'Identity $shortId';
}