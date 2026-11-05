import json
import time
from dataclasses import asdict

from totp_authenticator.api import AuthenticationError, SyncClient
from totp_authenticator.crypto import (
    decrypt_data,
    derive_key,
    encrypt_data,
    generate_salt,
)
from totp_authenticator.storage import Account, Settings, load_accounts, save_accounts


class SyncManager:
    def __init__(self, settings: Settings, sync_password: str):
        self.settings = settings
        self.sync_password = sync_password
        self.client = SyncClient(settings.sync_server_url)
        if settings.sync_token:
            self.client.set_token(settings.sync_token)

    def _pack_payload(self) -> str:
        """Encrypt all local accounts into a secure payload string."""
        accounts = load_accounts()
        accounts_json = json.dumps([asdict(a) for a in accounts])

        salt = generate_salt()
        key = derive_key(self.sync_password, salt)
        encrypted = encrypt_data(accounts_json, key)

        # We store salt and encrypted data as JSON, then return string
        import base64
        payload_dict = {
            "s": base64.urlsafe_b64encode(salt).decode("utf-8"),
            "d": encrypted
        }
        return json.dumps(payload_dict)

    def _unpack_payload(self, payload_str: str) -> list[Account]:
        """Decrypt payload string back into Account objects."""
        import base64
        try:
            payload_dict = json.loads(payload_str)
            salt = base64.urlsafe_b64decode(payload_dict["s"].encode("utf-8"))
            encrypted = payload_dict["d"]

            key = derive_key(self.sync_password, salt)
            accounts_json = decrypt_data(encrypted, key)
            accounts_data = json.loads(accounts_json)
            return [Account(**a) for a in accounts_data]
        except Exception as e:
            raise ValueError(f"Failed to unpack payload: {e}") from e

    def push(self) -> float:
        """Push encrypted local data to cloud. Returns the new last_updated."""
        if not self.settings.sync_server_url or not self.settings.sync_token:
            raise AuthenticationError("Not logged in to any Sync Server.")

        payload = self._pack_payload()
        last_updated = time.time()

        resp = self.client.push_sync_data(payload, last_updated)
        return resp["last_updated"]

    def pull_and_merge(self) -> float:
        """Pull cloud data, decrypt, and merge with local data. Returns last_updated."""
        if not self.settings.sync_server_url or not self.settings.sync_token:
            raise AuthenticationError("Not logged in to any Sync Server.")

        data = self.client.pull_sync_data()
        payload = data.get("encrypted_payload")
        server_last_updated = data.get("last_updated", 0.0)

        if not payload:
            return server_last_updated # Nothing to pull

        cloud_accounts = self._unpack_payload(payload)
        local_accounts = load_accounts()

        # Merge: simple deduplication by ID
        local_ids = {a.id for a in local_accounts}
        added = 0
        for ca in cloud_accounts:
            if ca.id not in local_ids:
                local_accounts.append(ca)
                added += 1

        if added > 0:
            save_accounts(local_accounts)

        return server_last_updated
