---
name: pytest-testing-patterns
description: Pytest, mocking, and TDD testing patterns for TOTP Authenticator, covering 30-second TOTP boundary testing, time-freezing, isolated filesystem fixtures, crypto roundtrip validation, and async FastAPI testing.
---

# Pytest & Testing Patterns Skill

This skill provides best practices, fixtures, and patterns for testing the **TOTP Authenticator** ecosystem (desktop UI logic and backend API).

---

## 1. Time-Freezing & TOTP Boundary Testing

TOTP codes rotate every 30 seconds (`time.time() // 30`). Testing must cover boundary transitions (e.g. at 29s, 30s, and 59s).

### Using `unittest.mock.patch("time.time")`:
```python
import pytest
from unittest.mock import patch
from totp_authenticator.core import get_code, get_remaining_seconds

SECRET = "JBSWY3DPEHPK3PXP"  # Standard RFC 6238 test secret

def test_totp_code_stable_within_window():
    # Freeze time at epoch 1000 and 1020 (same 30s window: 1000 // 30 == 33)
    with patch("time.time", return_value=1000.0):
        code_1 = get_code(SECRET)
        remaining_1 = get_remaining_seconds()

    with patch("time.time", return_value=1020.0):
        code_2 = get_code(SECRET)
        remaining_2 = get_remaining_seconds()

    assert code_1 == code_2
    assert remaining_1 == 20
    assert remaining_2 == 30 - (1020 % 30)

def test_totp_code_changes_across_window():
    with patch("time.time", return_value=1019.0):
        code_before = get_code(SECRET)

    with patch("time.time", return_value=1020.0):
        code_after = get_code(SECRET)

    assert code_before != code_after
```

---

## 2. Filesystem & Storage Isolation

**Rule**: Never write to `~/.totp_config.json` during automated test runs. Use pytest's built-in `tmp_path` fixture.

```python
import json
import pytest
from totp_authenticator import storage

@pytest.fixture
def isolated_storage(tmp_path, monkeypatch):
    """Direct storage.CONFIG_PATH to a temporary file."""
    fake_config = tmp_path / "test_totp_config.json"
    monkeypatch.setattr(storage, "CONFIG_PATH", str(fake_config))
    return fake_config

def test_save_and_load_secret(isolated_storage):
    assert storage.load_secret() == ""
    storage.save_secret("MYSECRETBASE32")
    assert storage.load_secret() == "MYSECRETBASE32"
    
    # Verify file content format
    with open(isolated_storage, "r") as f:
        data = json.load(f)
    assert data["secret"] == "MYSECRETBASE32"
```

---

## 3. Cryptography & Tamper Resistance Tests

Verify that encrypted secrets cannot be decrypted if tampered with:

```python
import pytest
from totp_authenticator.crypto import encrypt_data, decrypt_data

def test_encryption_roundtrip():
    secret = "JBSWY3DPEHPK3PXP"
    password = "CorrectHorseBatteryStaple!"
    
    encrypted = encrypt_data(secret, password)
    decrypted = decrypt_data(encrypted, password)
    assert decrypted == secret

def test_decryption_with_wrong_password():
    secret = "JBSWY3DPEHPK3PXP"
    encrypted = encrypt_data(secret, "passwordA")
    
    with pytest.raises(ValueError, match="Decryption failed"):
        decrypt_data(encrypted, "passwordB")

def test_tampered_ciphertext_fails():
    secret = "JBSWY3DPEHPK3PXP"
    encrypted = bytearray(encrypt_data(secret, "passwordA"))
    
    # Flip one byte in the ciphertext payload
    encrypted[-1] ^= 0xFF
    
    with pytest.raises(ValueError):
        decrypt_data(bytes(encrypted), "passwordA")
```

---

## 4. Async FastAPI Testing with HTTPX

Test FastAPI endpoints asynchronously without opening actual network ports:

```python
import pytest
from httpx import AsyncClient, ASGITransport
from server.main import app

@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

---

## 5. Execution Flags & Best Practices

```bash
# Run tests with verbose output and coverage
pytest tests/ -v --tb=short

# Run only crypto tests
pytest tests/test_crypto.py -v

# Run with warnings treated as errors (recommended for CI)
pytest -W error
```
