# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
