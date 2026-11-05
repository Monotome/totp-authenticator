"""Tests for Lock Screen and Reset Vault UI integration."""

import contextlib
import tkinter as tk
from unittest.mock import patch

import pytest

from totp_authenticator.app import TOTPApp
from totp_authenticator.storage import add_account, is_config_encrypted, set_encryption


@pytest.fixture(scope="module")
def tk_root():
    root = tk.Tk()
    root.withdraw()
    yield root
    with contextlib.suppress(Exception):
        root.destroy()


@pytest.fixture(autouse=True)
def clean_root(tk_root):
    for w in tk_root.winfo_children():
        w.destroy()
    yield
    for w in tk_root.winfo_children():
        w.destroy()


@pytest.fixture(autouse=True)
def patch_config(tmp_path, monkeypatch):
    """Redirect CONFIG_FILE to a temp path."""
    config_file = tmp_path / ".totp_config.json"
    monkeypatch.setattr("totp_authenticator.storage.CONFIG_FILE", str(config_file))
    return config_file


def test_lock_screen_displays_when_encrypted(tk_root):
    add_account("Test", "JBSWY3DPEHPK3PXP")
    set_encryption("test_password")
    assert is_config_encrypted()

    app = TOTPApp(tk_root)
    assert hasattr(app, "lock_frame")
    assert hasattr(app, "pwd_entry")
    assert hasattr(app, "lbl_pwd_error")

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_lock_screen_wrong_password_shows_error(tk_root):
    add_account("Test", "JBSWY3DPEHPK3PXP")
    set_encryption("test_password")

    app = TOTPApp(tk_root)
    app.pwd_entry.insert(0, "wrong_pass")
    app._try_unlock()

    assert app.lbl_pwd_error.cget("text") == "Incorrect password. Please try again."

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_lock_screen_correct_password_unlocks(tk_root):
    add_account("Test", "JBSWY3DPEHPK3PXP")
    set_encryption("test_password")

    app = TOTPApp(tk_root)
    app.pwd_entry.insert(0, "test_password")
    app._try_unlock()

    assert not hasattr(app, "lock_frame") or not app.lock_frame.winfo_exists()
    assert hasattr(app, "sidebar")
    assert len(app._accounts) == 1

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_lock_screen_reset_vault_workflow(tk_root, patch_config):
    add_account("Work", "JBSWY3DPEHPK3PXP")
    set_encryption("forgotten_password")
    assert is_config_encrypted()

    app = TOTPApp(tk_root)
    assert hasattr(app, "lock_frame")

    # Mock messagebox.showinfo so it doesn't block the test
    with patch("tkinter.messagebox.showinfo") as mock_info:
        app._confirm_reset_vault()

        # Find the open dialog Toplevel
        dialogs = [w for w in tk_root.winfo_children() if isinstance(w, tk.Toplevel)]
        assert len(dialogs) == 1
        dialog = dialogs[0]

        # Find confirm Entry and Confirm Button
        entries = [w for w in dialog.winfo_children() if isinstance(w, tk.Entry)]
        assert len(entries) == 1
        confirm_entry = entries[0]

        btn_box = [w for w in dialog.winfo_children() if isinstance(w, tk.Frame)][0]
        buttons = [w for w in btn_box.winfo_children() if isinstance(w, tk.Button)]
        btn_reset = [b for b in buttons if b.cget("text") == "Reset Vault"][0]

        # 1. Try clicking Reset Vault with empty string
        btn_reset.invoke()
        assert is_config_encrypted()  # Should NOT reset

        # 2. Type "RESET" and click Reset Vault
        confirm_entry.insert(0, "RESET")
        btn_reset.invoke()

        # 3. Assertions
        assert not is_config_encrypted()
        assert mock_info.called
        assert hasattr(app, "sidebar")
        assert len(app._accounts) == 0

        # Verify backup was created
        backups = list(patch_config.parent.glob("*.bak_*"))
        assert len(backups) == 1

    if app._update_job:
        tk_root.after_cancel(app._update_job)

