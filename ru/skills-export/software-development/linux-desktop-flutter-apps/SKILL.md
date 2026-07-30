---
name: linux-desktop-flutter-apps
description: Deploy/fix Flutter Linux desktop apps on old hardware.
---

# Linux Desktop Flutter Apps — Deployment & Shortcut Management

## Trigger
Use when deploying, updating, or troubleshooting Flutter Linux desktop applications on resource-constrained hardware (old laptops, embedded devices, single-board computers). Covers .desktop file management, binary builds, USB backup restoration, and process cleanup for builds.

## Core Principles
1. **Desktop shortcuts must map 1:1 to the correct binary** — citizen app ≠ admin app. User explicitly corrected inverted mapping twice.
2. **Never touch citizen app ("The Island") when fixing admin app ("Royal Island")** — user: "citizens The Island DO NOT FUCKING TOUCH NOW!!"
3. **Restore working binaries from USB backup before rebuilding** — builds fail on Tor proxy (pub.dev 501), old hardware is slow.
4. **Stop all background services before building** — ParanoidX, node monitor, simplex-node, v2ray/Xray consume RAM needed for Flutter linker.
5. **Unset ALL proxy env vars for Flutter** — `http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `all_proxy` must be unset or pub.dev fails with "501 Tor is not an HTTP Proxy".

## Desktop Shortcut Management

### Standard Locations
- System/user apps: `~/.local/share/applications/`
- Desktop copies: `~/Desktop/`
- Icons: `~/.local/share/icons/hicolor/512x512/apps/`
- Binaries: `~/.local/bin/<app-name>/`

### Naming Convention (User-Enforced)
| App | Shortcut Name | Binary Path | Purpose |
|-----|---------------|-------------|---------|
| Citizen | `The Island` | `~/.local/bin/the-isle/isle_app` | Wallet, Market, Radio, Chat, Vault, POS, Lock Screen |
| Admin | `Royal Island` | `~/.local/bin/the-royal/royal_app` | AI Office, Treasury, Governance, Dashboard, Comms, DC Cloud |

### .desktop File Template
```ini
[Desktop Entry]
Type=Application
Name=<Display Name>
Comment=<Description>
Exec=<binary-path> %F
Icon=<icon-path>
Terminal=false
Categories=Finance;Office;
StartupNotify=true
Keywords=<search-terms>;
```

### Validation
```bash
desktop-file-validate ~/.local/share/applications/<name>.desktop
```

### Common Pitfalls
- ❌ **Inverted mapping**: Admin binary pointed by citizen shortcut (happened twice in session)
- ❌ **Stale .desktop files** not removed when binary moves/deletes
- ❌ **Missing icon files** — copy from backup or Flutter build bundle
- ❌ **Exec path wrong** — must point to actual binary, not wrapper script

## Binary Restoration from USB Backup

### USB Backup Locations (Project-Specific)
```
/run/media/tomas/SIMPLEX-USB/
├── backups/simplex-node-backup-torquemada-20260725-000033.tar.gz  # Full known-good backup
├── simplex-fork/                                                    # Working fork
├── isle-app-windows.zip                                             # Windows build (may contain Linux artifacts)
└── simplex-node-broken-bak-20260607-050957/                        # Old broken state
```

### Extraction & Restoration
```bash
# Extract full backup
mkdir -p /tmp/usb-backup-extract
tar -xzf /run/media/tomas/SIMPLEX-USB/backups/simplex-node-backup-torquemada-20260725-000033.tar.gz -C /tmp/usb-backup-extract

# Restore citizen app (The Island)
cp /tmp/usb-backup-extract/simplex-node-backup/flutter/.local/bin/the-isle/isle_app ~/.local/bin/the-isle/isle_app
cp -r /tmp/usb-backup-extract/simplex-node-backup/flutter/.local/bin/the-isle/{lib,data} ~/.local/bin/the-isle/

# Restore admin app (Royal Island)
cp /tmp/usb-backup-extract/simplex-node-backup/codebase/apps/royal_app/build/linux/x64/release/bundle/royal_app ~/.local/bin/the-royal/royal_app
cp -r /tmp/usb-backup-extract/simplex-node-backup/codebase/apps/royal_app/build/linux/x64/release/bundle/{lib,data} ~/.local/bin/the-royal/
```

### Verification
```bash
strings ~/.local/bin/the-isle/isle_app | grep -i "org.stmaria.the_island"  # Citizen app
strings ~/.local/bin/the-royal/royal_app | grep -i "com.example.royal_app"  # Admin app
```

## Process Cleanup for Builds

### Services to Stop (Memory-Constrained Hardware)
```bash
pkill -f "simplex-node"
pkill -f "paranoidx"
pkill -f "node.*monitor"
pkill -f "v2raya"        # Root process
pkill -f "xray run"      # May leave 3 instances (VLESS client, VLESS server, legacy VMess)
```

### Port Cleanup
```bash
# Port 10808 often held by docker-proxy after v2ray cleanup
ss -tlnp | grep :10808
kill <pid>  # or stop docker if it owns it
```

## Flutter Build on Tor-Proxied / Offline-First Systems

### Required Environment
```bash
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
flutter pub get
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
flutter build linux --release
```

### Common Dependency Fixes
- `bip32: ^3.0.0` → `^2.0.0` (pub.dev 403 on newer version via proxy)
- `encrypt: ^5.0.3` — needed for `identity_service.dart`
- Missing packages for identity: `bip39`, `bip32`, `ed25519_hd_key`, `convert`, `pinenacl`
- Add via: `flutter pub add bip39 bip32 ed25519_hd_key convert pinenacl`
- Clean build dirs before retry: `rm -rf apps/*/build .dart_tool`

### Dart Library-Level Privacy (Cross-File Method Access)
When a `.dart` file defines private methods that files in the same package need to call, those methods are NOT accessible from other `.dart` files — each file is its own Dart library unless `part`/`part of` is used.

**Symptom**: Build error: `The method '_get' isn't defined for the type 'SimplexApiClient'.`
**Root cause**: `simplex_api_client.dart` defines `_get()` privately. `royal_client.dart` (separate file) calls `_client._get()`.
**Fix**: Rename to public: `_get` → `get`, `_post` → `post`, `_getBytes` → `getBytes` in the defining class. Update ALL callers.
**Lesson**: Inline sub-classes defined INSIDE the same file work (same Dart library). Consumers in separate files fail. This is not a bug — it's how Dart privacy works.

### Missing Model Classes in Shared Packages
When `api_client` uses typed return values but the `models` package doesn't define them, add the missing class with:
```dart
class ClassName {
  final bool success;
  const ClassName({this.success = false, this.message = ''});
  factory ClassName.fromJson(Map<String, dynamic> json) => ClassName(
    success: json['success'] ?? false,
    message: json['message'] ?? '',
  );
}
```
Then ensure `apps/shared/models/lib/models.dart` exports the file (via `export 'src/xxx.dart';`).
Files in `api_client` that reference model types need explicit `import 'package:models/models.dart';` — Dart does NOT re-export transitive imports.

### Build Output Location
```
apps/<app_name>/build/linux/x64/release/bundle/
├── <app_name>           # Main binary
├── lib/                 # Flutter engine .so files
└── data/                # icudtl.dat, assets, fonts
```

## Disk Space Management (Critical on 58GB SSD)

### Safe Cleanup Targets
```bash
# Flutter build artifacts
rm -rf apps/*/build .dart_tool

# Go caches (huge)
go clean -modcache -buildcache  # ~1.8GB

# System caches
rm -rf ~/.cache/* /tmp/* /var/tmp/*

# Downloads installers
rm -rf ~/Downloads/*.deb ~/Downloads/*.AppImage ~/Downloads/*.tar.gz
```

### Target: Keep >8GB free for Flutter linker

## Verification Checklist
- [ ] Both .desktop files validate with `desktop-file-validate`
- [ ] Citizen shortcut → `the-isle/isle_app` (strings shows "org.stmaria.the_island")
- [ ] Admin shortcut → `the-royal/royal_app` (strings shows "com.example.royal_app")
- [ ] Both binaries launch (GUI timeout = success in headless)
- [ ] Icons present at icon paths
- [ ] No stale shortcuts remain (Isle Royal deleted)
- [ ] Background processes stopped
- [ ] Disk space >8GB free

## Related Skills
- `hermes-desktop-plugins` — for Hermes-specific desktop integration
- `software-development/systematic-debugging` — root-cause debugging workflow
- `software-development/spike` — throwaway build experiments

## References
- `references/desktop-shortcut-templates.md` — .desktop file templates
- `references/usb-backup-extraction.md` — USB backup extraction procedures
- `references/flutter-tor-proxy-workaround.md` — Proxy env var unset patterns