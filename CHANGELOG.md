# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- **Mobile Theme Mode & Dual-Language Selection (`apps/mobile`)**:
  - **Dynamic Theme Mode Switching**: Added `ConfigProvider` managing `ThemeMode.system`, `ThemeMode.dark`, and `ThemeMode.light` with persistence in `SharedPreferences` (`app_theme_mode`).
  - **Comprehensive Localization Framework (`AppLocalizations`)**: Implemented compile-time safe, typed translations for Vietnamese (`vi`) and English (`en`) supporting both system locale matching and explicit user selection.
  - **Settings UI Preference Controls**: Added a grouped `GIAO DIỆN & NGÔN NGỮ` (`APPEARANCE & LANGUAGE`) card in `SettingsScreen` featuring a 3-way `SegmentedButton<ThemeMode>` (System / Dark / Light) and a styled language `DropdownButton` (Theo hệ thống / Tiếng Việt / English).
  - **Full Mobile Screen Localization**: Localized all mobile user interfaces, labels, dialogs, error messages, and bottom sheets across `HomeScreen`, `LockScreen`, `AddAccountScreen`, `ScanScreen`, `ScanConfirmSheet`, and `SyncPasswordDialog`.
  - **Test Coverage**: Added dedicated unit tests for `AppLocalizations` (`app_localizations_test.dart`), `ConfigProvider` (`config_provider_test.dart`), localized widget tests (`settings_screen_test.dart`, `sync_password_dialog_test.dart`), and updated visual golden tests (`golden_test.dart`).

### Fixed
- **Mobile Theme SegmentedButton Background Color (`apps/mobile`)**: Replaced default Material 3 green (`secondaryContainer`) background on active theme segments with the app's brand Sky Blue (`theme.colorScheme.primary` / `#38BDF8`), harmonizing `SegmentedButton` styling with Modern Slate design tokens in both dark and light modes.
- **Mobile Dual-Language Input Validations & Biometrics Localization (`apps/mobile`)**:
  - Localized form validation errors in `SettingsScreen` (server URL, username, password length) and `SyncPasswordDialog` (empty encryption password) to dynamically match active language preference.
  - Localized biometric and device credential display names via `l10n.getBiometricName` (`Face ID`, `Fingerprint`, `Iris Recognition`, `Device Passcode / PIN`), eliminating mixed Vietnamese/English text (`Lock with Mã PIN / Mật khẩu máy`).
  - Localized sync action feedback SnackBars, relative timestamps (`Never synced`), Keystore persistence toggle, and divider text.

## [v0.8.2] - 2026-11-06
### Added
- **Mobile Modern Slate App Launcher Icons (`apps/mobile`)**:
  - Designed and generated high-resolution 1024x1024 vector-styled master icon and transparent adaptive foreground matching the Modern Slate theme (`#0B0F19` deep space background, `#1E293B` shield, `#38BDF8` sky blue outline, padlock, and `#4ADE80` mint green 2FA verification badge).
  - Integrated `flutter_launcher_icons` automated generation for all Android mipmap densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`), adaptive vector background/foreground (`res/values/colors.xml`, `mipmap-anydpi-v26/`), and iOS AppIcon asset catalogs (`AppIcon.appiconset`).
  - Standardized application display name to "TOTP Authenticator" in Android (`AndroidManifest.xml` `android:label`) and iOS (`Info.plist` `CFBundleDisplayName`).
- **Desktop UI Geometry & Visual Alignment Testing (`apps/ui`)**: Added automated geometry assertions in `test_ui_modern.py` verifying that toolbar buttons share identical vertical coordinates (`winfo_rooty()`), exact 28x28px dimensions, strictly ordered horizontal positions, vector icon caching, and inner wrapper padding isolating focus border colors.
- **Mobile Flutter Golden Visual Testing (`apps/mobile`)**: Established pixel-by-pixel visual snapshot testing pipeline using `matchesGoldenFile` for Mobile UI (`LockScreen`, `HomeScreen`, `SettingsScreen`), rendering baseline PNGs at 1080x1920 viewport to automatically catch visual layout regressions in CI/test runs.

### Changed
- **Mobile Modern Slate UI & Grouped Settings Overhaul (`apps/mobile`)**:
  - **Color Palette Synchronization**: Migrated mobile dark theme from legacy navy/neon cyan to Modern Slate (`#0B0F19` background, `#1E293B` card surface, `#334155` border, `#38BDF8` sky blue accent), achieving 100% visual consistency with the desktop app.
  - **Grouped Inset Settings Layout**: Reorganized `SettingsScreen` into distinct grouped cards with uppercase bold section headers (`ĐỒNG BỘ ĐÁM MÂY (E2EE)`, `BẢO MẬT & SINH TRẮC HỌC`, `THÔNG TIN HỆ THỐNG`).
  - **Clean Server Presets**: Replaced bulky debug buttons with an elegant, 1px bordered suggestion row (`Gợi ý: [Emulator] [Localhost]`).
  - **Material 3 Switch & 1px Outlined Inputs**: Styled biometric switch with high-contrast white thumb on sky blue track and inputs with crisp 1px borders and dynamic focus rings.
  - **Home Screen & Empty State Localization**: Replaced AppBar emoji with clean vector shield icon, updated Empty State with professional Vietnamese copy and glowing shield illustration, and restyled `+ Thêm tài khoản` FAB.

### Fixed
- **Mobile Info Card Text Truncations (`apps/mobile`)**: Fixed `RFC 623...`, `Fernet A...`, `PBKDF2 4...` text cutoffs on mobile viewports by switching detail rows to flexible expanded auto-wrapping without truncation.
- **Outdated App Version Display (`apps/mobile`)**: Synchronized Settings info card version to current release version.
- **Mobile LockScreen Text Overflow (`apps/mobile`)**: Fixed a 59px `RenderFlex` horizontal overflow in the LockScreen security reassurance footer on compact viewports by wrapping description text in `Flexible` with `TextOverflow.ellipsis`.
- **Desktop UI Polish & Border Artifacts (`apps/ui`)**:
  - **Input Focus Border Clean-up**: Fixed double vertical edge highlight artifacts in dialog input fields by wrapping entries in matching background inner frames, ensuring a sharp 1px border and smooth internal padding.
  - **Sidebar Action Buttons Dark Mode Colors**: Fixed `Rename` and `Delete` buttons turning stark white in Dark Mode after toggling themes by ensuring button hover bindings and palette updaters dynamically refresh to active theme colors (`surface`).
  - **Header Action Toolbar Alignment & Vector Icons**: Replaced misaligned text emoji buttons with a unified, pixel-aligned 28x28 toolbar featuring smooth anti-aliased vector icons (Cloud Sync, Settings, Theme Toggle) rendered with supersampled PIL graphics and interactive hover tooltips.


## [v0.8.1] - 2026-11-05
### Fixed
- **Mobile Biometric Infinite Unlock Loop (`apps/mobile`)**: Fixed an issue on Android where activating biometric protection or unlocking on the Lock Screen triggered an endless authentication loop:
  - Ignored `AppLifecycleState.inactive` and spurious pause events caused by the native `BiometricPrompt` system dialog overlay.
  - Added an active `_isAuthenticating` guard preventing lifecycle changes from marking the app as paused/backgrounded while biometric authentication is ongoing.
  - Added a post-unlock grace period ignoring immediate resume events after successful fingerprint verification.
  - Maintained a stable root `Stack` widget tree in `AuthGate`, preventing `LockScreen` from unnecessarily unmounting and re-triggering auto-prompt upon app resume.

## [v0.8.0] - 2026-11-05
### Changed
- **Modern Windows 11 Fluent UI Overhaul (`apps/ui`)**:
  - Replaced legacy palette with crisp Modern Slate (Dark `#0b0f19` / Light `#f8fafc`) high-contrast theme tokens.
  - Replaced rigid `tk.Listbox` with an elegant scrollable Card List featuring colored circular initial avatars, subtitles, selection stripes, and context menus.
  - Formatted OTP codes into split groups (`123  456`) and introduced an animated countdown progress bar dynamically shifting Green $\to$ Amber $\to$ Red.
  - Upgraded Copy button with interactive visual feedback (`✓ Copied to Clipboard!`).
  - Redesigned Empty State with a dedicated security shield illustration and prominent Add Account CTA.
  - Modernized all 4 dialogs (Add Account, Cloud Sync, Security Settings, Reset Vault) with 1px outlined entries, dynamic focus rings, and zero retro 3D bevels.

## [v0.7.1] - 2026-11-05
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
