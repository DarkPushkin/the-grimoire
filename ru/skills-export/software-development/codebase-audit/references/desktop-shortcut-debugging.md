# Desktop Shortcut Debugging Reference

## Problem Pattern
Desktop shortcuts (`.desktop` files) fail to launch Flutter/Linux apps because:
1. `Exec` path points to build directory (`build/linux/x64/release/bundle/`) instead of install directory
2. Binary doesn't exist at the specified path
3. Icons missing or wrong path
4. `.desktop` file not in standard locations (`~/.local/share/applications/`, `/usr/share/applications/`)

## Debugging Steps

### 1. Read the Project's `install.sh`
The install script reveals the **true install destination**:
```bash
# Typical pattern in simplex-node apps:
INSTALL_DIR="/opt/the-island"   # system-wide (needs sudo)
# OR user-level:
INSTALL_DIR="$HOME/.local/bin/the-isle"
BINARY="isle_app"
```

### 2. Check Actual Binary Location
```bash
# Check common install locations
ls -la ~/.local/bin/the-isle/isle_app
ls -la ~/.local/bin/the-royal/royal_app
ls -la /opt/the-island/isle_app
ls -la /opt/isle-royal/royal_app

# Check build output (may not exist if not built)
ls -la /path/to/app/build/linux/x64/release/bundle/isle_app
```

### 3. Validate Current `.desktop` Files
```bash
# System/user locations
desktop-file-validate ~/.local/share/applications/*.desktop
desktop-file-validate /usr/share/applications/*.desktop
desktop-file-validate ~/Desktop/*.desktop

# Check Exec paths
grep ^Exec ~/.local/share/applications/*.desktop
```

### 4. Fix `.desktop` File
```ini
[Desktop Entry]
Type=Application
Name=Royal Island
Comment=Saint Mary Liberty Island — Royal Isle Administration
Exec=/home/tomas/.local/bin/the-isle/isle_app %F
Icon=/home/tomas/.local/share/icons/hicolor/512x512/apps/the-island.png
Terminal=false
Categories=Finance;Office;
StartupNotify=true
Keywords=royal;treasury;ai;governance;administration;
```

### 5. Deploy to Standard Locations
```bash
# User-level (preferred, no sudo)
cp fixed.desktop ~/.local/share/applications/royal-island.desktop
cp fixed.desktop ~/Desktop/"Royal Island.desktop"

# System-wide (needs sudo)
sudo cp fixed.desktop /usr/share/applications/royal-island.desktop
```

### 6. Ensure Icons Exist
```bash
# Source from app's icons/
cp /path/to/app/icons/icon.png ~/.local/share/icons/hicolor/512x512/apps/the-island.png

# Or from build output
cp /path/to/app/build/linux/x64/release/bundle/icon.png ~/.local/share/icons/hicolor/512x512/apps/the-island.png

# Update icon cache
gtk-update-icon-cache -f ~/.local/share/icons/hicolor/ 2>/dev/null || true
```

### 7. Refresh Desktop Database
```bash
update-desktop-database ~/.local/share/applications/
# Or system-wide
sudo update-desktop-database /usr/share/applications/
```

## Common Pitfalls
- ❌ **Assuming build directory persists** — `flutter clean` or rebuilds remove it
- ❌ **Using `/opt/` paths without sudo install** — binary won't exist
- ❌ **Icon path in `.desktop` doesn't match actual icon location**
- ❌ **Not running `desktop-file-validate`** — catches syntax errors
- ❌ **Forgetting `update-desktop-database`** — menu won't show new entry

## Verification Checklist
- [ ] Binary exists at `Exec` path and is executable (`ls -la /path/binary`)
- [ ] `.desktop` passes `desktop-file-validate`
- [ ] Icon file exists at `Icon` path
- [ ] Entry appears in application menu
- [ ] Launching from menu works (test with timeout: `timeout 3 /path/binary --help`)
- [ ] No duplicate/conflicting `.desktop` files

## Session Example: simplex-node (2026-07-29)
**Problem**: Two shortcuts "The Island" and "Isle Royal" both pointed to wrong/old binaries
**Root Cause**: 
- `isle_app` binary was the **Royal Isle admin app** (from USB backup `flutter/.local/bin/the-isle/isle_app`)
- `royal_app` binary was old version from `/home/tomas/.local/bin/the-royal/royal_app`
- Desktop files pointed to build directories that didn't exist

**Fix Applied**:
1. Deleted old `/home/tomas/.local/bin/the-royal/` and its `.desktop` files
2. Kept working `isle_app` at `/home/tomas/.local/bin/the-isle/isle_app` (verified as Royal admin app)
3. Created new `royal-island.desktop` pointing to the working binary
4. Removed "The Island" shortcut (confusing name for admin app)
5. Result: Single "Royal Island" shortcut launching correct admin app