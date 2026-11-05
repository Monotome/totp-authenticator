# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- **Master Password Vault Reset & Auto-Backup (`apps/ui`)**: Added "Forgot password? Reset vault" button to the desktop App Locked screen. Includes automated timestamped backup (`~/.totp_config.json.bak_YYYYMMDD_HHMMSS`) before wiping, Catppuccin-themed safety confirmation modal requiring explicit `RESET` verification, and seamless direct transition into the main unlocked application.
- **Mandatory Documentation Synchronization (`AGENTS.md`)**: Enforced rule requiring all future feature implementations, bug fixes, refactorings, and architecture changes to be documented in `CHANGELOG.md` and `docs/` in the same PR.
- **Roadmap Update**: Added desktop Master Password Vault Reset & Auto-Backup to planned improvements (`docs/ROADMAP.md`).

## [v0.7.0] - 2026-11-05
### Added
- **Official Mobile Companion App (`apps/mobile`)**: Multi-platform companion app for Android and iOS built with Flutter & Material 3.
- **Biometric App Protection (`local_auth`)**: Fingerprint, Face ID, and device PIN/pattern lock on cold startup and auto-lock upon background resumption.
- **Multitasking Privacy Shield**: Automatic privacy blur overlay preventing OTP secrets leakage in OS recent apps and multitasking views.
- **End-to-End Encrypted Cloud Sync**: Zero-knowledge synchronization with FastAPI backend (`apps/api`), 100% interoperable with Desktop (`apps/ui`) via Fernet and PBKDF2 (480,000 rounds).
- **Camera QR Scanner & Live OTP Preview**: Real-time camera QR scanning with custom HUD reticle and instant code verification.
- **Hardware Keystore Security**: Android Keystore and iOS Keychain hardware-backed storage for JWT tokens and master passwords.
- **Automated Multi-Platform Release CI/CD**: Release workflow builds and publishes both Windows standalone executable ZIP and Android mobile APK.

## [v0.6.3] - 2026-11-05
### Added
- **Mobile Cloud Sync & Settings (`apps/mobile`)**: Full End-to-End Encrypted (E2EE) synchronization with FastAPI backend (`apps/api`), 100% interoperable with Desktop client.
- **Zero-Knowledge Cryptography**: Fernet (AES-128-CBC + HMAC-SHA256) and PBKDF2-HMAC-SHA256 with 480,000 iterations.
- **Background Isolate Crypto**: Heavy PBKDF2 computation offloaded via `compute()` maintaining 60/120fps UI fluidity.
- **Secure Hardware Storage**: JWT access token and master encryption password protected in Android Keystore / iOS Keychain via `flutter_secure_storage`.
- **1-Click Bidirectional Sync**: Automatic Pull -> Decrypt -> Merge -> Encrypt -> Push flow with 409 Conflict resolution.
- **Settings Screen & UI Polish**: Status badge, quick emulator/localhost presets, E2EE master password dialog, and app security info.
- **Android APK CI/CD Packaging**: GitHub Actions release pipeline now automatically builds and attaches `TOTP-Authenticator-vX.Y.Z-android.apk` alongside Windows zip.

## [v0.6.2] - 2026-11-05
### Added
- **Mobile Companion App (`apps/mobile`)**: Initial cross-platform mobile client preview for Android and iOS built with Flutter.
- **Camera QR Scanner**: Real-time camera QR scanning powered by `mobile_scanner`, custom HUD reticle, laser scan animation, and instant RFC 6238 OTP verification.
- **Instant OTP Preview**: Real-time 6-digit preview confirmation sheet prior to saving accounts.
- **URI & Manual Import**: Fast parsing of `otpauth://` links and manual setup key entry.
- **Agent Skills & Workflows**: Integrated `release`, `writing-plans`, and `executing-plans` agent skills for automated development and CI/CD releases.

## [v0.6.1] - 2026-03-17
### Fixed
- Fixed auto-lockout handling after specific time freeze scenarios.

## [v0.6.0] - 2026-03-17
### Added
- **Cloud Sync Backend (`apps/api`)**: End-to-End Encrypted (E2EE) cloud synchronization server built with FastAPI, SQLite, and JWT authentication.
- **E2EE Sync Client**: Zero-knowledge push/pull sync and conflict resolution inside desktop client.
- **Docker Support**: Containerized deployment for self-hosted cloud sync backend.

## [v0.5.0] - 2026-03-14
### Added
- **URI Protocol Import**: You can now import accounts by pasting an `otpauth://` link into the "Or paste otpauth:// URI" field inside the Add Account dialog.
- **Encrypted Backup & Restore**: Added an automated process for securely exporting your accounts into a `.totp_backup` file protected by a custom password, and restoring them later. Available inside the Security Settings (⚙️).

## [v0.4.0] - 2026-03-14
### Added
- **Master Password**: You can now lock the app using a master password.
- **Encrypt at Rest**: Local secrets configuration file is now encrypted using AES-128-CBC (Fernet) if a password is set.
- **Auto-lock**: The application will automatically lock after a configurable period of inactivity.

## [0.3.0] - 2026-03-14

### Added
- System tray integration — minimize app to tray icon instead of closing
- Light and Dark themes — toggleable straight from the UI
- Window state persistence — app remembers its previous screen position between launches
- Global keyboard shortcuts: `Up`/`Down`/`Tab` for navigation, `Enter`/`Ctrl-c` to copy, `Ctrl-a` to add, etc.
- Seamless, zero-downtime config migration to support new preferences schema

### Changed
- Config file now contains `accounts` and `settings` objects  

## [0.2.0] - 2026-03-13

### Added
- Multi-account support — store and manage multiple TOTP accounts
- Account list sidebar with live codes for each account
- Add, rename, and delete accounts via dedicated dialogs
- Automatic migration from v0.1 single-secret config to multi-account format

### Changed
- Redesigned UI with two-panel layout (sidebar + main OTP view)
- Window resized to 620×400 to accommodate account list
- `storage.py` API replaced: `load_secret`/`save_secret` → `load_accounts`/`save_accounts` + `add_account`/`delete_account`/`rename_account`
- Config file format updated: `{"secret": "..."}` → `{"accounts": [...]}`

## [0.1.0] - 2026-03-12

### Added
- Auto-refreshing 6-digit TOTP codes (30-second window)
- Countdown timer with color change when code is expiring
- One-click copy to clipboard
- Persistent secret key storage
- Always-on-top window mode
- Unit tests for core logic and storage
- CI/CD pipeline with GitHub Actions
- Automated release builds with Nuitka

### Security
- Fully offline operation — zero network requests
- Local-only secret storage in user home directory
