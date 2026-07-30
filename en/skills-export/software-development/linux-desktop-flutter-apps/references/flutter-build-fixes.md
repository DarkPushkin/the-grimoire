# Flutter Build Fixes — Common Compilation Errors & Workarounds

## Context
This document captures recurring Flutter/Dart build issues encountered during the simplex-node/royal_app build on Linux (old hardware, Tor-proxied environment). Use as a checklist before/after major dependency upgrades or Flutter version changes.

---

## 1. flutter_gen Import Path Not Found

### Error
```
Error: Error when reading 'lib/l10n/generated/app_localizations.dart': No such file or directory
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### Root Cause
`flutter_gen` package in pub cache (`~/.pub-cache/hosted/pub.dev/flutter_gen-*/`) does NOT contain `lib/gen_l10n/` — it is a code generator, not a runtime library. The `import 'package:flutter_gen/gen_l10n/app_localizations.dart'` path **does not resolve** and is untestable without `build_runner` succeeding, which is flaky on Tor-proxied systems.

`flutter gen-l10n` outputs generated files to `lib/l10n/generated/` by default (per `l10n.yaml`).

### Proven Working Import Path
```dart
import 'package:royal_app/l10n/generated/app_localizations.dart';
```
Use `AppLocalizations.of(context)!` or `lookupAppLocalizations(context)` to access.

### Alternative: flutter_gen + build_runner (unreliable)
```yaml
# pubspec.yaml
flutter:
  generate: true
```
```bash
flutter pub get
flutter gen-l10n
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter pub run build_runner build --delete-conflicting-outputs
# If build_runner hangs (common on Tor), manual copy workaround:
mkdir -p .dart_tool/flutter_gen/gen_l10n
cp lib/l10n/generated/* .dart_tool/flutter_gen/gen_l10n/
```

> **Note:** `build_runner` regularly times out or hangs on Tor-proxied systems. The direct import via `royal_app/l10n/generated/` is more reliable.

---

## 2. Deprecated FontVariant.tabularNums

### Error
```
'FontVariant.tabularNums' is deprecated and shouldn't be used. Use FontFeature.tabularFigures instead.
```

### Fix
```dart
// OLD
fontVariants: [FontVariant.tabularNums],

// NEW
fontFeatures: [FontFeature.tabularFigures()],
```

### Affected Files (Pattern)
- `onboarding_screen.dart` - headlineMedium, bodyMedium
- `bridge_setup_screen.dart` - monospace text fields
- Any `TextStyle` using tabular numbers for PIN/code display

---

## 3. Icons.onion_rounded Does Not Exist

### Error
```
The getter 'onion_rounded' isn't defined for the class 'Icons'.
```

### Fix
```dart
// OLD
Icon(Icons.onion_rounded)

// NEW - Use security icon for Tor/onion routing
Icon(Icons.security_rounded)
```

---

## 4. Reserved Keyword 'continue' in Localization

### Error
```
'continue' is a reserved keyword and cannot be used as an identifier.
```

### Fix in ARB Files
```json
// app_en.arb
{
  "continueAction": "Continue"
}

// app_ru.arb
{
  "continueAction": "Продолжить"
}
```

### Usage in Dart
```dart
// OLD (breaks)
Text(l10n.continue)

// NEW
Text(l10n.continueAction)
```

---

## 5. Null Safety for String? Fields

### Pattern: Optional Config Strings
```dart
// Field declaration
String? _simplexNodeConfig;

// Null-safe checks
if ((_simplexNodeConfig?.isNotEmpty ?? false)) { ... }

// Safe display
Text(_simplexNodeConfig?.isEmpty ?? true ? 'Not configured' : _simplexNodeConfig!)

// Safe controller initialization
TextEditingController(text: widget.simplexNodeConfig ?? '')
```

### SharedPreferences Save
```dart
// OLD (crashes on null)
await _prefs.setString('simplex_node_config', _simplexNodeConfig);

// NEW
if ((_simplexNodeConfig?.isNotEmpty ?? false)) {
  await _prefs.setString('simplex_node_config', _simplexNodeConfig!);
}
```

---

## 6. AppLocalizations Initialization Pattern

### Correct Pattern for State Classes
```dart
class _MyScreenState extends State<MyScreen> {
  late AppLocalizations _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    // Use _l10n here
    return Text(_l10n.someKey);
  }
}
```

### Anti-Patterns to Avoid
```dart
// ❌ BAD: Calling in initState - context not ready
@override
void initState() {
  _l10n = AppLocalizations.of(context)!; // CRASH
}

// ❌ BAD: flutter_gen import path — flutter_gen package does NOT contain gen_l10n/
// This import compiles only if build_runner succeeded and generated into .dart_tool/
// On Tor-proxied systems build_runner regularly hangs, making this path unreliable.
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### ✅ Working Import (Proven on Tor-Proxied Systems)
```dart
import 'package:royal_app/l10n/generated/app_localizations.dart';
```
Use `AppLocalizations.of(context)!` or `lookupAppLocalizations(context)` in `didChangeDependencies()` — same as above.

---

## 7. Missing dart:async Import for Timer

### Error
```
Type 'Timer' not found.
```

### Fix
```dart
import 'dart:async';  // Add at top of file
```

### Affected Files
- `lock_screen.dart` - uses `Timer.periodic` for lockout countdown

---

## 8. Localization Keys Added This Session

### English (app_en.arb)
```json
{
  "russianDetected": "Russian detected",
  "englishDetected": "English detected",
  "bootMessage": "Booting Royal Control"
}
```

### Russian (app_ru.arb)
```json
{
  "russianDetected": "Русский язык обнаружен",
  "englishDetected": "Английский язык обнаружен",
  "bootMessage": "Загрузка Royal Control"
}
```

---

## 9. AppState Methods Required by Screens

### Missing Methods (Added to main.dart)
```dart
class AppState extends ChangeNotifier {
  // ... existing fields ...

  void setIdentity(Identity identity) {
    _identity = identity;
    notifyListeners();
  }

  void setUnlocked(bool v) {
    unlocked = v;
    notifyListeners();
  }
}
```

### Usage in Screens
```dart
final appState = context.read<AppState>();
appState.setIdentity(identity);
appState.setUnlocked(true);
```

---

## 10. ARB Functions with Parameters (Not Just Strings)

### Error
```
Error: The method 'replaceFirst' isn't defined for the type 'String Function(Object)'.
```

### Root Cause
ARB entries with `{param}` syntax generate Dart **methods**, not string getters:
```json
// app_en.arb
{
  "testingProtocol": "Testing {protocol}..."
}
```
This generates: `String testingProtocol(Object protocol)` — a function, not a `String`.

### Fix
```dart
// ❌ BAD: treating ARB key as string with placeholder replacement
_currentMessage = _l10n.testingProtocol.replaceFirst('{protocol}', protocol.displayName);

// ✅ GOOD: calling the generated function directly with the parameter
_currentMessage = _l10n.testingProtocol(protocol.displayName);
```

### Detection
- Look for `.replaceFirst('{`, `.replaceAll('{` on a `_l10n.*` value
- If it compiles but `.replaceFirst` is called on a localizable, it's likely a `String Function(Object)` not a `String`
- Run `flutter gen-l10n` and inspect the generated `app_localizations.dart` to see which keys are functions vs properties

---

## 11. AppState Import Pattern for Screens

### Error
```
Error: 'AppState' isn't a type.
```

### Problem
Screens that use `context.read<AppState>()` (e.g., `onboarding_screen.dart`, `lock_screen.dart`) need the `AppState` type in scope. `AppState` is defined in `main.dart` but is NOT exported as a public library.

### Fix
```dart
// Add to screen file imports:
import '../main.dart';

// Then use in build methods / handlers:
final appState = context.read<AppState>();
appState.setIdentity(identity);
appState.setUnlocked(true);
```

### Also Required in main.dart
`AppState` must expose `setIdentity` and `setUnlocked` methods:
```dart
class AppState extends ChangeNotifier {
  // ...
  void setIdentity(Identity identity) {
    _identity = identity;
    notifyListeners();
  }

  void setUnlocked(bool v) {
    unlocked = v;
    notifyListeners();
  }
}
```

### LocalizationsDelegates Must Be Mutable
```dart
// main.dart — ❌ const list fails at runtime
localizationsDelegates: const [
  AppLocalizations.delegate,  // Error: Constant evaluation error
  ...
]

// ✅ Mutable list works
localizationsDelegates: [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
],
```

---

## 12. Complete Build Command (Tor-Proxied Systems)

```bash
# 1. Stop memory-heavy services
pkill -f simplex-node
pkill -f paranoidx
pkill -f "node.*monitor"
pkill -f v2raya
pkill -f "xray run"

# 2. Free port 10808 if held by docker-proxy
ss -tlnp | grep :10808 && kill $(ss -tlnp | grep :10808 | awk '{print $NF}' | cut -d= -f2)

# 3. Clean build artifacts
rm -rf apps/royal_app/build .dart_tool

# 4. Generate l10n
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter gen-l10n

# 5. Build with all proxy env vars unset
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
flutter build linux --release 2>&1

# 6. Verify binary
ls -la build/linux/x64/release/bundle/royal_app
file build/linux/x64/release/bundle/royal_app
file build/linux/x64/release/bundle/royal_app
```

---

## 12. Verification Checklist Before Commit

- [ ] All screens import from `royal_app/l10n/generated/app_localizations.dart` (NOT flutter_gen)
- [ ] No `FontVariant.tabularNums` — all use `FontFeature.tabularFigures()`
- [ ] No `Icons.onion_rounded` — use `Icons.security_rounded`
- [ ] No `l10n.continue` — use `l10n.continueAction`
- [ ] All `String?` fields use `??` or `?.` operators
- [ ] `didChangeDependencies()` used for `AppLocalizations.of(context)!`
- [ ] `import 'dart:async';` in files using `Timer`
- [ ] `pubspec.yaml` has `flutter: generate: true`
- [ ] ARB functions with `{param}` syntax are called as function calls, not with `.replaceFirst()`
- [ ] `AppState` type is available via `import '../main.dart'` in screens using `context.read<AppState>()`
- [ ] LocalizationsDelegates is mutable (not `const`) to allow `AppLocalizations.delegate`
- [ ] No unused imports (check via `flutter analyze`)

---

## Session-Specific Fixes (2026-07-28 through 2026-07-30)

### Files Modified
- `lib/main.dart` — imports, AppState methods, mutable localizationsDelegates
- `lib/screens/boot_screen.dart` — imports, _l10n init, language detection
- `lib/screens/bridge_setup_screen.dart` — imports, null safety, dialog params, testingProtocol call
- `lib/screens/onboarding_screen.dart` — imports, _pinObscure field, hashPin via context.read, AppState import
- `lib/screens/lock_screen.dart` — imports, Timer import, _l10n init, AppState import
- `lib/screens/registration_screen.dart` — imports, Random import
- `lib/l10n/app_en.arb` / `app_ru.arb` — 20+ new keys
- `pubspec.yaml` — `generate: true`, `build_runner` dev dependency

### Key Workarounds Applied
1. **Import path migration** — switched from `flutter_gen/gen_l10n/` to `royal_app/l10n/generated/` after proving flutter_gen package lacks gen_l10n in pub cache
2. **Mutable localizationsDelegates** — changed from `const` to mutable list to allow `AppLocalizations.delegate`
3. **ARB function call** — `testingProtocol({protocol})` → called as `_l10n.testingProtocol(protocol.displayName)` not `.replaceFirst()`
4. **AppState import** — screens now import `../main.dart` for `context.read<AppState>()` access
5. **Removed unused imports** — `flutter_animate`, `bridge_setup_screen`, `onboarding_screen`, unused local variables cleaned across all screen files
6. **Deprecated API replacement** — `activeColor` → `activeThumbColor` in Switch widget
7. **Build result**: 0 errors, 64 infos/warnings (style only), binary at 24KB