# USB Backup Extraction Procedures — simplex-node Project

## USB Drive Location
```
/run/media/tomas/SIMPLEX-USB/
```

## Backup Files
| File | Description | Size | Date |
|------|-------------|------|------|
| `backups/simplex-node-backup-torquemada-20260725-000033.tar.gz` | Full known-good backup (codebase + flutter binaries) | ~2GB | 2026-07-25 |
| `simplex-fork/` | Working fork directory (git repo) | - | 2026-07-23 |
| `isle-app-windows.zip` | Windows build (may contain Linux artifacts) | - | - |
| `simplex-node-broken-bak-20260607-050957/` | Old broken state (docker only) | - | 2026-06-07 |

## Extraction Commands

### Full Backup (Recommended)
```bash
mkdir -p /tmp/usb-backup-extract
tar -xzf /run/media/tomas/SIMPLEX-USB/backups/simplex-node-backup-torquemada-20260725-000033.tar.gz -C /tmp/usb-backup-extract
```

### Extracted Structure
```
/tmp/usb-backup-extract/simplex-node-backup/
├── bin/                    # Compiled Go binaries
├── codebase/               # Full source code
│   └── apps/
│       ├── isle_app/       # Citizen app source
│       └── royal_app/      # Admin app source (with build artifacts)
├── config/                 # Config files
├── data/                   # Runtime data
├── flutter/                # Pre-built Flutter binaries
│   └── .local/bin/the-isle/isle_app  # Citizen binary + libs + data
└── session/                # Session data
```

## Binary Restoration

### Citizen App (The Island) — Pre-built Binary
```bash
# Binary
cp /tmp/usb-backup-extract/simplex-node-backup/flutter/.local/bin/the-isle/isle_app ~/.local/bin/the-isle/isle_app

# Dependencies
cp -r /tmp/usb-backup-extract/simplex-node-backup/flutter/.local/bin/the-isle/{lib,data} ~/.local/bin/the-isle/
```

### Admin App (Royal Island) — From Built Source
```bash
# Binary (from built bundle)
cp /tmp/usb-backup-extract/simplex-node-backup/codebase/apps/royal_app/build/linux/x64/release/bundle/royal_app ~/.local/bin/the-royal/royal_app

# Dependencies
cp -r /tmp/usb-backup-extract/simplex-node-backup/codebase/apps/royal_app/build/linux/x64/release/bundle/{lib,data} ~/.local/bin/the-royal/
```

## Verification
```bash
# Citizen app identifier
strings ~/.local/bin/the-isle/isle_app | grep -i "org.stmaria.the_island"

# Admin app identifier
strings ~/.local/bin/the-royal/royal_app | grep -i "com.example.royal_app"

# Both should launch (GUI timeout = success in headless)
timeout 10 ~/.local/bin/the-isle/isle_app 2>&1 | grep -q "cursor theme" && echo "Citizen OK"
timeout 10 ~/.local/bin/the-royal/royal_app 2>&1 | grep -q "cursor theme" && echo "Admin OK"
```

## Source Code Recovery (If Rebuilding)
```bash
# Full source trees available at:
/tmp/usb-backup-extract/simplex-node-backup/codebase/apps/isle_app/
/tmp/usb-backup-extract/simplex-node-backup/codebase/apps/royal_app/
/tmp/usb-backup-extract/simplex-node-backup/codebase/apps/shared/
```

## Notes
- USB drive may be unmounted between sessions — check `/run/media/tomas/` and `/media/tomas/`
- The tar.gz backup is the most complete (includes pre-built Flutter binaries)
- `simplex-fork/` is a git repo — can `cd` and `git log` for history
- `isle-app-windows.zip` untested for Linux artifacts
- Clean `/tmp/usb-backup-extract/` after use (space-constrained system)