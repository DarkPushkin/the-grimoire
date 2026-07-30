// BIP39 Onboarding Service — Standard Implementation Template
// Copy to apps/isle_app/lib/services/onboarding_service.dart
// Adapt imports/paths for your project structure

import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wallet.dart';

/// Service handling citizen wallet onboarding using standard BIP39/BIP32/BIP44
/// 
/// Flow:
/// 1. Generate 256-bit entropy from OS CSPRNG
/// 2. Encode to 24-word BIP39 mnemonic (English wordlist)
/// 3. Show mnemonic ONCE for paper backup (verify user wrote it down)
/// 4. Optional: User adds passphrase (BIP39 "25th word")
/// 5. Derive seed: PBKDF2-HMAC-SHA512(mnemonic + "mnemonic" + passphrase, 2048 rounds)
/// 6. Derive master key (BIP32) → BIP44 path: m/44'/1337'/0'/0/0 (coin_type=1337 for Isle)
/// 7. Encrypt mnemonic with PIN using SecurePrefs, store encrypted blob
/// 8. Store master public key (watch-only) for balance display without PIN

class OnboardingService {
  static const _storage = FlutterSecureStorage();
  static const _mnemonicKey = 'wallet_mnemonic_encrypted';
  static const _passphraseKey = 'wallet_passphrase_hash'; // SHA256 of passphrase
  static const _masterPubKey = 'wallet_master_pubkey';
  static const _coinType = 1337; // Custom coin type for Isle (register if needed)
  static const _bip44Purpose = 44;
  static const _account = 0;

  /// Generate new wallet — returns mnemonic for ONE-TIME display
  static Future<OnboardingResult> createWallet({
    required String pin,
    String? passphrase, // Optional BIP39 passphrase (25th word)
  }) async {
    // 1. Generate entropy from OS CSPRNG (256 bits = 24 words)
    final entropy = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    
    // 2. Encode to BIP39 mnemonic
    final mnemonic = bip39.mnemonicFromEntropy(entropy);
    
    // 3. Validate (should always pass)
    if (!bip39.validateMnemonic(mnemonic)) {
      throw OnboardingException('Generated invalid mnemonic');
    }

    // 4. Derive seed with passphrase
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase ?? '');
    
    // 5. Derive master key (BIP32)
    final masterKey = bip32.BIP32.fromSeed(seed);
    
    // 6. Derive BIP44 account key: m/44'/1337'/0'
    final accountKey = masterKey.derivePath(
      "m/${_bip44Purpose}'/${_coinType}'/${_account}'",
    );
    
    // 7. Get master public key (for watch-only balance)
    final masterPubKey = accountKey.neutered().publicKeyAsHex;
    
    // 8. Encrypt mnemonic with PIN for storage
    await _storeEncryptedMnemonic(mnemonic, pin);
    
    // 9. Store passphrase hash (for verification on unlock)
    if (passphrase != null && passphrase.isNotEmpty) {
      await _storage.write(key: _passphraseKey, value: _hash(passphrase));
    }
    
    // 10. Store master public key (unencrypted, for balance display)
    await _storage.write(key: _masterPubKey, value: masterPubKey);

    return OnboardingResult(
      mnemonic: mnemonic, // ONLY for immediate display — DO NOT LOG/STORE
      masterPublicKey: masterPubKey,
      coinType: _coinType,
      derivationPath: "m/${_bip44Purpose}'/${_coinType}'/${_account}'",
    );
  }

  /// Unlock existing wallet with PIN (+ optional passphrase)
  static Future<Wallet> unlockWallet({
    required String pin,
    String? passphrase,
  }) async {
    // 1. Decrypt mnemonic
    final mnemonic = await _retrieveDecryptedMnemonic(pin);
    if (mnemonic == null) {
      throw OnboardingException('No wallet found or wrong PIN');
    }

    // 2. Verify passphrase if set
    final storedPassphraseHash = await _storage.read(key: _passphraseKey);
    if (storedPassphraseHash != null) {
      if (passphrase == null || passphrase.isEmpty) {
        throw OnboardingException('Passphrase required');
      }
      if (_hash(passphrase) != storedPassphraseHash) {
        throw OnboardingException('Invalid passphrase');
      }
    } else if (passphrase != null && passphrase.isNotEmpty) {
      throw OnboardingException('No passphrase set for this wallet');
    }

    // 3. Derive seed & keys
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase ?? '');
    final masterKey = bip32.BIP32.fromSeed(seed);
    final accountKey = masterKey.derivePath(
      "m/${_bip44Purpose}'/${_coinType}'/${_account}'",
    );

    // 4. Return wallet with derived keys
    return Wallet(
      mnemonic: mnemonic,
      masterKey: masterKey,
      accountKey: accountKey,
      masterPublicKey: accountKey.neutered().publicKeyAsHex,
      coinType: _coinType,
      derivationPath: "m/${_bip44Purpose}'/${_coinType}'/${_account}'",
    );
  }

  /// Verify user wrote down mnemonic correctly (ask for 3 random words)
  static MnemonicVerificationChallenge createVerificationChallenge(String mnemonic) {
    final words = mnemonic.split(' ');
    if (words.length != 24) throw OnboardingException('Expected 24-word mnemonic');
    
    final random = Random.secure();
    final indices = <int>{};
    while (indices.length < 3) {
      indices.add(random.nextInt(24));
    }
    final sortedIndices = indices.toList()..sort();
    
    return MnemonicVerificationChallenge(
      wordIndices: sortedIndices,
      expectedWords: sortedIndices.map((i) => words[i]).toList(),
    );
  }

  static bool verifyChallenge(MnemonicVerificationChallenge challenge, List<String> userWords) {
    return challenge.expectedWords.length == userWords.length &&
        challenge.expectedWords.asMap().entries.every((e) => e.value == userWords[e.key]);
  }

  /// Check if wallet exists
  static Future<bool> hasWallet() async {
    return await _storage.containsKey(key: _mnemonicKey);
  }

  /// Wipe wallet (emergency reset)
  static Future<void> wipeWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _passphraseKey);
    await _storage.delete(key: _masterPubKey);
  }

  /// Get master public key for watch-only balance (no PIN needed)
  static Future<String?> getMasterPublicKey() async {
    return await _storage.read(key: _masterPubKey);
  }

  // --- Private helpers ---

  static Future<void> _storeEncryptedMnemonic(String mnemonic, String pin) async {
    // Use your existing SecurePrefs pattern (SHA-256 + XOR with device key)
    // Or use flutter_secure_storage directly with PIN as auth
    final encrypted = _encryptWithPin(mnemonic, pin);
    await _storage.write(key: _mnemonicKey, value: encrypted);
  }

  static Future<String?> _retrieveDecryptedMnemonic(String pin) async {
    final encrypted = await _storage.read(key: _mnemonicKey);
    if (encrypted == null) return null;
    return _decryptWithPin(encrypted, pin);
  }

  static String _encryptWithPin(String data, String pin) {
    // Integrate with your SecurePrefs pattern
    // This is a simplified version — use your existing _xorEncrypt/_hash
    final key = _deriveKeyFromPin(pin);
    final bytes = utf8.encode(data);
    final result = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ key[i % key.length]);
    }
    return base64UrlEncode(result);
  }

  static String _decryptWithPin(String encrypted, String pin) {
    final key = _deriveKeyFromPin(pin);
    final bytes = base64Url.decode(encrypted);
    final result = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ key[i % key.length]);
    }
    return utf8.decode(result);
  }

  static List<int> _deriveKeyFromPin(String pin) {
    // Match your SecurePrefs._deviceKey derivation
    // For template: simple SHA256(PIN + salt)
    return sha256.convert(utf8.encode('isle-pin-salt:$pin')).bytes;
  }

  static String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

/// Result of wallet creation — mnemonic ONLY for immediate display
class OnboardingResult {
  final String mnemonic;           // 24 words — show ONCE, then discard
  final String masterPublicKey;    // Hex — store for watch-only
  final int coinType;
  final String derivationPath;

  OnboardingResult({
    required this.mnemonic,
    required this.masterPublicKey,
    required this.coinType,
    required this.derivationPath,
  });
}

/// Challenge for mnemonic backup verification
class MnemonicVerificationChallenge {
  final List<int> wordIndices;    // e.g., [3, 12, 19]
  final List<String> expectedWords;

  MnemonicVerificationChallenge({
    required this.wordIndices,
    required this.expectedWords,
  });
}

/// Custom exception for onboarding errors
class OnboardingException implements Exception {
  final String message;
  OnboardingException(this.message);
  @override String toString() => 'OnboardingException: $message';
}