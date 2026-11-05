---
name: release
description: End-to-end release automation and guidelines for TOTP Authenticator, covering semantic versioning, changelog generation, cross-platform version synchronization, git tagging, and GitHub Actions CI/CD release builds.
---

# 🚀 Release Engineering Skill

This skill defines the official release process, version synchronization rules, pre-flight verification checks, and automated CI/CD release workflows for **TOTP Authenticator**.

---

## 1. 🧭 Release Overview & Architecture

TOTP Authenticator follows [Semantic Versioning 2.0.0](https://semver.org/) (`MAJOR.MINOR.PATCH`).
The release workflow is anchored by Git tags (`v*`) and executed automatically via GitHub Actions:

```text
Local / Agent Prep
  ├── Run tests & linters (Desktop, API, Mobile)
  ├── Sync version numbers across monorepo projects
  ├── Update CHANGELOG.md (Keep a Changelog format)
  └── Commit release changes to main
         │
         ▼
Tag & Push Trigger
  └── git tag -a vX.Y.Z -m "Release vX.Y.Z"
  └── git push origin vX.Y.Z
         │
         ▼
GitHub Actions (.github/workflows/release.yml)
  ├── Setup Python 3.12 on windows-latest
  ├── Compile standalone binary with Nuitka (totp-auth.exe)
  ├── Package ZIP: TOTP-Authenticator-vX.Y.Z-windows.zip
  └── Publish GitHub Release with auto-generated release notes
```

---

## 2. 🚦 Pre-Flight Quality Gates

Before cutting any release tag, **ALL** quality checks across all sub-apps must pass without error:

### A. Run Desktop Tests & Lint (`apps/ui`)
```powershell
cd apps/ui
$env:PYTHONPATH="src"
pytest tests/ -v
ruff check src/ tests/
```

### B. Run Cloud Sync API Tests & Lint (`apps/api`)
```powershell
cd apps/api
pytest tests/ -v
ruff check src/ tests/
```

### C. Run Mobile Tests & Analysis (`apps/mobile`)
```powershell
cd apps/mobile
flutter test
flutter analyze
```

---

## 3. 📂 Monorepo Version Synchronization

A release requires synchronizing version strings across the monorepo:

| Project | File Path | Version Field |
| :--- | :--- | :--- |
| **Desktop Client** | [`apps/ui/pyproject.toml`](file:///d:/Personal%20Projects/2026/topt-authenticator/apps/ui/pyproject.toml) | `version = "X.Y.Z"` |
| **Desktop Source** | [`apps/ui/src/totp_authenticator/__init__.py`](file:///d:/Personal%20Projects/2026/topt-authenticator/apps/ui/src/totp_authenticator/__init__.py) | `__version__ = "X.Y.Z"` |
| **Cloud API** | [`apps/api/pyproject.toml`](file:///d:/Personal%20Projects/2026/topt-authenticator/apps/api/pyproject.toml) | `version = "X.Y.Z"` |
| **Mobile App** | [`apps/mobile/pubspec.yaml`](file:///d:/Personal%20Projects/2026/topt-authenticator/apps/mobile/pubspec.yaml) | `version: X.Y.Z+<build_number>` |
| **Changelog** | [`CHANGELOG.md`](file:///d:/Personal%20Projects/2026/topt-authenticator/CHANGELOG.md) | `## [vX.Y.Z] - YYYY-MM-DD` |

---

## 4. 📝 Changelog Maintenance Standards

Always follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):
- Move items under `## [Unreleased]` into the new version section.
- Use standard sub-headings:
  - `### Added`: New user-facing features or capabilities.
  - `### Changed`: Changes in existing functionality or UI redesign.
  - `### Fixed`: Bug fixes, security remediations.
  - `### Security`: Cryptographic changes, dependency vulnerability patches.
  - `### Removed`: Deprecated or removed capabilities.

Example entry:
```markdown
## [v0.7.0] - 2026-11-05
### Added
- **Mobile Companion App**: Initial multi-platform Flutter application for Android & iOS.
- **Camera QR Scanner**: Real-time camera QR scanning with `mobile_scanner`, custom HUD reticle, and laser scan animation.
- **Live OTP Preview**: 6-digit real-time code confirmation sheet prior to saving accounts.
- **URI & Manual Import**: Fast parsing of `otpauth://` links and setup keys.
```

---

## 5. 🛠️ Execution Playbook: Cutting a Release

### Step 1: Ensure `main` is clean and up to date
```powershell
git checkout main
git pull origin main
git status
```

### Step 2: Update Version Strings & CHANGELOG.md
Update the files listed in Section 3 and Section 4.

### Step 3: Commit the Release Preparation
```powershell
git add CHANGELOG.md apps/ui/pyproject.toml apps/ui/src/totp_authenticator/__init__.py apps/mobile/pubspec.yaml
git commit -m "chore(release): prepare release vX.Y.Z"
```

### Step 4: Push `main` to Remote
```powershell
git push origin main
```

### Step 5: Create and Push Annotated Git Tag
```powershell
# Create annotated tag with summary
git tag -a vX.Y.Z -m "Release vX.Y.Z: <Short Highlights>"

# Push tag to GitHub to trigger CI/CD release workflow
git push origin vX.Y.Z
```

### Step 6: Monitor GitHub Actions Build
1. Open GitHub Actions: `https://github.com/SilvaHerald/totp-authenticator/actions`.
2. Inspect the **Release** workflow run.
3. Once completed (~5-8 minutes), verify that the release package appears under:
   `https://github.com/SilvaHerald/totp-authenticator/releases/tag/vX.Y.Z`
4. Verify asset download: `TOTP-Authenticator-vX.Y.Z-windows.zip`.

---

## 6. 🔄 Hotfix & Tag Rollback Emergency Procedures

### If a Tag was Created Incorrectly Locally (Before Push):
```powershell
git tag -d vX.Y.Z
```

### If a Tag was Already Pushed to Remote:
```powershell
# 1. Delete local tag
git tag -d vX.Y.Z

# 2. Delete remote tag
git push --delete origin vX.Y.Z

# 3. Manually delete the draft or faulty Release on GitHub web UI if already created
```

### Cutting a Hotfix (`vX.Y.(Z+1)`):
1. Checkout a fix branch off main: `git checkout -b fix/<bug-name>`.
2. Fix the bug, write regression tests, ensure all tests pass.
3. Merge into `main`.
4. Follow the standard release playbook to tag `vX.Y.(Z+1)`.
