# Isle App Audit Reference — 2026-07-26

**Project:** Saint Mary Liberty Island / simplex-node  
**App:** isle_app (Citizen Client — "The Isle")  
**Date:** 2026-07-26  
**Auditor:** Hermes Agent using codebase-audit skill

---

## App Role & Architecture

| App | Role | User | Backend |
|-----|------|------|---------|
| **royal_app** | Admin/Backend Office | King/Operators | simplex-node:8080 |
| **isle_app** | Citizen Client | Island residents | simplex-node:8080 (same) |

Both apps share the **same Go backend** (simplex-node on 127.0.0.1:8080 or onion). They use different API endpoints/permissions.

---

## Key Findings Summary

| Severity | Count | Critical Items |
|----------|-------|----------------|
| 🔴 CRITICAL | 1 | Plaintext HTTP to sovereign backend (same as royal_app) |
| 🟠 HIGH | 4 | 4× `use_build_context_synchronously` in simplex_chat_screen, welcome_screen |
| 🟡 MEDIUM | 8 | Shared package divergence, silent error catches, deprecated APIs |
| 🟢 LOW | 227 | Lint warnings (const, braces, deprecations, unused) |

**Total: 240 issues** (`flutter analyze --no-pub`)

---

## Critical Security Gaps (Same as royal_app)

### 1. Plaintext HTTP Transport
**Files:** `lib/services/isle_api_service.dart`, `lib/services/tor_aware_client.dart`
```dart
static const String defaultBaseUrl = 'http://127.0.0.1:8080';
```
All citizen operations (wallet, chat, market, vault, POS) transmitted in cleartext.

### 2. Zero Authentication on API Calls
No `Authorization` headers, no token storage, no cert pinning.

---

## High-Risk Code Patterns

### 3. Async BuildContext Usage (4 locations)
| File | Line | Context |
|------|------|---------|
| `simplex_chat_screen.dart` | 2095 | `Navigator.pop(ctx)` after `await` |
| `simplex_chat_screen.dart` | 2130 | `setState` after `await` |
| `simplex_chat_screen.dart` | 2988 | `Navigator.pop(ctx)` after `await` |
| `simplex_chat_screen.dart` | 3021 | `Navigator.pop(ctx)` after `await` |
| `welcome_screen.dart` | 396 | `ScaffoldMessenger.of(context)` after `await` |

**Fix:** Capture `mounted` or `navigator`/`messenger` before `await`.

### 4. Silent Error Swallowing (Multiple)
```dart
// simplex_chat_screen.dart:2990-2992
} catch (_) {
  setState(() => _stewardThinking = 'AI request failed');
}

// simplex_chat_screen.dart:3020
} catch (_) {}
```

**Fix:** Show user-visible error, log structured.

### 5. Deprecated API Usage
- `textScaleFactor` → `textScaler` (dashboard_screen.dart:83)
- `surfaceVariant` → `surfaceContainerHighest` (market_screen.dart:455, 480)
- `withOpacity` → `withValues` (royal_screen.dart:258)
- `groupValue`/`onChanged` on Radio → `RadioGroup` (relay_selector_dialog.dart:90-91)
- `activeColor` → `activeThumbColor` (paranoidx_screen.dart:461)

---

## Medium: Shared Package Divergence

### isle_app USES shared packages ✅ (royal_app does NOT)
```yaml
# isle_app/pubspec.yaml
dependencies:
  api_client: { path: ../shared/api_client }
  models: { path: ../shared/models }
  widgets: { path: ../shared/widgets }
```

| Package | Used by isle_app? | Purpose |
|---------|-------------------|---------|
| `api_client` | ✅ | `RoyalClient`, `SimplexNodeClient`, `Client` |
| `models` | ✅ | `Banknote`, `AppUser`, `SystemStatus`, `ChatMessage` |
| `widgets` | ✅ | `SectionCard`, `StatusBadge`, `NgDisplay`, `IsleEmblem` |

**royal_app duplicates ~2000 LOC** reimplementing these.

### Migration for royal_app:
```yaml
# royal_app/pubspec.yaml needs:
dependencies:
  api_client: { path: ../shared/api_client }
  models: { path: ../shared/models }
  widgets: { path: ../shared/widgets }
  provider: ^6.1.0  # for ChangeNotifier
```

---

## Isle App Specific Features (Not in royal_app)

### 1. Onboarding / PIN / Seed Flow (`welcome_screen.dart` — 1191 lines)
- **PIN Setup** → **PIN Entry** → **Seed Login** (24-word BIP39) → **Connection Handshake**
- Secure storage via `SecurePrefs` (SHA-256 + XOR encryption, device-bound key)
- Tor + V2Ray health checks before unlock
- Multi-language (EN/RU/ES/ZH)

### 2. ParanoidX Tor/V2Ray Bridge (Android native)
- `ParanoidXController.kt` starts Tor (9050) + V2Ray (10810/10811) on app launch
- MethodChannel `com.example.isle_app/paranoidx` for Dart ↔ Kotlin status
- `TorController`, `V2RayController` manage binaries in app files dir

### 3. SIMplex Chat (Full E2E Messaging)
- Contact management, QR invite, message bubbles, reactions, replies, forwarding
- Money attachments (XAG/USDT/BTC), voice messages, file sharing
- Read receipts, recall, encryption flags
- AI Steward integration (`/api/chat/ai`)

### 4. Wallet / Market / POS / Vault
- Multi-asset wallet (BTC, ETH, USDT, SOL, XRP, XAG)
- Orderbook market with charts
- Point-of-sale invoice generation (QR + LN)
- Encrypted vault with biometric unlock

### 5. Radio Player + WebRTC
- Icecast/SimpleX streaming
- WebRTC signaling via `webrtc` Go package

---

## BIP39 Onboarding Design Discussion (2026-07-26)

### User Proposal
> "In citizen onboarding, app with no active user profile starts in initial state and offers user to create new account and save keys. Use BIP39 for onboarding, entropy source = current date + 5 words (lowercase English, ≤16 chars each), combine, hash 100,000 times, final hash = entropy source."

### Analysis

**Entropy Calculation:**
- Current date (YYYY-MM-DD): ~11 bits (known to attacker)
- 5 words × 16 chars = 80 chars from [a-z] = 80 × log2(26) ≈ **376 bits**
- Combined string ≈ 387 bits → SHA256 → 256 bits
- PBKDF2-HMAC-SHA256 × 100,000 iterations

**Issues:**
1. **Date is not secret** — reduces entropy by ~11 bits (negligible vs 376)
2. **User-chosen words** — humans pick predictable words (not uniform random)
3. **100k iterations** — good (matches BIP39 default 2048 rounds × ~50), but PBKDF2 is GPU-friendly
4. **No salt** — identical inputs → identical seeds (rainbow table risk)

**How Real Crypto Projects Do It:**

| Project | Entropy Source | KDF | Notes |
|---------|----------------|-----|-------|
| **Bitcoin Core** | OS CSPRNG (`getrandom`/`CryptGenRandom`) | — | No user input |
| **Electrum** | OS CSPRNG → BIP39 mnemonic | PBKDF2 2048 | User writes down 12/24 words |
| **BlueWallet** | OS CSPRNG → BIP39 | PBKDF2 2048 | Optional passphrase (BIP39 "25th word") |
| **Muun** | OS CSPRNG → BIP39 | PBKDF2 2048 | + 2FA backup |
| **Phoenix** | OS CSPRNG → BIP39 | PBKDF2 2048 | Lightning-specific |
| **Breez** | OS CSPRNG → BIP39 | PBKDF2 2048 | Auto-backup to Google Drive (encrypted) |

**Standard Pattern (Recommended):**
```dart
// 1. Generate 256-bit entropy from OS CSPRNG
final entropy = Random.secure().nextBytes(32);  // dart:math

// 2. Encode to BIP39 mnemonic (12/24 words)
final mnemonic = Bip39.mnemonicFromEntropy(entropy);  // bip39 package

// 3. Derive seed with optional passphrase (BIP39 standard)
final seed = Bip39.seedFromMnemonic(mnemonic, passphrase: userPassphrase ?? '');

// 4. Derive master key (BIP32/BIP44)
final masterKey = Bip32.fromSeed(seed);
```

**Why OS CSPRNG > User Words:**
- Uniform distribution guaranteed
- No human bias (people pick "love", "freedom", "island", "king", "crypto")
- Standard, auditable, compatible with all wallets
- User still gets **write-down backup** (the mnemonic) — this IS the UX

**If You Want User Involvement:**
- Let user add a **passphrase** (BIP39 "25th word") — high entropy, user-memorable
- Show mnemonic **once** for paper backup, then encrypt with PIN in SecurePrefs
- Never derive entropy from user-typed words alone

---

## Build & Deployment

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ | Native Tor/V2Ray bridge, ParanoidX |
| iOS | ✅ | Flutter create regenerated Runner |
| Linux | ✅ | Standard Flutter desktop |
| macOS | ✅ | Standard Flutter desktop |
| Web | ❌ | No `web/` folder, Tor bridge incompatible |

**Cannot build on netbook** — no Flutter SDK (per AGENTS.md). Build on Lenovo/MacBook.

---

## Commands for Future Audits

```bash
# From apps/isle_app/
flutter analyze --no-pub              # 240 issues (0 errors)
flutter test --no-pub                 # Load test (times out on netbook)
dart fix --apply --dry-run            # Preview auto-fixes

# Cross-check shared packages
cd ../shared/api_client && flutter analyze --no-pub
cd ../shared/models && flutter analyze --no-pub
cd ../shared/widgets && flutter analyze --no-pub

# Compare API endpoints used vs server routes
grep -r "api\." lib/ | grep -o '/api/[^'"'"'")]*' | sort -u
# Compare with: grep -r "router\." /home/tomas/simplex-node/cmd/simplex-node/main.go
```

---

## Related Files

- Royal app audit: `references/royal-app-audit-2026-07-25.md`
- Full report: `/home/tomas/simplex-node/AUDIT-ROYAL-APP-2026-07-25.md` (royal only)
- Project AGENTS.md: `/home/tomas/simplex-node/AGENTS.md`
- Shared packages: `/home/tomas/simplex-node/apps/shared/`
- USB backup codebase: `/tmp/codebase/apps/isle_app/` (older version)