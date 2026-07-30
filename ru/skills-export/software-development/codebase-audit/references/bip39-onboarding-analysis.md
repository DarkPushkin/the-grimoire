# BIP39 Onboarding — Security Analysis & Recommendations

**Context:** Saint Mary Liberty Island / Isle App citizen onboarding  
**Date:** 2026-07-26  
**User Proposal:** "Use current date + 5 user-chosen words, hash 100,000 times, use as entropy"

---

## Why the Proposed Approach is Insecure

| Component | User Proposal | Security Problem |
|-----------|---------------|------------------|
| **Date** | Current date (YYYY-MM-DD) | Public knowledge = 0 bits entropy |
| **5 Words** | User-chosen, lowercase, ≤16 chars | Human selection bias → ~4-6 bits/word vs 11 bits (random from 2048) |
| **Hash Iterations** | 100,000× SHA-256 | Non-standard KDF; PBKDF2-HMAC-SHA512 with 2048 rounds is standard |
| **Output** | Raw hash as entropy | Not a valid BIP39 mnemonic; no checksum; no interoperability |

**Total Entropy Estimate:** 20-30 bits → **Crackable in seconds on GPU**

---

## How Real Crypto Projects Do It

| Project | Entropy Source | Mnemonic | KDF | Derivation |
|---------|----------------|----------|-----|------------|
| **Bitcoin Core** | OS CSPRNG | BIP39 (12/24 words) | PBKDF2-SHA512×2048 | BIP32/BIP44 |
| **Electrum** | OS CSPRNG | BIP39 (12 words) | PBKDF2-SHA512×2048 | BIP32/BIP44 |
| **Metamask** | OS CSPRNG | BIP39 (12 words) | PBKDF2-SHA512×2048 | BIP44 (coin 60) |
| **Monero (mymonero)** | OS CSPRNG | 25-word (custom) | PBKDF2-SHA512×2048 | Ed25519 |
| **Solana (Phantom)** | OS CSPRNG | BIP39 (12/24 words) | PBKDF2-SHA512×2048 | BIP44 (coin 501) |
| **Signal/Session** | OS CSPRNG | N/A (X3DH) | HKDF-SHA256 | Double Ratchet |

**Universal Principles:**
1. **Entropy from CSPRNG only** — Never user input
2. **Standard wordlists** — BIP39 English (2048 words) for compatibility
3. **Standard KDF** — PBKDF2-HMAC-SHA512, 2048+ rounds
4. **Standard derivation** — BIP32/BIP44 (or SLIP-10 for Ed25519)
5. **Optional passphrase** — BIP39 "25th word" for plausible deniability

---

## Recommended Isle App Onboarding Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. WELCOME → "Create New Wallet" or "Restore from Paper"       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌────────────────────────┐        ┌────────────────────────┐
│ 2a. GENERATE           │        │ 2b. RESTORE            │
│ - OS CSPRNG → 256 bits │        │ - User enters 12/24    │
│ - BIP39 → 24 words     │        │   words + optional     │
│ - SHOW ONCE            │        │   passphrase           │
│ - User writes on paper │        │ - Validate checksum    │
└───────────┬────────────┘        └───────────┬────────────┘
            │                                 │
            └──────────────┬──────────────────┘
                           ▼
              ┌────────────────────────┐
              │ 3. VERIFY BACKUP       │
              │ "Enter word #3, #12,   │
              │  #19 to confirm"       │
              └───────────┬────────────┘
                          ▼
              ┌────────────────────────┐
              │ 4. SET PIN             │
              │ - 6-digit PIN          │
              │ - Encrypts mnemonic    │
              │ - SecurePrefs (XOR)    │
              └───────────┬────────────┘
                          ▼
              ┌────────────────────────┐
              │ 5. MAIN APP UNLOCKED   │
              │ - Derive Ed25519 keys  │
              │ - Connect to node      │
              └────────────────────────┘
```

---

## Dependencies to Add

```yaml
# apps/isle_app/pubspec.yaml
dependencies:
  bip39: ^1.0.6      # Mnemonic generation/validation
  bip32: ^2.0.0      # HD key derivation (BIP32/BIP44)
  # Existing:
  shared_preferences: ^2.2.0
  crypto: ^3.0.3
```

---

## Integration with Existing `SecurePrefs`

Your `SecurePrefs` already does:
- ✅ Device-bound key (machine-id + uid)
- ✅ SHA-256(PIN + deviceKey) for PIN verification
- ✅ XOR encryption for reversible storage (mnemonic)

**Use it exactly as-is:**
```dart
// Store mnemonic (reversible)
await SecurePrefs.instance.setString('wallet_mnemonic', mnemonic);

// Later: decrypt with PIN
final mnemonic = await SecurePrefs.instance.getString('wallet_mnemonic');
```

**Add:** `bip39` + `bip32` packages for standard key derivation.

---

## Coin Type Registration

For Saint Mary Liberty Island sovereign currency:
- **BIP44 Coin Type:** Request allocation at https://github.com/satoshilabs/slips/blob/master/slip-0044.md
- **Suggested:** `1337` (unassigned, memorable) or `0` (generic) with custom path `m/44'/1337'/0'/0/0`
- **Derivation:** `m/44'/coin'/account'/change/index`

---

## Files to Modify

| File | Change |
|------|--------|
| `apps/isle_app/pubspec.yaml` | Add `bip39`, `bip32` deps |
| `apps/isle_app/lib/services/secure_prefs.dart` | No change needed |
| `apps/isle_app/lib/screens/welcome_screen.dart` | Replace PIN+custom seed with BIP39 flow |
| `apps/isle_app/lib/services/onboarding_service.dart` | **NEW** — encapsulate logic (see template) |
| `apps/isle_app/lib/main.dart` | Initialize onboarding on startup |

---

## Testing Checklist

- [ ] Generate mnemonic → verify 24 words, valid checksum
- [ ] Restore from mnemonic → same master key
- [ ] Passphrase changes seed → different keys (plausible deniability)
- [ ] PIN encrypts/decrypts mnemonic correctly
- [ ] Wipe wallet removes all traces
- [ ] Wrong PIN rejects after 3 attempts (30s lockout)
- [ ] Backup verification catches typos

---

## Template Reference

See `templates/bip39-onboarding.dart` for complete implementation.