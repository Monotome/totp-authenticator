# TOTP Authenticator

[![CI](https://github.com/SilvaHerald/totp-authenticator/actions/workflows/ci.yml/badge.svg)](https://github.com/SilvaHerald/totp-authenticator/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/downloads/)

A lightweight, **premium**, and **End-to-End Encrypted (E2EE)** TOTP authenticator for Windows. Keep your 2FA codes safe and synced across your devices without compromising privacy.

![TOTP Authenticator Demo](assets/demo.gif)

## ✨ Features

- 🔢 **Auto-refreshing 6-digit codes** — updates every 30 seconds.
- ☁️ **E2EE Cloud Sync (New!)** — Sync your secrets securely across devices. The server never sees your keys.
- 🔒 **Master Password Protection** — Optional encryption for your local configuration.
- 📥 **Import/Export** — Seamlessly import from `otpauth://` URIs or export encrypted backups.
- 📋 **One-click copy** — Copies code to clipboard instantly.
- 📌 **Always-on-top window** — Stays visible while you work.
- 🌗 **Premium Dark/Light UI** — Modern, clean aesthetic with smooth animations.

## 🚀 Getting Started

### Option 1: Download (Recommended)
Download the latest pre-built installer from [GitHub Releases](https://github.com/SilvaHerald/totp-authenticator/releases).

### Option 2: Run from Source
This project uses a **Monorepo** structure. The desktop application is located in `apps/ui`.

```bash
# Clone the repository
git clone https://github.com/SilvaHerald/totp-authenticator.git
cd totp-authenticator/apps/ui

# Setup environment (Windows)
python -m venv .venv
.venv\Scripts\activate

# Install dependencies
pip install -e .

# Run the app
totp-auth
```

## ☁️ Cloud Sync Backend
The Backend Sync Server is located in `apps/api`. You can use our default server or self-host your own using our [Docker instructions](apps/api/README.md).

## 🛠️ Development

```bash
# From the project root, navigate to the UI app
cd apps/ui

# Run tests
pytest tests/ -v

# Build executable (requires Nuitka + MSVC/MinGW)
python -m nuitka --standalone --enable-plugin=tk-inter --windows-console-mode=disable src/totp_authenticator/main.py
```

## 📦 Project Structure
We use a monorepo architecture:
- `apps/ui`: The Tkinter desktop application.
- `apps/api`: The FastAPI backend for cloud synchronization.

See [PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) for a full breakdown.

## 🗺️ Roadmap
Check out our [Roadmap](docs/ROADMAP.md) for v0.7.0 (Mobile App) and beyond.

## 📄 License
This project is licensed under the [MIT License](LICENSE).
