"""Unit tests for SyncManager: E2EE packing/unpacking, push, pull, and 2-way sync."""

import json
from unittest.mock import MagicMock, patch

import pytest

from totp_authenticator.api import AuthenticationError
from totp_authenticator.crypto import InvalidPasswordError
from totp_authenticator.storage import (
    Account,
    Settings,
    add_account,
    load_accounts,
    set_encryption,
)
from totp_authenticator.sync_manager import SyncManager

VALID_SECRET = "JBSWY3DPEHPK3PXP"
VALID_SECRET_2 = "HXDMVJXTZSE6IKQK"


@pytest.fixture(autouse=True)
def patch_config(tmp_path, monkeypatch):
    """Isolate config file for each test in temp directory."""
    cfg = tmp_path / ".totp_config.json"
    monkeypatch.setattr("totp_authenticator.storage.CONFIG_FILE", str(cfg))
    return cfg


def test_pack_and_unpack_payload_unencrypted_storage():
    """Verify that SyncManager can pack local plaintext accounts and unpack them cleanly."""
    add_account("GitHub", VALID_SECRET)
    add_account("Google", VALID_SECRET_2)

    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-123")
    manager = SyncManager(settings, sync_password="vault-password-xyz")

    payload = manager._pack_payload()
    assert isinstance(payload, str)

    payload_data = json.loads(payload)
    assert "s" in payload_data
    assert "d" in payload_data

    # Unpack with same password
    restored = manager._unpack_payload(payload)
    assert len(restored) == 2
    assert restored[0].name == "GitHub"
    assert restored[1].name == "Google"


def test_pack_and_unpack_payload_encrypted_storage():
    """Verify that SyncManager works when local storage is encrypted with a master password."""
    master_key = set_encryption("local-master-password")
    add_account("EncryptedAccount", VALID_SECRET, key=master_key)

    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-123")
    sync_manager = SyncManager(settings, sync_password="cloud-sync-password")

    # Packing requires passing current_key
    payload = sync_manager._pack_payload(current_key=master_key)
    restored = sync_manager._unpack_payload(payload)

    assert len(restored) == 1
    assert restored[0].name == "EncryptedAccount"


def test_unpack_with_wrong_password_raises_invalid_password():
    """Verify that decrypting with the wrong sync password fails."""
    add_account("Sensitive", VALID_SECRET)
    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-123")
    manager = SyncManager(settings, sync_password="correct-password")
    payload = manager._pack_payload()

    wrong_manager = SyncManager(settings, sync_password="wrong-password")
    with pytest.raises(InvalidPasswordError):
        wrong_manager._unpack_payload(payload)


def test_push_success():
    """Verify push uploads packed encrypted payload to SyncClient."""
    add_account("GitHub", VALID_SECRET)
    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-token")
    manager = SyncManager(settings, sync_password="sync-pass")

    manager.client = MagicMock()
    manager.client.push_sync_data.return_value = {"message": "ok", "last_updated": 12345.67}

    res_ts = manager.push()
    assert res_ts == 12345.67
    manager.client.push_sync_data.assert_called_once()
    payload_arg, ts_arg = manager.client.push_sync_data.call_args[0]
    assert isinstance(payload_arg, str)
    assert isinstance(ts_arg, float)


def test_pull_and_merge_deduplicates():
    """Verify pull_and_merge merges remote accounts without duplicating existing ones."""
    # Local has GitHub
    add_account("GitHub", VALID_SECRET)

    # Cloud has GitHub AND Discord
    remote_accounts = [
        Account(id="id-1", name="GitHub", secret=VALID_SECRET),
        Account(id="id-2", name="Discord", secret=VALID_SECRET_2),
    ]

    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-token")
    manager = SyncManager(settings, sync_password="sync-pass")

    # Mock client pull
    with patch.object(manager, "_unpack_payload", return_value=remote_accounts):
        manager.client = MagicMock()
        manager.client.pull_sync_data.return_value = {
            "encrypted_payload": "mock-payload",
            "last_updated": 99999.0,
        }

        added = manager.pull_and_merge()
        assert added == 1  # Only Discord was added

        local = load_accounts()
        assert len(local) == 2
        names = [a.name for a in local]
        assert "GitHub" in names
        assert "Discord" in names


def test_pull_alias():
    """Verify manager.pull() is an alias to pull_and_merge()."""
    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-token")
    manager = SyncManager(settings, sync_password="sync-pass")

    with patch.object(manager, "pull_and_merge", return_value=3) as mock_pull:
        added = manager.pull()
        assert added == 3
        mock_pull.assert_called_once_with(None)


def test_sync_now_two_way_sync():
    """Verify sync_now executes pull_and_merge followed by push."""
    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-token")
    manager = SyncManager(settings, sync_password="sync-pass")

    with (
        patch.object(manager, "pull_and_merge", return_value=2) as mock_pull,
        patch.object(manager, "push", return_value=123456.78) as mock_push,
    ):
        res = manager.sync_now()
        assert res == {"added": 2, "last_updated": 123456.78}
        mock_pull.assert_called_once_with(None)
        mock_push.assert_called_once_with(None)


def test_resolve_conflict_overwrite():
    """Verify resolve_conflict_overwrite calls push with force=True."""
    settings = Settings(sync_server_url="http://mock-server:8000", sync_token="jwt-token")
    manager = SyncManager(settings, sync_password="sync-pass")

    with patch.object(manager, "push", return_value=77777.0) as mock_push:
        res = manager.resolve_conflict_overwrite()
        assert res == 77777.0
        mock_push.assert_called_once_with(None, force=True)


def test_push_not_logged_in_raises_authentication_error():
    """Verify push or pull raises AuthenticationError when not logged in."""
    settings = Settings(sync_server_url="http://mock:8000", sync_token="")
    manager = SyncManager(settings, sync_password="sync-pass")

    with pytest.raises(AuthenticationError):
        manager.push()

    with pytest.raises(AuthenticationError):
        manager.pull_and_merge()
