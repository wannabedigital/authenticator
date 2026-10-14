# Authenticator

A minimal authenticator for macOS 26 and later: two-factor codes (TOTP and HOTP) in a native SwiftUI interface with Liquid Glass.

The app works entirely offline. It has no network access and no third-party dependencies, and your secret keys are stored only on your Mac, encrypted.

## Features

- TOTP and HOTP codes (RFC 6238 and RFC 4226): SHA-1, SHA-256 and SHA-512, 6 to 8 digits.
- Profiles with a name, color and icon, for example to keep personal and work accounts apart.
- QR code import: drag an image from Finder, Telegram or a browser, paste it with ⌘V, or choose a file.
- Transfer from Google Authenticator: its export format (`otpauth-migration://`) is supported, including exports split across several QR codes.
- Transfer to Google Authenticator: compatible accounts are shown as QR codes to scan on your iPhone.
- Password-protected backup files with all profiles and settings, to move to another Mac or keep as a backup.
- A QR code for a single account that any authenticator app can scan.
- `otpauth://` links and manual key entry.
- Lock with Touch ID or your Mac password: on launch, when the screen locks, on sleep and after a set time in the background.
- Click a code to copy it; the clipboard is cleared after 30 seconds.
- Search codes (⌘F) and profiles (⇧⌘F).
- Interface in English and Russian, following the macOS language.

## Security

| | |
|---|---|
| Network | The app runs in the macOS sandbox without the network entitlement, so the system won't let it send anything. |
| Dependencies | Only Apple system frameworks: SwiftUI, CryptoKit, Security, LocalAuthentication, Vision. |
| Storage | All data lives in one file encrypted with AES-256-GCM. The random 256-bit key is stored in the Keychain. |
| Backups | Encrypted with AES-256-GCM using a key derived from your password with PBKDF2-HMAC-SHA256 (600,000 iterations, random salt). |
| Memory | While the app is locked, the vault isn't decrypted. |
| QR codes | Recognized on device with the Vision framework. |
| Clipboard | Codes are marked as concealed for clipboard managers and erased after 30 seconds. |

You can check the entitlements of a built app:

```bash
codesign -d --entitlements - Authenticator.app
```

The output lists only `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-write`, which allows access only to files you pick in the Open and Save dialogs. Debug builds also include `com.apple.security.get-task-allow` for the Xcode debugger. There is no network entitlement.

Limitations worth knowing:

- The Touch ID lock protects the interface. The vault key is kept in the login keychain and is available to the app while you're logged in.
- The vault doesn't sync through iCloud. Make a backup with File → Export, and keep the backup codes that services give you when you turn on two-factor authentication.

## Installation

Download the latest `.dmg` from [Releases](https://github.com/wannabedigital/authenticator/releases) and drag Authenticator into Applications.

The app isn't notarized by Apple, so on first launch macOS blocks it. Click **Done**, then go to **System Settings → Privacy & Security**, click **Open Anyway** next to the message about Authenticator, and confirm. You only need to do this once. The release notes have step-by-step instructions in English and Russian.

## Requirements

- macOS 26 Tahoe or later
- Xcode 26 or later to build

## Building

```bash
git clone git@github.com:wannabedigital/authenticator.git
cd authenticator
open Authenticator.xcodeproj
```

In Xcode, choose your team: Authenticator target → Signing & Capabilities → Team. A free Personal Team works; you only need to sign in with your Apple ID. Then press ⌘R.

If you choose Team: None, Xcode signs the app locally. It works, but macOS asks for Keychain access again after every rebuild.

## Moving from Google Authenticator

1. In Google Authenticator on your iPhone, open the menu, choose to transfer accounts, then export, and select the accounts.
2. Take a screenshot of the QR code. If there are several codes, capture each one.
3. Move the screenshots to your Mac, for example with AirDrop.
4. In Authenticator, click + and drag the screenshots onto the import area.
5. Delete the screenshots: they contain your secret keys.

## Backups and moving to another Mac

1. Choose File → Export, keep Authenticator File selected, and pick the accounts.
2. Set a password of at least 8 characters, confirm with Touch ID and save the `.authbackup` file.
3. On the other Mac, choose File → Open Backup, enter the password and pick the profiles to import.

Profiles with the same name get the new accounts, and accounts you already have are skipped. A forgotten password can't be recovered.

## Moving to Google Authenticator

1. In Authenticator, choose File → Export and select Google Authenticator.
2. Select the accounts and confirm with Touch ID.
3. In Google Authenticator on your iPhone, open the menu, choose to transfer accounts, then import, and scan each QR code.

Google Authenticator supports only SHA-1 codes with 6 digits and a 30-second period, so other accounts can't be exported and are shown as unavailable.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New account |
| ⇧⌘N | New profile |
| ⌘F | Find code |
| ⇧⌘F | Find profile |
| ⌘E | Export |
| ⌘O | Open backup |
| ⌃⌘L | Lock |
| ⌘, | Settings |
| ⌘V | Paste a QR code while hovering over the import area |

## Project structure

```
Authenticator/
├── App/        entry point and menus
├── Core/       Base32, code generation, otpauth://, Google Authenticator format
├── Import/     QR recognition, drag and drop, clipboard
├── Security/   Touch ID lock
├── Storage/    encryption, Keychain, profiles
└── Views/      interface
Config/         sandbox entitlements
```

## Roadmap

- Scanning QR codes with the Mac or iPhone camera

## License

[MIT](LICENSE)
