# Flutter Monorepo Architecture — Shared Packages Pattern

## Project Structure

```
simplex-node/
├── apps/
│   ├── royal_app/          # Admin console (Flutter)
│   ├── isle_app/           # Citizen client (Flutter)
│   └── shared/             # Local packages (path deps)
│       ├── models/         # Shared Dart data models (BIP39 Identity, Chat, Wallet, POS, Radio, AI, etc.)
│       ├── api_client/     # Unified SimplexApiClient (onion/clearnet, typed endpoints, SSE, offline queue)
│       └── widgets/        # Shared UI widgets (NTDisplay, PulseDot, ChatContactList, etc.)
```

## Key Architecture Decisions

### 1. Path Dependencies (Not Git Deps)
- `pubspec.yaml` uses `path: ../shared/models` etc.
- Git deps (`git: url, ref: v1.0.0-shared`) blocked by Tor proxy (pub.dev unreachable)
- Tag `v1.0.0-shared` exists locally for future migration when network permits

### 2. Shared Models Package (`models`)
Exports all DTOs used by both apps:
- **Identity**: `Identity`, `SecureIdentityService` (BIP39 24-word, Ed25519/X25519, coin_type=1337)
- **Wallet**: `WalletBalance`, `TransferResult`, `MarketListing`, `WalletTransaction`, `BanknoteResult`, `DividendResult`
- **Market**: `MarketListing`, `MarketOrder`, `PurchaseResult`, `EscrowResult`
- **Chat**: `ChatMessage`, `Conversation`, `ChatStatus`, `MessageResult`, `BroadcastResult`
- **Radio**: `RadioStation`, `RadioTrack`, `RadioSchedule`, `ScheduledBlock`, `RadioScheduleContent`, `AiContent`
- **AI**: `AiResponse`, `AiExplanation`, `MemoryStats`, `AiHealth`
- **POS**: `Invoice`, `PaymentResult`
- **Vault**: `VaultFile`, `VaultUsage`, `UploadResult`, `DeleteResult`
- **Tokens**: `Token`, `TokenBalance`, `ExternalWallet`

### 3. Unified API Client (`api_client`)
`SimplexApiClient` — single source of truth for all HTTP:
- Auto onion/clearnet routing based on `.onion` in baseUrl
- Ed25519 request signing via `Identity` headers (`X-Identity-Pubkey`, `X-Identity-Timestamp`)
- Typed sub-clients: `WalletApi`, `MarketApi`, `TreasuryApi`, `GovernanceApi`, `SystemApi`, `ChatApi`, `RadioApi`, `VaultApi`, `AiApi`, `PosApi`, `TokenClient`, `ExternalWalletClient`, `RoyalClient`
- SSE/Events stream (`events()`) for real-time updates
- Offline queue with `flushOfflineQueue()`
- 30s timeout, exponential backoff retries

### 4. Shared Widgets (`widgets`)
Reusable UI components:
- `NTDisplay` — nano-token formatting (ng → NT, TLR)
- `PulseDot` — animated connection status indicator
- `ChatContactList`, `ChatMessageBubble`, `ChatInputBar`, `ChatEncryptionIndicator`
- `SectionCard`, `StatusBadge`, `RadioPlayer`

### 5. Isle App (`apps/isle_app`)
- `main.dart`: `IsleShell` with `PageView` + `NavigationBar` (9 tabs)
- BIP39 onboarding (`WelcomeScreen`) → SecurePrefs storage → Lock screen (`LockScreen`)
- All screens use DI: receive typed API clients + `Identity` + `mnemonic` in constructor
- ParanoidX native bridge via `ParanoidXService` (MethodChannel → Kotlin `ParanoidXController`)

### 6. Royal App (`apps/royal_app`)
- `main.dart`: `AuthGate` → `LockScreen` (PIN/biometric) → `RoyalShell` (NavigationRail/Bar)
- Uses `RoyalApiService` (legacy, being migrated to `SimplexApiClient`)
- 8 admin screens: Dashboard, AI Office, Treasury, Comms, DC Cloud, Governance, System, Settings

## Native Android Layer (ParanoidX)

```
apps/isle_app/android/app/src/main/kotlin/com/example/isle_app/
├── ParanoidXController.kt    # Orchestrator: 4-layer chain (V2Ray→VPN→Tor→SimpleX)
├── TorController.kt          # Tor hidden service + SOCKS5
├── V2RayController.kt        # V2Ray config + routing
└── MainActivity.kt           # MethodChannel bridge
```

Flutter bridge: `ParanoidXService` + `ParanoidXBridge` (MethodChannel `com.isle_app/paranoidx`)
- `getStatus()` → `ParanoidXStatus` (overall + per-layer health)
- `buildChain()` / `teardownChain()` / `testChain()` / `getChainState()`
- `vpnUp(name)` / `vpnDown(name)` / `addVpnProfile()` / `deleteVpnProfile()`
- `updateConfig(v2ray?, vpn?, tor?)`

## Build/Analysis Commands

```bash
# From project root
cd apps/isle_app && dart analyze --no-pub          # Static analysis (works offline)
cd apps/royal_app && dart analyze --no-pub

# Full flutter analyze (needs pub get, blocked by Tor)
flutter analyze --no-pub

# Test (blocked by Tor proxy)
flutter test --no-pub
```

## Dependencies Status (Tor-Blocked)

Missing from pub cache (need `flutter pub get` on clearnet):
- `bip39`, `bip32`, `ed25519_hd_key`, `pointycastle`, `encrypt` (in models)
- `drift`, `web_socket_channel` (in api_client)
- `local_auth`, `flutter_secure_storage` (in apps)

Currently: `dart analyze` on individual files passes; `flutter analyze` times out.

## Migration Pattern (Legacy → Unified)

| Legacy | Unified |
|--------|---------|
| `IsleApiService` | `SimplexApiClient` + typed APIs |
| `RoyalApiService` | `RoyalClient` (wraps typed APIs) |
| `TorAwareClient` | `SimplexApiClient` (auto onion routing) |
| `RadioPlayer` (local) | `RadioApi` + shared `RadioStation`/`RadioTrack` models |
| Inline BIP39 in `SecurePrefs` | `SecureIdentityService` in `models` |

## Key Files for Context

- `/home/tomas/simplex-node/apps/isle_app/lib/main.dart` — App shell, DI, navigation
- `/home/tomas/simplex-node/apps/shared/models/lib/models.dart` — Model exports
- `/home/tomas/simplex-node/apps/shared/api_client/lib/src/simplex_api_client.dart` — Unified client
- `/home/tomas/simplex-node/apps/shared/api_client/lib/api_client.dart` — API exports
- `/home/tomas/simplex-node/PARANOIDX-ENGINE-REPORT.md` — Native engine architecture

## Isle App — 9 Tabs (All DI via Constructor)

| Tab | Screen | API Clients Used |
|-----|--------|------------------|
| 1 | Dashboard | `WalletApi`, `MarketApi`, `VaultApi` |
| 2 | Wallet | `WalletApi`, `MarketApi`, `TokenClient`, `ExternalWalletClient` |
| 3 | Market | `MarketApi`, `WalletApi` |
| 4 | Vault | `VaultApi` |
| 5 | Radio | `RadioApi` + shared `RadioStation`/`RadioTrack` |
| 6 | Chat | `ChatApi` + shared `ChatMessage`/`Conversation` |
| 7 | ParanoidX | `ParanoidXService` (MethodChannel) |
| 8 | POS | `PosApi` + shared `Invoice`/`PaymentResult` |
| 9 | Royal | `RoyalClient` (treasury, system, economy, chat) |

**Onboarding**: `WelcomeScreen` (BIP39 24-word mnemonic → PBKDF2-HMAC-SHA512 2048 rounds → BIP32/44 Ed25519 coin_type 1337) with verification step.

**Lock**: App lifecycle observer → auto-lock on background; PIN/biometric unlock.

**Identity**: `SecurePrefs` → `SecureIdentityService` (encrypted storage, multiple identities).

## Royal App — 8 Admin Screens

| Screen | Function |
|--------|----------|
| Dashboard | Node status, system metrics, treasury snapshot, radio |
| AI Office | Steward chat, explain silver, memory stats |
| Treasury | Reserve, oracle, deflation, dividends, mint/burn, banknotes, proof-of-reserve |
| Communications | Broadcast, treasury alert, chat status |
| DC Cloud | Docker, containers, backup/restore/panic |
| Governance | Constitution, proposals, voting, delegation |
| System | Health, services, config, maintenance, emergency stop, rate limits |
| Settings | Server URL, theme, identity, PIN |

**State**: `AppState` (ChangeNotifier) — API client, selectedIndex, unlocked, SSE telemetry.

## ParanoidX Native Engine

**Location**: `isle_app/android/app/src/main/kotlin/com/example/isle_app/`
- `ParanoidXController.kt` — Orchestrator (3,507 chars)
- `TorController.kt` — Tor hidden service + SOCKS proxy (3,768 chars)
- `V2RayController.kt` — V2Ray/VMess/VLESS config + routing (3,200 chars)

**Flutter Bridge**:
- `ParanoidXService` — HTTP wrapper for REST endpoints
- `ParanoidXBridge` — MethodChannel (`com.isle.paranoidx`) for native calls

**Proxy Chain** (4 layers):
1. **V2Ray** (ingress) — VMess/VLESS, routing rules
2. **VPN** (tunnel) — WireGuard/OpenConnect, split tunneling
3. **Tor** (anonymity) — Hidden service, SOCKS5, stream isolation
4. **SimpleX** (messaging) — Double-ratchet, contact discovery

**API** (exposed to Flutter):
- `getStatus()` → overall healthy + per-layer latency
- `buildChain()` / `teardownChain()` / `getChainState()`
- `testChain()` → per-layer connectivity
- `vpnUp/down/delete/profile()` — profile management
- `updateConfig(v2ray?, vpn?, tor?)`

## Build Constraints

- **No pub.dev access** — Tor proxy is not HTTP proxy; `flutter pub get` fails with "501 Tor is not an HTTP Proxy"
- **Workaround**: All deps must be pre-cached or use path dependencies; `flutter analyze --no-pub` for static analysis
- **Missing deps** (not in pub cache): `bip39`, `bip32`, `ed25519_hd_key`, `pointycastle`, `encrypt`, `local_auth`, `flutter_secure_storage`, `drift`, `web_socket_channel`
- **iOS/Android**: Regenerated via `flutter create` (both apps have Runner projects)

## Verification Commands

```bash
# Static analysis (no pub)
dart analyze apps/isle_app/lib/main.dart
dart analyze apps/royal_app/lib/main.dart
dart analyze apps/shared/models/lib/models.dart
dart analyze apps/shared/api_client/lib/simplex_api_client.dart

# Build (requires deps in cache)
flutter build apk --no-pub -C apps/isle_app
flutter build apk --no-pub -C apps/royal_app
```