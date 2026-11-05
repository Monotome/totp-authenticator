"""Tests for backup and restore functionality."""

import os

import pytest

from totp_authenticator.crypto import InvalidPasswordError
from totp_authenticator.storage import (
    add_account,
    create_backup,
    load_accounts,
    restore_backup,
)


@pytest.fixture(autouse=True)
def patch_config(tmp_path, monkeypatch):
    """Redirect CONFIG_FILE to a temp path."""
    config_file = tmp_path / ".totp_config.json"
    monkeypatch.setattr("totp_authenticator.storage.CONFIG_FILE", str(config_file))
    return config_file


def test_create_and_restore_backup(tmp_path):
    # Setup initial accounts
    add_account("GitHub", "JBSWY3DPEHPK3PXP")

    backup_file = str(tmp_path / "backup.json")

    # Create backup with password
    create_backup("secure_pass_123", backup_file)

    assert os.path.exists(backup_file)

    # Add a new account to current state to simulate drift
    add_account("Google", "JBSWY3DPEHPK3PXP")

    # Restore from backup
    added = restore_backup("secure_pass_123", backup_file)

    # Since GitHub is already in the state, and backup only has GitHub, added should be 0
    assert added == 0

    accounts = load_accounts()
    assert len(accounts) == 2
    assert {"GitHub", "Google"} == {a.name for a in accounts}


def test_restore_adds_new_accounts(tmp_path):
    # Create accounts, backup, then delete one and restore
    a1 = add_account("Acc1", "JBSWY3DPER")
    add_account("Acc2", "JBSWY3DPER")

    backup_file = str(tmp_path / "backup.json")
    create_backup("pass", backup_file)

    from totp_authenticator.storage import delete_account
    delete_account(a1.id)

    assert len(load_accounts()) == 1

    added = restore_backup("pass", backup_file)
    assert added == 1

    accounts = load_accounts()
    assert len(accounts) == 2


def test_restore_with_wrong_password_fails(tmp_path):
    add_account("GitHub", "JBSWY3DPEHPK3PXP")
    backup_file = str(tmp_path / "backup.json")
    create_backup("correct_pass", backup_file)

    with pytest.raises(InvalidPasswordError):
        restore_backup("wrong_pass", backup_file)
