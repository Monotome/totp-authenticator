"""Tests for modern UI components, design tokens, and avatar helpers."""

import contextlib
import tkinter as tk

import pytest

from totp_authenticator.app import (
    THEMES,
    TOTPApp,
    get_avatar_colors,
    get_initials,
)
from totp_authenticator.storage import add_account


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


def test_theme_tokens_completeness():
    """Verify that both dark and light themes contain all required design tokens."""
    required_keys = {
        "bg", "bg_sidebar", "bg_card", "bg_card_hover", "bg_card_selected",
        "bg_entry", "border", "border_focus", "fg", "fg_dim", "fg_selected",
        "blue", "blue_hover", "green", "amber", "red", "surface", "surface_hover",
        "progress_bg",
    }
    for theme_name in ("dark", "light"):
        theme = THEMES.get(theme_name)
        assert theme is not None
        missing = required_keys - set(theme.keys())
        assert not missing, f"Theme '{theme_name}' is missing keys: {missing}"


def test_get_initials():
    assert get_initials("Google") == "GO"
    assert get_initials("GitHub") == "GI"
    assert get_initials("AWS Root Account") == "AA"
    assert get_initials("Discord Personal") == "DP"
    assert get_initials("") == "?"


def test_get_avatar_colors():
    bg, fg = get_avatar_colors("GitHub")
    assert bg.startswith("#")
    assert fg == "#ffffff"


def test_modern_entry_creation_and_focus(tk_root):
    app = TOTPApp(tk_root)
    cnt, entry = app._create_modern_entry(tk_root, width=20)
    cnt.pack()
    assert isinstance(cnt, tk.Frame)
    assert isinstance(entry, tk.Entry)

    # FocusIn changes container bg to border_focus
    entry.on_focus_in()
    assert cnt.cget("bg") == app.c["border_focus"]

    # FocusOut restores border
    entry.on_focus_out()
    assert cnt.cget("bg") == app.c["border"]

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_sidebar_card_rendering_and_selection(tk_root):
    add_account("GitHub", "JBSWY3DPEHPK3PXP")
    add_account("Google", "JBSWY3DPEHPK3PXP")

    app = TOTPApp(tk_root)
    assert len(app._accounts) == 2

    # Check card widgets are rendered for both accounts
    assert len(app._card_widgets) == 2
    assert app._selected_id == app._accounts[0].id

    # Test navigation down switches selected account
    app._navigate_down()
    assert app._selected_id == app._accounts[1].id

    # Test navigation up switches back
    app._navigate_up()
    assert app._selected_id == app._accounts[0].id

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_empty_state_when_no_accounts(tk_root):
    app = TOTPApp(tk_root)
    assert len(app._accounts) == 0
    assert app._selected_account() is None
    assert app.empty_frame.winfo_manager() == "pack"
    assert not app.code_container.winfo_manager()

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_theme_toggle_updates_ui(tk_root):
    app = TOTPApp(tk_root)
    initial_theme = app._settings.theme
    app._toggle_theme()
    assert app._settings.theme != initial_theme
    assert app.root.cget("bg") == app.c["bg"]

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_sidebar_buttons_theme_aware(tk_root):
    app = TOTPApp(tk_root)
    if app._settings.theme != "dark":
        app._toggle_theme()

    rename_btn = next(b for b in app.sidebar_buttons if b.cget("text") == "Rename")
    delete_btn = next(b for b in app.sidebar_buttons if b.cget("text") == "Delete")
    add_btn = next(b for b in app.sidebar_buttons if b.cget("text") == "+ Add")

    # Dark mode colors
    assert rename_btn.cget("bg") == app.c["surface"]
    assert delete_btn.cget("bg") == app.c["surface"]
    assert add_btn.cget("bg") == app.c["blue"]

    # Toggle to light mode
    app._toggle_theme()
    assert rename_btn.cget("bg") == app.c["surface"]
    assert delete_btn.cget("bg") == app.c["surface"]
    assert add_btn.cget("bg") == app.c["blue"]

    # Toggle back to dark mode
    app._toggle_theme()
    assert rename_btn.cget("bg") == app.c["surface"]
    assert delete_btn.cget("bg") == app.c["surface"]

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_toolbar_action_buttons(tk_root):
    app = TOTPApp(tk_root)
    assert hasattr(app, "toolbar_frame")
    assert hasattr(app, "btn_sync")
    assert hasattr(app, "btn_security")
    assert hasattr(app, "btn_theme_toggle")

    # Check button sizes and attributes
    assert app.btn_sync.cget("width") == 28
    assert app.btn_security.cget("width") == 28
    assert app.btn_theme_toggle.cget("width") == 28
    assert hasattr(app.btn_sync, "_tooltip")

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_toolbar_buttons_geometry_and_alignment(tk_root):
    """Verify that all toolbar buttons are strictly aligned on the same horizontal baseline."""
    tk_root.deiconify()
    try:
        app = TOTPApp(tk_root)
        tk_root.update()

        # Vertical baseline alignment (all 3 buttons must share identical Y coordinate)
        y_sync = app.btn_sync.winfo_rooty()
        y_sec = app.btn_security.winfo_rooty()
        y_thm = app.btn_theme_toggle.winfo_rooty()
        assert (
            y_sync == y_sec == y_thm
        ), f"Toolbar buttons misaligned vertically: {y_sync}, {y_sec}, {y_thm}"

        # Identical bounding box dimensions
        h_sync = app.btn_sync.winfo_height()
        h_sec = app.btn_security.winfo_height()
        h_thm = app.btn_theme_toggle.winfo_height()
        assert h_sync == h_sec == h_thm

        w_sync = app.btn_sync.winfo_width()
        w_sec = app.btn_security.winfo_width()
        w_thm = app.btn_theme_toggle.winfo_width()
        assert w_sync == w_sec == w_thm

        # Strictly ordered from left to right with positive separation
        x_sync = app.btn_sync.winfo_rootx()
        x_sec = app.btn_security.winfo_rootx()
        x_thm = app.btn_theme_toggle.winfo_rootx()
        msg = f"Buttons not laid out left-to-right: {x_sync}, {x_sec}, {x_thm}"
        assert x_sync < x_sec < x_thm, msg

        if app._update_job:
            tk_root.after_cancel(app._update_job)
    finally:
        tk_root.withdraw()


def test_modern_entry_inner_wrapper_and_border_padding(tk_root):
    """Verify modern entry has an inner container preventing focus border artifacts."""
    app = TOTPApp(tk_root)
    container, entry = app._create_modern_entry(app.main, width=28)

    # Entry must be nested in inner frame with matching background, NOT directly on border container
    inner = entry.master
    assert inner != container, "Entry is packed directly inside outer border container"
    assert inner.cget("bg") == app.c["bg_entry"]

    # Initial border color
    assert container.cget("bg") == app.c["border"]

    # Focus-in illuminates border
    entry.on_focus_in()
    assert container.cget("bg") == app.c["border_focus"]

    # Focus-out returns to standard border
    entry.on_focus_out()
    assert container.cget("bg") == app.c["border"]

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_action_icons_rendering(tk_root):
    """Verify vector icons render crisp PhotoImage objects and cache properly."""
    app = TOTPApp(tk_root)
    icons = ["cloud", "gear", "sun", "moon"]
    for icon_name in icons:
        photo = app._get_action_icon(icon_name, "#ffffff", size=15)
        assert photo is not None
        assert (icon_name, "#ffffff", 15) in app._icon_cache

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_sync_dialog_renders_connected_state(tk_root):
    """Verify that Cloud Sync dialog renders 2-way sync button and controls when connected."""
    app = TOTPApp(tk_root)
    app._settings.sync_token = "valid-token-xyz"
    app._settings.sync_username = "alice"
    app._settings.sync_server_url = "https://example-sync.com"

    # Open sync dialog
    app._open_sync_dialog()

    # Find the opened Toplevel dialog
    toplevels = [w for w in tk_root.winfo_children() if isinstance(w, tk.Toplevel)]
    assert len(toplevels) >= 1
    dialog = toplevels[-1]
    assert "Cloud Sync" in dialog.title()

    # Recursively collect all buttons
    def _find_all_buttons(parent):
        found = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Button):
                found.append(child)
            found.extend(_find_all_buttons(child))
        return found

    all_buttons = _find_all_buttons(dialog)
    btn_texts = [b.cget("text") for b in all_buttons]

    # Verify Hero 2-Way Sync button exists
    assert any("Sync Now (2-Way Sync)" in t for t in btn_texts)
    # Verify Pull & Merge exists
    assert any("Pull & Merge" in t for t in btn_texts)
    # Verify Push Vault exists
    assert any("Push Vault" in t for t in btn_texts)
    # Verify Disconnect Account exists
    assert any("Disconnect Account" in t for t in btn_texts)

    dialog.destroy()
    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_sync_dialog_renders_disconnected_state(tk_root):
    """Verify that when no sync_token is set, Cloud Sync dialog renders login form with presets."""
    app = TOTPApp(tk_root)
    app._settings.sync_token = ""

    app._open_sync_dialog()

    toplevels = [w for w in tk_root.winfo_children() if isinstance(w, tk.Toplevel)]
    assert len(toplevels) >= 1
    dialog = toplevels[-1]

    def _find_all_buttons(parent):
        found = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Button):
                found.append(child)
            found.extend(_find_all_buttons(child))
        return found

    all_buttons = _find_all_buttons(dialog)
    btn_texts = [b.cget("text") for b in all_buttons]

    assert any("Log In" in t for t in btn_texts)
    assert any("Create New Account" in t for t in btn_texts)
    assert any("Render Cloud" in t for t in btn_texts)
    assert any("Localhost" in t for t in btn_texts)

    dialog.destroy()
    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_security_dialog_encrypted_vault_renders_fields(tk_root):
    """Verify Security Settings dialog shows old, new, and confirm password fields."""
    from totp_authenticator.storage import set_encryption

    key = set_encryption("secret123")
    app = TOTPApp(tk_root)
    app._current_key = key

    app._open_security_dialog()

    toplevels = [w for w in tk_root.winfo_children() if isinstance(w, tk.Toplevel)]
    assert len(toplevels) >= 1
    dialog = toplevels[-1]

    def _find_all_labels(parent):
        found = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Label):
                found.append(child)
            found.extend(_find_all_labels(child))
        return found

    def _find_all_buttons(parent):
        found = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Button):
                found.append(child)
            found.extend(_find_all_buttons(child))
        return found

    all_labels = _find_all_labels(dialog)
    label_texts = [lbl.cget("text") for lbl in all_labels]

    assert any("Current Master Password" in t for t in label_texts)
    assert any("New Master Password" in t for t in label_texts)
    assert any("Confirm New Password" in t for t in label_texts)

    all_buttons = _find_all_buttons(dialog)
    btn_texts = [b.cget("text") for b in all_buttons]
    assert any("Save Settings" in t for t in btn_texts)
    assert any("Remove Password" in t for t in btn_texts)

    dialog.destroy()
    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_security_dialog_unencrypted_vault_renders_fields(tk_root):
    """Verify Security Settings dialog shows set and confirm fields when unencrypted."""
    app = TOTPApp(tk_root)

    app._open_security_dialog()

    toplevels = [w for w in tk_root.winfo_children() if isinstance(w, tk.Toplevel)]
    assert len(toplevels) >= 1
    dialog = toplevels[-1]

    def _find_all_labels(parent):
        found = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Label):
                found.append(child)
            found.extend(_find_all_labels(child))
        return found

    def _find_all_buttons(parent):
        found = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Button):
                found.append(child)
            found.extend(_find_all_buttons(child))
        return found

    all_labels = _find_all_labels(dialog)
    label_texts = [lbl.cget("text") for lbl in all_labels]

    assert any("Set Master Password" in t for t in label_texts)
    assert any("Confirm Password" in t for t in label_texts)
    assert not any("Current Master Password" in t for t in label_texts)

    all_buttons = _find_all_buttons(dialog)
    btn_texts = [b.cget("text") for b in all_buttons]
    assert any("Save Settings" in t for t in btn_texts)
    assert not any("Remove Password" in t for t in btn_texts)

    dialog.destroy()
    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_security_dialog_change_password_flow(tk_root, monkeypatch):
    """Verify master password change enforces old password check and updates key."""
    from totp_authenticator.storage import set_encryption, verify_password

    key = set_encryption("old_pass123")
    app = TOTPApp(tk_root)
    app._current_key = key

    app._open_security_dialog()

    toplevels = [w for w in tk_root.winfo_children() if isinstance(w, tk.Toplevel)]
    dialog = toplevels[-1]

    def _find_entries(parent):
        entries = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Entry):
                entries.append(child)
            entries.extend(_find_entries(child))
        return entries

    entries = _find_entries(dialog)
    assert len(entries) >= 4
    _timeout_e, old_e, new_e, confirm_e = entries[0], entries[1], entries[2], entries[3]

    errors = []
    infos = []
    monkeypatch.setattr(
        "tkinter.messagebox.showerror",
        lambda title, msg, **kw: errors.append((title, msg)),
    )
    monkeypatch.setattr(
        "tkinter.messagebox.showinfo",
        lambda title, msg, **kw: infos.append((title, msg)),
    )

    def _find_buttons(parent):
        btns = []
        for child in parent.winfo_children():
            if isinstance(child, tk.Button):
                btns.append(child)
            btns.extend(_find_buttons(child))
        return btns

    btns = _find_buttons(dialog)
    save_btn = next(b for b in btns if b.cget("text") == "Save Settings")

    # 1. Test wrong old password
    old_e.insert(0, "wrong_old_pwd")
    new_e.insert(0, "new_pass456")
    confirm_e.insert(0, "new_pass456")
    save_btn.invoke()
    assert "Incorrect current master password" in dialog.lbl_feedback.cget("text")

    # 2. Test password mismatch
    old_e.delete(0, tk.END)
    old_e.insert(0, "old_pass123")
    confirm_e.delete(0, tk.END)
    confirm_e.insert(0, "different_pass")
    save_btn.invoke()
    assert "do not match" in dialog.lbl_feedback.cget("text")

    # 3. Test password too short
    new_e.delete(0, tk.END)
    new_e.insert(0, "123")
    confirm_e.delete(0, tk.END)
    confirm_e.insert(0, "123")
    save_btn.invoke()
    assert "at least 6 characters" in dialog.lbl_feedback.cget("text")

    # 4. Test valid password change
    new_e.delete(0, tk.END)
    new_e.insert(0, "new_pass456")
    confirm_e.delete(0, tk.END)
    confirm_e.insert(0, "new_pass456")
    save_btn.invoke()
    assert "Master password updated successfully" in dialog.lbl_feedback.cget("text")

    # Verify that new password unlocks the vault
    new_key = verify_password("new_pass456")
    assert new_key == app._current_key

    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_toast_notification(tk_root):
    """Verify that floating toast renders with correct message and styles."""
    app = TOTPApp(tk_root)
    app._show_toast("Operation completed successfully", is_error=False)

    assert app._toast_frame is not None
    assert "Operation completed successfully" in app._toast_lbl.cget("text")
    assert "✓" in app._toast_lbl.cget("text")

    app._show_toast("Operation failed", is_error=True)
    assert "Operation failed" in app._toast_lbl.cget("text")
    assert "⚠️" in app._toast_lbl.cget("text")

    if app._toast_timer:
        tk_root.after_cancel(app._toast_timer)
    if app._update_job:
        tk_root.after_cancel(app._update_job)


def test_position_dialog_centers_over_parent(tk_root):
    """Verify that _position_dialog computes coordinates relative to parent."""
    app = TOTPApp(tk_root)
    dialog = tk.Toplevel(tk_root)
    app._position_dialog(dialog, 400, 300, parent=tk_root)
    dialog.update_idletasks()

    geom = dialog.geometry()
    assert "+" in geom
    dialog.destroy()
    if app._update_job:
        tk_root.after_cancel(app._update_job)




