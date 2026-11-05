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
        assert x_sync < x_sec < x_thm, f"Buttons not laid out left-to-right: {x_sync}, {x_sec}, {x_thm}"

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

