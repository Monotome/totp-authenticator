# 🤖 AGENTS.md — AI Agent Guidance & System Manual

Welcome to **TOTP Authenticator**. This file serves as the definitive reference manual for AI coding agents (Antigravity, Claude Code, Cursor, Copilot, etc.) operating on this repository.

Read this document carefully before making code modifications, proposing architectural changes, writing tests, or packaging applications.

---

## 1. 🧭 Project Overview & Mission

**TOTP Authenticator** is a lightweight, privacy-first, and **End-to-End Encrypted (E2EE)** two-factor authentication suite designed to generate and sync RFC 6238 / RFC 4226 2FA codes without compromising user privacy.

### Monorepo Architecture:
* **`apps/ui`**: Windows desktop app built with Python 3.10+, Tkinter, Cryptography, and packaged with Nuitka into a standalone `.exe`.
* **`apps/api`**: Cloud synchronization server built with FastAPI, async SQLAlchemy, Pydantic v2, and Docker.
* **`apps/mobile`**: Cross-platform companion mobile app built with Flutter (Dart), Provider, Biometrics, and QR Scanner.
* **Core Philosophy**: **Zero-Knowledge Architecture**. The sync server acts only as a blind encrypted blob storage. Master passwords, derived keys, and plaintext OTP secrets never leave the client device unencrypted.

---

## 2. 📁 Monorepo Layout & Directory Map

```text
totp-authenticator/
├── apps/
│   ├── ui/                         # 🖥️ Python Tkinter Desktop Client
│   │   ├── src/totp_authenticator/
│   │   │   ├── main.py             # Entry point & DPI initialization
│   │   │   ├── app.py              # Tkinter UI, event loop & tray coordination
│   │   │   ├── core.py             # Pure TOTP/HOTP calculation logic (NO UI / NO NET)
│   │   │   ├── crypto.py           # AES-256-GCM & PBKDF2 vault encryption
│   │   │   ├── storage.py          # Local encrypted configuration persistence
│   │   │   ├── api.py              # REST client communicating with sync backend
│   │   │   ├── sync_manager.py     # E2EE push/pull sync & conflict resolution
│   │   │   ├── parser.py           # otpauth:// URI parsing & validation
│   │   │   └── icon.py             # App & system tray icon assets
│   │   ├── tests/                  # Pytest test suite for desktop
│   │   └── pyproject.toml          # Desktop dependencies & tool settings
│   │
│   ├── api/                        # ☁️ Cloud Sync Server (FastAPI)
│   │   ├── src/server/
│   │   │   ├── main.py             # REST API routers (Auth & Vault sync)
│   │   │   ├── models.py           # SQLAlchemy ORM models (User, EncryptedVault)
│   │   │   ├── auth.py             # JWT generation, verification & bcrypt hashing
│   │   │   └── database.py         # Async database engine & session factory
│   │   ├── tests/                  # Pytest async API test suite
│   │   ├── Dockerfile              # Production multi-stage Docker container
│   │   ├── docker-compose.yml      # Local container orchestration
│   │   └── pyproject.toml          # API dependencies & tool settings
│   │
│   └── mobile/                     # 📱 Flutter Mobile Companion App
│       ├── lib/
│       │   ├── main.dart           # Flutter app entry & root Provider tree
│       │   ├── theme.dart          # Material 3 Dark/Light design tokens
│       │   ├── models/             # Data models (Account, Vault)
│       │   ├── providers/          # ChangeNotifier state management
│       │   ├── screens/            # Home, Add Account, QR Scan, Unlock screens
│       │   └── services/           # Biometric, secure storage, and OTP services
│       ├── test/                   # Flutter widget & unit tests
│       └── pubspec.yaml            # Flutter dependencies & assets
│
├── .agents/skills/                 # 🧠 Specialized Agent Skills
├── assets/                         # Static icons, graphics & demo gifs
├── docs/                           # Architecture docs, roadmap & milestones
├── skills-lock.json                # Agent skills registry & integrity lock
└── README.md                       # Public project documentation
```

---

## 3. 🛡️ Inviolable Core Commandments

Whenever modifying or generating code, AI agents **MUST** strictly adhere to these rules:

1. **Zero-Knowledge Integrity**:
   * The backend API must **NEVER** receive, process, or store unencrypted TOTP secrets, master passwords, or raw cryptographic keys.
   * All cryptographic encryption/decryption happens solely inside `apps/ui` or `apps/mobile`.
2. **Purity of `core.py`**:
   * `apps/ui/src/totp_authenticator/core.py` must remain **100% pure Python**. It must never import `tkinter`, `httpx`, or file I/O libraries.
3. **No File Pollution in Tests**:
   * Automated tests must **NEVER** read from or write to `~/.totp_config.json`. Always isolate storage tests using pytest's `tmp_path` fixture or mocking.
4. **Cryptographic Rigor**:
   * Always use **AES-256-GCM** with a fresh 12-byte random nonce (`os.urandom(12)`) per encryption operation. Nonces must never be reused.
   * Secret comparisons, token checks, and hashes must always use constant-time comparisons (`hmac.compare_digest`).
5. **Secrets in Logs**:
   * Never log Base32 secrets, raw passwords, or authorization tokens in console outputs, logging handlers, or UI dialogs.

---

## 4. 🧰 Agent Skills Activation Matrix

Specialized Agent Skills are stored in [`.agents/skills/`](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills). When handling relevant tasks, agents **MUST** read and apply the instructions from the respective `SKILL.md`:

### A. Security, Cryptography & Cloud Sync
| Skill Name | Path | Trigger & Use Cases |
| :--- | :--- | :--- |
| **`python-cryptography-security`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/python-cryptography-security/SKILL.md) | **Must use** when touching `crypto.py`, `storage.py`, `sync_manager.py`, or designing master password derivation, AEAD encryption, tamper-resistance, and memory zeroing. |
| **`fastapi-backend`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/fastapi-backend/SKILL.md) | **Must use** when editing `apps/api/`, writing Pydantic v2 schemas, async SQLAlchemy ORM queries, JWT auth, or Docker containerization. |

### B. Mobile & Desktop Engineering
| Skill Name | Path | Trigger & Use Cases |
| :--- | :--- | :--- |
| **`flutter-mobile-dev`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/flutter-mobile-dev/SKILL.md) | **Must use** for all tasks in `apps/mobile/` (Provider state management, `local_auth` biometrics, `mobile_scanner` QR codes, and `flutter_secure_storage`). |
| **`desktop-nuitka-packaging`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/desktop-nuitka-packaging/SKILL.md) | **Must use** when packaging the desktop app to `.exe`, handling Windows DPI scaling, Tcl/Tk DLL bundling, or managing system tray icon background threads. |

### C. Testing & Code Quality
| Skill Name | Path | Trigger & Use Cases |
| :--- | :--- | :--- |
| **`pytest-testing-patterns`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/pytest-testing-patterns/SKILL.md) | **Must use** when writing tests for `apps/ui/tests/` or `apps/api/tests/`, time-freezing TOTP 30s boundaries, mocking storage with `tmp_path`, or writing async API tests. |
| **`code-review`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/code-review/SKILL.md) | **Use** when reviewing PRs, unstaged changes, or validating whether code complies with repository standards and task specifications. |

### D. UI/UX Design & Polish
| Skill Name | Path | Trigger & Use Cases |
| :--- | :--- | :--- |
| **`ui-ux-pro-max`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/ui-ux-pro-max/SKILL.md) | **Use** for styling design systems, typography pairings, accessible color palettes, and component patterns across Tkinter and Flutter. |
| **`impeccable`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/impeccable/SKILL.md) | **Use** when auditing UI, polishing animations, fine-tuning visual hierarchy, and critiquing screen layouts. |
| **`frontend-design`** & **`ui-taste`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/frontend-design/SKILL.md) | **Use** to avoid generic, uninspired "AI-slop" aesthetics and enforce high craft standards in visual presentation. |

### E. Architecture, Ideation & Ecosystem
| Skill Name | Path | Trigger & Use Cases |
| :--- | :--- | :--- |
| **`brainstorming`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/brainstorming/SKILL.md) | **Must use** before starting creative work: adding major new features, architecting new components, or modifying UX behavior. |
| **`codebase-design`** & **`improve-codebase-architecture`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/codebase-design/SKILL.md) | **Use** when designing module boundaries, creating deep interfaces, or refactoring complex code (e.g., `app.py`). |
| **`find-skills`** | [SKILL.md](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/find-skills/SKILL.md) | **Use** when the user requests extending agent capabilities from the open agent skills ecosystem (`skills.sh`). |

---

## 5. 🛠️ Development Workflows & Cheatsheet

### 🖥️ Desktop Application (`apps/ui`)
* **Environment Setup**:
  ```powershell
  cd apps/ui
  .venv\Scripts\activate
  pip install -e ".[dev]"
  ```
* **Run App**:
  ```powershell
  totp-auth
  # OR: python src/totp_authenticator/main.py
  ```
* **Run Tests & Linting**:
  ```powershell
  pytest tests/ -v
  ruff check src/ tests/
  ruff check src/ tests/ --fix
  ```
* **Build Standalone `.exe`**:
  Consult [`.agents/skills/desktop-nuitka-packaging/SKILL.md`](file:///d:/Personal%20Projects/2026/topt-authenticator/.agents/skills/desktop-nuitka-packaging/SKILL.md) for compilation flags.

---

### ☁️ Cloud Sync Backend (`apps/api`)
* **Environment Setup**:
  ```powershell
  cd apps/api
  pip install -e ".[dev]"
  ```
* **Run Local Server**:
  ```powershell
  uvicorn server.main:app --reload --port 8000
  ```
* **Run API Tests**:
  ```powershell
  pytest tests/ -v
  ```
* **Docker Build**:
  ```powershell
  docker compose up --build -d
  ```

---

### 📱 Flutter Mobile App (`apps/mobile`)
* **Run Tests & Analysis**:
  ```powershell
  cd apps/mobile
  flutter test
  flutter analyze
  ```
* **Launch Mobile App**:
  ```powershell
  flutter run
  ```

---

## 6. 🚦 Agent Operational Checklist

Before completing any user request or committing changes:

1. **Linting Verification**: Ensure `ruff check` (for Python) or `flutter analyze` (for Flutter) returns zero errors or warnings.
2. **Test Validation**: Run the relevant `pytest` or `flutter test` command to guarantee all existing and newly authored tests pass.
3. **No Secret Leaks**: Verify that no real secret keys, private credentials, or auth tokens have been added to files or Git history.
4. **Skill Adherence**: Verify that changes adhere to the corresponding rules outlined in `.agents/skills/`.
