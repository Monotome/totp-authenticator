---
name: fastapi-backend
description: Best practices for building, testing, and containerizing the FastAPI Cloud Sync server for TOTP Authenticator, covering Pydantic v2 schemas, async SQLAlchemy ORM, JWT authentication, and Docker deployment.
---

# FastAPI Backend & Cloud Sync Skill

This skill defines development standards for **`apps/api`**, the Cloud Synchronization server providing Zero-Knowledge encrypted vault sync for the TOTP Authenticator ecosystem.

---

## 1. Zero-Knowledge API Design

* **Encrypted Blobs Only**: The API must **never** accept or store unencrypted TOTP secrets or passwords.
* **Payload Structure**:
  ```json
  {
    "vault_version": 2,
    "encrypted_payload": "<base64_encoded_aes_gcm_ciphertext>",
    "salt": "<base64_encoded_kdf_salt>",
    "updated_at": "2026-11-05T12:00:00Z"
  }
  ```
* The server's responsibility is solely user authentication, version conflict resolution, and timestamped ciphertext storage.

---

## 2. Pydantic v2 Guidelines

Use modern Pydantic v2 syntax:

```python
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator

class VaultSyncRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    vault_version: int = Field(..., ge=1, description="Monotonically increasing version number")
    encrypted_payload: str = Field(..., min_length=24, description="Base64 ciphertext + tag")
    salt: str = Field(..., min_length=16, description="Base64 salt for PBKDF2/Argon2")

    @field_validator("encrypted_payload")
    @classmethod
    def validate_payload_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Encrypted payload cannot be empty")
        return v
```

---

## 3. Async SQLAlchemy 2.0 & Session Management

Always use modern async SQLAlchemy patterns with dependency injection:

```python
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

engine = create_async_engine(
    "sqlite+aiosqlite:///./sync.db",
    echo=False,
    future=True
)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

---

## 4. Authentication & Security (JWT + Bcrypt)

* **Password Hashing**: Hash user account passwords using `bcrypt` (work factor 12+).
* **JWT Claims**: Store only minimal claims (`sub` = user_id, `exp`, `iat`). Never store sensitive metadata in JWT claims.
* **Rate Limiting**: Protect `/auth/login` and `/auth/register` against brute-force attacks.

```python
import jwt
from datetime import datetime, timedelta, timezone

SECRET_KEY = "..." # Loaded from environment variable, never hardcoded
ALGORITHM = "HS256"

def create_access_token(user_id: str, expires_delta: timedelta = timedelta(days=7)) -> str:
    expire = datetime.now(timezone.utc) + expires_delta
    payload = {"sub": str(user_id), "exp": expire, "iat": datetime.now(timezone.utc)}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
```

---

## 5. Dockerization & Deployment

* Use multi-stage builds in [Dockerfile](file:///d:/Personal%20Projects/2026/topt-authenticator/apps/api/Dockerfile) to minimize image footprint.
* Run the container as a non-privileged user:
  ```dockerfile
  RUN adduser --disabled-password --gecos '' appuser
  USER appuser
  ```
* Standard run command:
  ```bash
  uvicorn server.main:app --host 0.0.0.0 --port 8000 --workers 2
  ```

---

## 6. Daily Testing Commands

From `apps/api`:
```bash
pytest tests/ -v                   # Run test suite
ruff check src/ tests/             # Lint check
ruff check src/ tests/ --fix       # Auto-fix lint issues
```
