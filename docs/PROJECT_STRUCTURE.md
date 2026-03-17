# 📦 Project Structure

The project follows a **Monorepo** architecture to separate the Desktop Client from the Cloud Sync Backend.

```text
totp-authenticator/
├── apps/
│   ├── ui/                 # 🖥️ Desktop Application (Frontend)
│   │   ├── src/totp_authenticator/
│   │   │   ├── main.py     # Application entry point
│   │   │   ├── app.py      # Main UI (tkinter) & event handling
│   │   │   ├── api.py      # Backend API communication client
│   │   │   ├── sync_manager.py # E2EE Sync logic (Push/Pull/Merge)
│   │   │   ├── storage.py  # Multi-account data persistence
│   │   │   └── core.py     # TOTP code generation logic
│   │   ├── tests/          # Unit tests for UI and core logic
│   │   └── pyproject.toml  # Desktop app configuration & dependencies
│   │
│   └── api/                # ☁️ Cloud Sync Server (Backend)
│       ├── src/server/     # FastAPI application source
│       │   ├── main.py     # REST API endpoints & Last-Write-Wins logic
│       │   ├── models.py   # Database schema (SQLAlchemy)
│       │   ├── auth.py     # JWT & Bcrypt security handling
│       │   └── database.py # SQLite connection engine
│       ├── tests/          # API endpoint testing
│       ├── Dockerfile      # Production container build
│       └── pyproject.toml  # Backend configuration & dependencies
│
├── docs/                   # 📄 ROADMAP & Implementation plans
├── .github/workflows/      # 🤖 Automated CI/CD pipelines
│   ├── ci.yml              # Multi-version check for monorepo
│   └── release.yml         # Automated Nuitka builds & GitHub Releases
└── README.md               # Main project overview
```
