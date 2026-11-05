"""Tests for totp_authenticator.storage."""

import json

import pytest

from totp_authenticator.storage import (
    Account,
    Settings,
    add_account,
    delete_account,
    is_config_encrypted,
    load_accounts,
    load_settings,
    remove_encryption,
    rename_account,
    save_accounts,
    save_settings,
    set_encryption,
    verify_password,
)

VALID_SECRET = "JBSWY3DPEHPK3PXP"


@pytest.fixture(autouse=True)
def patch_config(tmp_path, monkeypatch):
    """Redirect CONFIG_FILE to a temp path for every test."""
    config_file = tmp_path / ".totp_config.json"
    monkeypatch.setattr("totp_authenticator.storage.CONFIG_FILE", str(config_file))
    return config_file


class TestLoadAccounts:
    """Tests for load_accounts()."""

    def test_load_missing_file_returns_empty_list(self):
        assert load_accounts() == []

    def test_load_corrupted_file_returns_empty_list(self, patch_config):
        patch_config.write_text("NOT VALID JSON{{{", encoding="utf-8")
        assert load_accounts() == []

    def test_load_empty_accounts_key_returns_empty_list(self, patch_config):
        patch_config.write_text('{"accounts": []}', encoding="utf-8")
        assert load_accounts() == []


class TestAddAndSave:
    """Tests for add_account() and save_accounts()."""

    def test_add_and_load_roundtrip(self):
        account = add_account("GitHub", VALID_SECRET)
        loaded = load_accounts()
        assert len(loaded) == 1
        assert loaded[0].name == "GitHub"
        assert loaded[0].secret == VALID_SECRET
        assert loaded[0].id == account.id

    def test_add_multiple_accounts(self):
        add_account("GitHub", VALID_SECRET)
        add_account("Google", VALID_SECRET)
        add_account("AWS", VALID_SECRET)
        accounts = load_accounts()
        assert len(accounts) == 3
        names = [a.name for a in accounts]
        assert "GitHub" in names
        assert "Google" in names
        assert "AWS" in names

    def test_each_account_has_unique_id(self):
        add_account("A", VALID_SECRET)
        add_account("B", VALID_SECRET)
        accounts = load_accounts()
        ids = [a.id for a in accounts]
        assert len(set(ids)) == 2

    def test_save_is_valid_json(self, patch_config):
        save_accounts([Account(id="test-id", name="Test", secret=VALID_SECRET)])
        data = json.loads(patch_config.read_text(encoding="utf-8"))
        assert "accounts" in data
        assert data["accounts"][0]["name"] == "Test"


class TestDeleteAccount:
    """Tests for delete_account()."""

    def test_delete_account(self):
        account = add_account("GitHub", VALID_SECRET)
        add_account("Google", VALID_SECRET)
        delete_account(account.id)
        accounts = load_accounts()
        assert len(accounts) == 1
        assert accounts[0].name == "Google"

    def test_delete_nonexistent_id_does_not_crash(self):
        add_account("GitHub", VALID_SECRET)
        delete_account("nonexistent-id-12345")  # should not raise
        assert len(load_accounts()) == 1

    def test_delete_all_accounts(self):
        a = add_account("GitHub", VALID_SECRET)
        delete_account(a.id)
        assert load_accounts() == []


class TestRenameAccount:
    """Tests for rename_account()."""

    def test_rename_account(self):
        account = add_account("GitHub", VALID_SECRET)
        rename_account(account.id, "GitLab")
        accounts = load_accounts()
        assert accounts[0].name == "GitLab"

    def test_rename_only_affects_target(self):
        a1 = add_account("GitHub", VALID_SECRET)
        add_account("Google", VALID_SECRET)
        rename_account(a1.id, "GitLab")
        accounts = load_accounts()
        names = {a.id: a.name for a in accounts}
        assert names[a1.id] == "GitLab"
        # Google stays unchanged
        google = next(a for a in accounts if a.name == "Google")
        assert google.name == "Google"

    def test_rename_nonexistent_id_does_not_crash(self):
        add_account("GitHub", VALID_SECRET)
        rename_account("nonexistent-id", "Foo")  # should not raise
        assert load_accounts()[0].name == "GitHub"


class TestMigration:
    """Tests for automatic migration from v0.1 single-secret format."""

    def test_migration_from_v0_1_format(self, patch_config):
        patch_config.write_text(
            json.dumps({"secret": VALID_SECRET}), encoding="utf-8"
        )
        accounts = load_accounts()
        assert len(accounts) == 1
        assert accounts[0].name == "My Account"
        assert accounts[0].secret == VALID_SECRET

    def test_migration_rewrites_file_to_new_format(self, patch_config):
        patch_config.write_text(
            json.dumps({"secret": VALID_SECRET}), encoding="utf-8"
        )
        load_accounts()
        data = json.loads(patch_config.read_text(encoding="utf-8"))
        assert "accounts" in data
        assert "secret" not in data


class TestSettings:
    """Tests for load_settings() and save_settings()."""

    def test_load_settings_missing_file_returns_default(self):
        settings = load_settings()
        assert settings.theme == "dark"
        assert settings.window_x is None
        assert settings.window_y is None

    def test_save_and_load_settings(self):
        settings = Settings(theme="light", window_x=150, window_y=250)
        save_settings(settings)
        loaded = load_settings()
        assert loaded.theme == "light"
        assert loaded.window_x == 150
        assert loaded.window_y == 250

    def test_save_settings_creates_file_if_missing(self, patch_config):
        settings = Settings(theme="light")
        save_settings(settings)
        assert patch_config.exists()
        data = json.loads(patch_config.read_text(encoding="utf-8"))
        assert data["settings"]["theme"] == "light"

    def test_save_settings_does_not_overwrite_accounts(self):
        add_account("Test", VALID_SECRET)
        settings = Settings(theme="light", window_x=10, window_y=20)
        save_settings(settings)

        # Accounts should still be there
        accounts = load_accounts()
        assert len(accounts) == 1
        assert accounts[0].name == "Test"

    def test_save_accounts_does_not_overwrite_settings(self):
        settings = Settings(theme="light", window_x=10, window_y=20)
        save_settings(settings)

        add_account("Test", VALID_SECRET)

        # Settings should still be there
        loaded = load_settings()
        assert loaded.theme == "light"
        assert loaded.window_x == 10
        assert loaded.window_y == 20


class TestEncryption:
    """Tests for master password and config encryption."""

    def test_set_and_verify_encryption(self, patch_config):
        # Create some initial plaintext data
        add_account("Test", VALID_SECRET)
        assert not is_config_encrypted()

        # Set encryption
        key = set_encryption("my_password")
        assert is_config_encrypted()

        # Verify
        verified_key = verify_password("my_password")
        assert key == verified_key

    def test_verify_fails_with_wrong_password(self):
        add_account("Test", VALID_SECRET)
        set_encryption("my_password")

        from totp_authenticator.crypto import InvalidPasswordError
        with pytest.raises(InvalidPasswordError):
            verify_password("wrong_password")

    def test_remove_encryption(self):
        add_account("Test", VALID_SECRET)
        key = set_encryption("my_password")

        remove_encryption(key)
        assert not is_config_encrypted()

        # Data is back to plaintext, loadable without key
        accounts = load_accounts()
        assert len(accounts) == 1
        assert accounts[0].name == "Test"
