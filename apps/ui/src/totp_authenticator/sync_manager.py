"""Sync Manager — manages client-side encryption and push/pull sync operations."""

import base64
import json
import time
from dataclasses import asdict
from typing import Any

from totp_authenticator.api import AuthenticationError, ConflictError, SyncClient
from totp_authenticator.crypto import (
    InvalidPasswordError,
    decrypt_data,
    derive_key,
    encrypt_data,
    generate_salt,
)
from totp_authenticator.storage import Account, Settings, load_accounts, save_accounts

__all__ = ["ConflictError", "SyncManager"]


class SyncManager:
    def __init__(self, settings: Settings, sync_password: str):
        self.settings = settings
        self.sync_password = sync_password
        self.client = SyncClient(settings.sync_server_url)
        if settings.sync_token:
            self.client.set_token(settings.sync_token)

    def _pack_payload(self, current_key: bytes | None = None) -> str:
        """Encrypt all local accounts into a secure payload string."""
        accounts = load_accounts(current_key)
        accounts_json = json.dumps([asdict(a) for a in accounts])

        salt = generate_salt()
        key = derive_key(self.sync_password, salt)
        encrypted = encrypt_data(accounts_json, key)

        payload_dict = {
            "s": base64.urlsafe_b64encode(salt).decode("utf-8"),
            "d": encrypted,
        }
        return json.dumps(payload_dict)

    def _unpack_payload(self, payload_str: str) -> list[Account]:
        """Decrypt payload string back into Account objects."""
        try:
            payload_dict = json.loads(payload_str)
            salt = base64.urlsafe_b64decode(payload_dict["s"].encode("utf-8"))
            encrypted = payload_dict["d"]

            key = derive_key(self.sync_password, salt)
            accounts_json = decrypt_data(encrypted, key)
            accounts_data = json.loads(accounts_json)
            return [Account(**a) for a in accounts_data]
        except InvalidPasswordError:
            raise
        except Exception as e:
            raise ValueError(f"Failed to unpack payload: {e}") from e

    def push(self, current_key: bytes | None = None, force: bool = False) -> float:
        """Push encrypted local data to cloud. Returns the new last_updated."""
        if not self.settings.sync_server_url or not self.settings.sync_token:
            raise AuthenticationError("Not logged in to any Sync Server.")

        payload = self._pack_payload(current_key)
        last_updated = time.time()
        if force:
            try:
                remote_data = self.client.pull_sync_data()
                remote_ts = float(remote_data.get("last_updated", 0.0))
                last_updated = max(last_updated, remote_ts + 0.1)
            except Exception:
                pass

        resp = self.client.push_sync_data(payload, last_updated)
        return float(resp["last_updated"])

    def pull_and_merge(self, current_key: bytes | None = None) -> int:
        """Pull cloud data, decrypt, and merge with local data. Returns added account count."""
        if not self.settings.sync_server_url or not self.settings.sync_token:
            raise AuthenticationError("Not logged in to any Sync Server.")

        data = self.client.pull_sync_data()
        payload = data.get("encrypted_payload")

        if not payload:
            return 0  # Nothing on remote server yet

        cloud_accounts = self._unpack_payload(str(payload))
        local_accounts = load_accounts(current_key)

        # Merge deduplication: check both ID and normalized secret
        local_ids = {a.id for a in local_accounts}
        local_secrets = {a.secret.strip().upper() for a in local_accounts}

        added = 0
        for ca in cloud_accounts:
            if ca.id not in local_ids and ca.secret.strip().upper() not in local_secrets:
                local_accounts.append(ca)
                local_ids.add(ca.id)
                local_secrets.add(ca.secret.strip().upper())
                added += 1

        if added > 0:
            save_accounts(local_accounts, current_key)

        return added

    def pull(self, current_key: bytes | None = None) -> int:
        """Alias for pull_and_merge."""
        return self.pull_and_merge(current_key)

    def sync_now(self, current_key: bytes | None = None) -> dict[str, Any]:
        """Perform 2-way sync: Pull remote updates, merge locally, and push consolidated vault."""
        added = self.pull_and_merge(current_key)
        last_updated = self.push(current_key)
        return {"added": added, "last_updated": last_updated}

    def resolve_conflict_overwrite(self, current_key: bytes | None = None) -> float:
        """Force overwrite cloud data with local data."""
        return self.push(current_key, force=True)
