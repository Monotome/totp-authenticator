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

## 5. Critical Action Re-Authentication (Sudo Mode) & Threat Modeling

In authenticator and password management applications, simply being in an "unlocked" state does **NOT** grant carte blanche permission to execute security-altering operations. 

### Why Sudo Mode is Mandatory
If a user leaves their computer unattended at an office or public space with TOTP Authenticator open, an opportunistic adversary or malicious process could:
- Change the Master Password to lock out the legitimate owner.
- Remove password protection, leaving all TOTP secrets unencrypted in plaintext on disk.
- Export all 2FA accounts to an unencrypted or attacker-controlled backup file.

### Required Invariants for Sensitive Operations:
1. **Always Verify Current Credentials First**:
   - When changing a password: must supply `old_password`, verify against disk/salt via `verify_password(old_password)` before calling `set_encryption(new_password)`.
   - When disabling encryption: must prompt for `current_password` via secure modal, verify with `verify_password()`, and only then execute `remove_encryption()`.
   - When exporting or restoring data: require dedicated passphrase entry.
2. **Double Confirmation & Strength Constraints**:
   - Enforce a minimum password length of $\ge 6$ characters (recommended $\ge 8$).
   - Always require a "Confirm Password" field matching `new_password`.
3. **Constant-Time Verification**:
   - Re-authenticating must decrypt ciphertext or derive key and compare using constant-time digest comparison (`hmac.compare_digest`).
4. **Adversary Threat Modeling Questions (Run before finalizing code)**:
   - *Can this action be invoked without re-authenticating the current user?*
   - *What happens if the current password is empty, incorrect, or mismatched? Does it abort immediately without partial state changes?*
   - *Is the plaintext secret exposed in any alert, toast, or exception message?*
   - *Are negative/abuse unit tests written asserting that unauthorized requests fail?*

---

## 6. Security Checklist for Code Review

- [ ] **Sudo Mode / Re-Authentication**: Does any password change, encryption removal, or vault reset require entering and verifying the current master password?
- [ ] **Strength & Confirmation**: Are new passwords verified for minimum length ($\ge 6$ chars) and double-checked against a confirmation field?
- [ ] **No Secret Leaks**: Does any endpoint, dialog, or logging call leak Base32 secrets, raw passwords, or derived encryption keys?
- [ ] **Timing Attack Immunity**: Is `hmac.compare_digest` or `verify_password` used for comparing secrets, tokens, or hashes?
- [ ] **Cryptographic Rigor**: Is a fresh random nonce (12 bytes, `os.urandom(12)`) generated for *every* encryption operation? Nonce reuse is strictly prohibited.
- [ ] **Graceful Exception Handling**: Are cryptography exceptions (`InvalidTag`, `InvalidPasswordError`) caught without leaking stack traces or raw payloads?
- [ ] **Storage Isolation & Permissions**: Are permissions on local config files restricted to the current user (Windows ACLs / POSIX 0600) and isolated with `tmp_path` in all tests?
- [ ] **Negative & Abuse Tests**: Are automated tests written asserting rejection of invalid/missing current passwords, mismatched passwords, and short passwords?
