# Roadmap

This document outlines the planned features and improvements for TOTP Authenticator.
Items are loosely prioritized within each milestone.

> **Note:** This roadmap is aspirational. Timelines are not guaranteed.
> Have a feature idea? [Open an issue](https://github.com/SilvaHerald/totp-authenticator/issues)!

---

## ✅ v0.1.0 — Initial Release (Current)

- [x] Auto-refreshing 6-digit TOTP codes (30-second window)
- [x] Countdown timer with color change when expiring
- [x] One-click copy to clipboard
- [x] Persistent secret key storage
- [x] Always-on-top window mode
- [x] Unit tests for core logic and storage
- [x] CI/CD pipeline with GitHub Actions
- [x] Automated release builds with Nuitka

---

## 🔭 v0.2.0 — Multi-Account Support

- [x] Store and manage multiple TOTP accounts
- [x] Display a list of accounts with their live codes
- [x] Add / rename / delete accounts
- [ ] Import accounts via QR code scan or `otpauth://` URI (moved to v0.5)

---

## 🎨 v0.3.0 — UX Polish

- [x] System tray integration (minimize to tray)
- [x] Light / dark theme toggle
- [x] Custom window size and position persistence
- [x] Keyboard shortcuts (copy code, switch account)

---

## 🔒 v0.4.0 — Security Hardening

- [x] Optional PIN / password lock on app open
- [x] Encrypt stored secrets at rest
- [x] Auto-lock after inactivity timeout

---

## 📥 v0.5.0 — Import & Protocol Support

- [x] Import accounts via `otpauth://` URI (clipboard/text)
- [x] Export accounts as encrypted backup file
- [x] Restore accounts from backup file

---

## ☁️ v0.6.0 — Cloud Sync (E2EE)

> Secrets are encrypted end-to-end before leaving the device — the server never sees plaintext keys.

- [x] Account system (sign up / log in) for sync identity
- [x] End-to-end encrypted secret sync across devices
- [x] Default hosted sync server (free tier)
- [x] Self-hosted sync server support (open source backend)
- [x] Conflict resolution for multi-device edits

---

## 📱 v0.7.0 — Mobile App (Android & iOS)

- [x] Flutter-based companion app (single codebase for Android + iOS)
- [x] QR code scanner to add accounts on mobile
- [x] Live OTP display with countdown timer (mirrors desktop experience)
- [ ] Sync with desktop via v0.6 cloud sync backend
- [ ] Biometric lock (fingerprint / Face ID)

---

## 📦 v1.0.0 — Stable Release

- [ ] Desktop + mobile feature parity stabilized
- [ ] Comprehensive documentation and user guide
- [ ] Signed Windows installer (`.exe`)
- [ ] macOS desktop build support
- [ ] Published to Google Play Store and Apple App Store

---

## 💡 Ideas Backlog (No ETA)

These are ideas that have been raised but not yet scheduled:

- Browser extension integration
- TOTP token search / filter
- Localization / i18n support
- Watch app (Wear OS / watchOS)
