---
name: python-cryptography-security
description: Security, cryptography, and zero-knowledge E2EE standards for the TOTP Authenticator, covering AES-256-GCM encryption, PBKDF2/Argon2 key derivation, constant-time validation, and secure in-memory handling of 2FA secrets.
---

# Python Cryptography & Zero-Knowledge Security Skill

This skill governs all cryptographic operations, data security, and Zero-Knowledge End-to-End Encryption (E2EE) implementations in the **TOTP Authenticator** project (both desktop and API communications).

---

## 1. Core Principles

1. **Zero-Knowledge Architecture**: The sync server must never receive or store plaintext secrets, keys, or passwords. All encryption and decryption must occur entirely on the client side (desktop app or mobile app).
2. **Authenticated Encryption (AEAD)**: Always use AEAD ciphers like **AES-256-GCM** or **ChaCha20-Poly1305**. Never use ECB or CBC without HMAC (unauthenticated ciphers).
3. **Nonce / IV Uniqueness**: Never reuse an Initialization Vector (IV) / Nonce under the same key. A fresh 12-byte (96-bit) cryptographically secure random nonce must be generated for every encryption operation (`os.urandom(12)`).
4. **Timing Attack Immunity**: Token comparisons, OTP validations, and hash checks must always use constant-time comparisons (`hmac.compare_digest`).

---

## 2. Key Derivation (PBKDF2 / Argon2id)

When deriving an encryption key from a Master Password:

```python
import os
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

def derive_key(master_password: str, salt: bytes) -> bytes:
    """
    Derive a 256-bit key from the master password using PBKDF2-HMAC-SHA256.
    Salt must be at least 16 bytes, randomly generated via os.urandom(16).
    """
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,          # 256 bits
        salt=salt,
        iterations=600_000, # Follow OWASP recommendations (>= 600,000 for SHA256)
    )
    return kdf.derive(master_password.encode("utf-8"))
```

* **Salt Storage**: Salt is public and must be stored alongside the ciphertext (e.g. prepended to the encrypted payload or in config).
* **Never hardcode salts or keys.**

---

## 3. AES-256-GCM Encryption & Decryption

Use `cryptography.hazmat.primitives.ciphers.aead.AESGCM`:

```python
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag

def encrypt_payload(data: bytes, key: bytes, associated_data: bytes = None) -> bytes:
    """
    Returns: salt (16 bytes, if applicable) + nonce (12 bytes) + ciphertext + tag (16 bytes appended by AESGCM).
    """
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)  # 96-bit IV
    ciphertext = aesgcm.encrypt(nonce, data, associated_data)
    return nonce + ciphertext

def decrypt_payload(encrypted_blob: bytes, key: bytes, associated_data: bytes = None) -> bytes:
    """
    Extracts nonce (first 12 bytes) and decrypts the remaining ciphertext.
    Raises InvalidTag if tampered with or if wrong key is supplied.
    """
    if len(encrypted_blob) < 12 + 16:
        raise ValueError("Invalid ciphertext length: payload is too short.")
    
    nonce = encrypted_blob[:12]
    ciphertext = encrypted_blob[12:]
    aesgcm = AESGCM(key)
    try:
        return aesgcm.decrypt(nonce, ciphertext, associated_data)
    except InvalidTag as e:
        raise ValueError("Decryption failed: corrupted data or invalid password.") from e
```

---

## 4. TOTP & Secret Hygiene

1. **Base32 Hygiene**:
   * Strip spaces, hyphens, and convert to uppercase before validating:
     ```python
     clean_secret = secret.replace(" ", "").replace("-", "").upper()
     ```
   * Pad with `=` to a multiple of 8 if missing before Base32 decoding.
2. **Memory Safety**:
   * Never output the Base32 secret or derived encryption key in log files (`logging.info/debug`), error messages, exception tracebacks, or UI toast notifications.
   * Clear clipboard content after 30 seconds to reduce exposure to other running Windows/Android processes.
3. **Backup Export/Import**:
   * Encrypted backup files must include:
     - `version`: Integer format version (e.g. `1`).
     - `kdf`: Algorithm parameters (`{"algo": "pbkdf2", "iterations": 600000, "hash": "sha256"}`).
     - `salt`: Base64-encoded salt.
     - `payload`: Base64-encoded AES-GCM ciphertext.

---

## 5. Security Checklist for Code Review

- [ ] Does any endpoint or logging call log the plaintext secret or password?
- [ ] Is `hmac.compare_digest` used for comparing secrets or hashes?
- [ ] Is a fresh random nonce (12 bytes) generated for *every* encryption?
- [ ] Are exceptions caught gracefully without displaying stack traces that might leak secrets?
- [ ] Are permissions on local config files restricted to current user (Windows ACLs / POSIX 0600)?
