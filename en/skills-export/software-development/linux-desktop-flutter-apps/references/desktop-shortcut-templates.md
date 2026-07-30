# Desktop Shortcut Templates — Flutter Linux Apps

## Citizen App: The Island
```ini
[Desktop Entry]
Type=Application
Name=The Island
Comment=Saint Mary Liberty Island — Citizen App (Wallet, Market, Radio, Chat, Vault, POS, Lock Screen)
Exec=/home/tomas/.local/bin/the-isle/isle_app %F
Icon=/home/tomas/.local/share/icons/hicolor/512x512/apps/the-island.png
Terminal=false
Categories=Finance;Office;
StartupNotify=true
Keywords=island;citizen;wallet;market;radio;chat;vault;pos;lock;
```

## Admin App: Royal Island
```ini
[Desktop Entry]
Type=Application
Name=Royal Island
Comment=Saint Mary Liberty Island — Royal Isle Administration (AI Office, Treasury, Governance)
Exec=/home/tomas/.local/bin/the-royal/royal_app %F
Icon=/home/tomas/.local/share/icons/hicolor/512x512/apps/isle-royal.png
Terminal=false
Categories=Finance;Office;
StartupNotify=true
Keywords=royal;treasury;ai;governance;administration;
```

## Generic Template
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

## Validation
```bash
desktop-file-validate ~/.local/share/applications/<name>.desktop
```

## Deploy to Both Locations
```bash
cp <name>.desktop ~/.local/share/applications/
cp <name>.desktop ~/Desktop/
```