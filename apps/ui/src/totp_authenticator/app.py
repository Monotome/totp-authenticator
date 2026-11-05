"""TOTP Authenticator UI — tkinter-based desktop window (v0.2.0 multi-account)."""

import time
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog

import pyperclip

from totp_authenticator.api import AuthenticationError, ConflictError, SyncClientError
from totp_authenticator.core import get_code, get_remaining_seconds, validate_secret
from totp_authenticator.crypto import InvalidPasswordError
from totp_authenticator.parser import InvalidURIError, parse_uri
from totp_authenticator.storage import (
    Account,
    add_account,
    create_backup,
    delete_account,
    is_config_encrypted,
    load_accounts,
    load_settings,
    remove_encryption,
    rename_account,
    reset_vault,
    restore_backup,
    save_settings,
    set_encryption,
    verify_password,
)
from totp_authenticator.sync_manager import SyncManager

# ── Colour palettes (Catppuccin Mocha for Dark, Latte for Light) ───────────
THEMES = {
    "dark": {
        "bg": "#1e1e2e",
        "bg_sidebar": "#181825",
        "bg_entry": "#313244",
        "fg": "#cdd6f4",
        "fg_dim": "#6c7086",
        "fg_selected": "#89b4fa",
        "green": "#a6e3a1",
        "red": "#f38ba8",
        "blue": "#89b4fa",
        "surface": "#45475a",
    },
    "light": {
        "bg": "#eff1f5",
        "bg_sidebar": "#e6e9ef",
        "bg_entry": "#dce0e8",
        "fg": "#4c4f69",
        "fg_dim": "#8c8fa1",
        "fg_selected": "#1e66f5",
        "green": "#40a02b",
        "red": "#d20f39",
        "blue": "#1e66f5",
        "surface": "#ccd0da",
    },
}


class TOTPApp:
    """Main application window for the TOTP Authenticator (multi-account)."""

    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("TOTP Authenticator")
        self.root.resizable(False, False)
        self.root.attributes("-topmost", True)

        self._settings = load_settings()
        self.c = THEMES.get(self._settings.theme, THEMES["dark"])

        width, height = 620, 400
        if self._settings.window_x is not None and self._settings.window_y is not None:
            self.root.geometry(f"{width}x{height}+{self._settings.window_x}+{self._settings.window_y}")
        else:
            self.root.geometry(f"{width}x{height}")

        self.root.configure(bg=self.c["bg"])
        self._copy_timer: str | None = None
        self._current_key: bytes | None = None
        self._last_activity = time.time()
        self._update_job: str | None = None

        # Track window moves to save config
        self.root.bind("<Configure>", self._on_window_configure)

        # Global activity tracking for auto-lock
        for event in ("<Key>", "<Button>", "<Motion>", "<MouseWheel>"):
            self.root.bind(event, self._on_user_activity, add="+")

        if is_config_encrypted():
            self._build_lock_screen()
        else:
            self._init_main_app()

    def _on_user_activity(self, _event: tk.Event) -> None:  # type: ignore[type-arg]
        """Reset the inactivity timer."""
        self._last_activity = time.time()

    def _init_main_app(self, key: bytes | None = None) -> None:
        """Initialize or re-initialize the main application UI."""
        self._current_key = key
        self._accounts = load_accounts(self._current_key)
        self._selected_id: str | None = (
            self._accounts[0].id if self._accounts else None
        )

        # Clear lock screen if any
        for widget in self.root.winfo_children():
            widget.destroy()

        self.root.bind("<Control-c>", lambda e: self._copy_code())
        self.root.bind("<Control-C>", lambda e: self._copy_code())
        self.root.bind("<Return>", lambda e: self._copy_code())
        self.root.bind("<Control-a>", lambda e: self._open_add_dialog())
        self.root.bind("<Control-r>", lambda e: self._open_rename_dialog())
        self.root.bind("<Delete>", lambda e: self._open_delete_dialog())
        self.root.bind("<Up>", self._navigate_up)
        self.root.bind("<Down>", self._navigate_down)

        self._build_ui()
        self._refresh_sidebar()
        self._last_activity = time.time()
        self._update_loop()

    def _lock_app(self) -> None:
        """Lock the application and require password again."""
        if not is_config_encrypted():
            return

        if self._update_job:
            self.root.after_cancel(self._update_job)
            self._update_job = None

        self._current_key = None
        self._accounts = []
        self._selected_id = None

        # Unbind shortcuts
        keys_to_unbind = (
            "<Control-c>", "<Control-C>", "<Return>",
            "<Control-a>", "<Control-r>", "<Delete>",
            "<Up>", "<Down>"
        )
        for key in keys_to_unbind:
            self.root.unbind(key)

        for widget in self.root.winfo_children():
            widget.destroy()

        self._build_lock_screen()

    # ── Build ──────────────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        """Construct the two-panel widget tree."""
        # ── Sidebar (left) ─────────────────────────────────────────────────────
        self.sidebar = tk.Frame(self.root, bg=self.c["bg_sidebar"], width=190)
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)

        # Header contains "Accounts" label and Theme Toggle button
        self.header_frame = tk.Frame(self.sidebar, bg=self.c["bg_sidebar"])
        self.header_frame.pack(fill="x", pady=(16, 6), padx=12)

        self.lbl_accounts = tk.Label(
            self.header_frame, text="Accounts", font=("Segoe UI", 10, "bold"),
            bg=self.c["bg_sidebar"], fg=self.c["fg_dim"],
        )
        self.lbl_accounts.pack(side="left")

        self.btn_security = tk.Button(
            self.header_frame,
            text="⚙️",
            font=("Segoe UI", 10),
            bg=self.c["bg_sidebar"],
            fg=self.c["fg_dim"],
            relief="flat",
            borderwidth=0,
            cursor="hand2",
            command=self._open_security_dialog,
        )
        self.btn_security.pack(side="right", padx=(0, 8))

        self.btn_sync = tk.Button(
            self.header_frame,
            text="☁️",
            font=("Segoe UI", 10),
            bg=self.c["bg_sidebar"],
            fg=self.c["fg_dim"],
            relief="flat",
            borderwidth=0,
            cursor="hand2",
            command=self._open_sync_dialog,
        )
        self.btn_sync.pack(side="right", padx=(0, 4))

        self.btn_theme_toggle = tk.Button(
            self.header_frame,
            text="☀️" if self._settings.theme == "dark" else "🌙",
            font=("Segoe UI", 10),
            bg=self.c["bg_sidebar"],
            fg=self.c["fg_dim"],
            relief="flat",
            borderwidth=0,
            cursor="hand2",
            command=self._toggle_theme,
        )
        self.btn_theme_toggle.pack(side="right")

        # Account listbox
        self.list_frame = tk.Frame(self.sidebar, bg=self.c["bg_sidebar"])
        self.list_frame.pack(fill="both", expand=True, padx=8)

        self.listbox = tk.Listbox(
            self.list_frame, bg=self.c["bg_sidebar"], fg=self.c["fg"],
            selectbackground=self.c["bg_entry"], selectforeground=self.c["fg_selected"],
            font=("Segoe UI", 10), relief="flat", borderwidth=0,
            highlightthickness=0, activestyle="none", cursor="hand2",
        )
        self.listbox.pack(fill="both", expand=True)
        self.listbox.bind("<<ListboxSelect>>", self._on_select)

        # Sidebar action buttons
        self.btn_bar = tk.Frame(self.sidebar, bg=self.c["bg_sidebar"])
        self.btn_bar.pack(fill="x", padx=8, pady=(6, 12))

        self.sidebar_buttons = []
        for text, cmd in [
            ("+ Add", self._open_add_dialog),
            ("Rename", self._open_rename_dialog),
            ("Delete", self._open_delete_dialog),
        ]:
            btn = tk.Button(
                self.btn_bar, text=text, font=("Segoe UI", 9),
                bg=self.c["surface"], fg=self.c["fg"], relief="flat",
                padx=8, pady=4, cursor="hand2", command=cmd,
            )
            btn.pack(side="left", padx=2)
            self.sidebar_buttons.append(btn)

        # ── Main panel (right) ─────────────────────────────────────────────────
        self.main = tk.Frame(self.root, bg=self.c["bg"])
        self.main.pack(side="left", fill="both", expand=True)

        self.account_name_var = tk.StringVar(value="")
        self.lbl_acc_name = tk.Label(
            self.main, textvariable=self.account_name_var,
            font=("Segoe UI", 11, "bold"), bg=self.c["bg"], fg=self.c["fg_dim"],
        )
        self.lbl_acc_name.pack(pady=(28, 0))

        self.code_var = tk.StringVar(value="------")
        self.code_label = tk.Label(
            self.main, textvariable=self.code_var,
            font=("Courier New", 42, "bold"), bg=self.c["bg"], fg=self.c["green"],
        )
        self.code_label.pack(pady=(4, 0))

        self.timer_var = tk.StringVar(value="")
        self.lbl_timer = tk.Label(
            self.main, textvariable=self.timer_var,
            font=("Segoe UI", 9), bg=self.c["bg"], fg=self.c["fg_dim"],
        )
        self.lbl_timer.pack()

        self.copy_btn = tk.Button(
            self.main, text="📋  Copy Code", font=("Segoe UI", 11, "bold"),
            bg=self.c["blue"], fg=self.c["bg"], relief="flat", padx=24, pady=8,
            cursor="hand2", command=self._copy_code,
        )
        self.copy_btn.pack(pady=20)

        self.hint_var = tk.StringVar(value="")
        self.lbl_hint = tk.Label(
            self.main, textvariable=self.hint_var, font=("Segoe UI", 9),
            bg=self.c["bg"], fg=self.c["fg_dim"], wraplength=360, justify="center",
        )
        self.lbl_hint.pack()

    def _toggle_theme(self) -> None:
        """Switch between light and dark themes and update UI."""
        self._settings.theme = "light" if self._settings.theme == "dark" else "dark"
        save_settings(self._settings)
        self.c = THEMES[self._settings.theme]

        self.root.configure(bg=self.c["bg"])
        self.sidebar.configure(bg=self.c["bg_sidebar"])
        self.header_frame.configure(bg=self.c["bg_sidebar"])
        self.lbl_accounts.configure(bg=self.c["bg_sidebar"], fg=self.c["fg_dim"])
        self.btn_security.configure(bg=self.c["bg_sidebar"], fg=self.c["fg_dim"])
        self.btn_sync.configure(bg=self.c["bg_sidebar"], fg=self.c["fg_dim"])
        self.btn_theme_toggle.configure(
            bg=self.c["bg_sidebar"], fg=self.c["fg_dim"],
            text="☀️" if self._settings.theme == "dark" else "🌙"
        )
        self.list_frame.configure(bg=self.c["bg_sidebar"])
        self.listbox.configure(
            bg=self.c["bg_sidebar"], fg=self.c["fg"],
            selectbackground=self.c["bg_entry"], selectforeground=self.c["fg_selected"]
        )
        self.btn_bar.configure(bg=self.c["bg_sidebar"])
        for btn in self.sidebar_buttons:
            btn.configure(bg=self.c["surface"], fg=self.c["fg"])

        self.main.configure(bg=self.c["bg"])
        self.lbl_acc_name.configure(bg=self.c["bg"], fg=self.c["fg_dim"])
        self.code_label.configure(bg=self.c["bg"])
        self.lbl_timer.configure(bg=self.c["bg"], fg=self.c["fg_dim"])
        self.lbl_hint.configure(bg=self.c["bg"], fg=self.c["fg_dim"])
        self.copy_btn.configure(bg=self.c["blue"], fg=self.c["bg"])

    # ── Sidebar helpers ────────────────────────────────────────────────────────

    def _refresh_sidebar(self) -> None:
        """Rebuild the listbox from in-memory accounts list."""
        self.listbox.delete(0, "end")
        for account in self._accounts:
            self.listbox.insert("end", f"  {account.name}")

        # Re-select previously selected account
        if self._selected_id:
            idx = self._index_of(self._selected_id)
            if idx is not None:
                self.listbox.selection_set(idx)
                self.listbox.activate(idx)
            else:
                # Selected account was deleted; fall back to first
                self._selected_id = self._accounts[0].id if self._accounts else None
                if self._selected_id:
                    self.listbox.selection_set(0)

        self._refresh_main_panel()

    def _on_select(self, _event: tk.Event) -> None:  # type: ignore[type-arg]
        """Handle listbox selection change."""
        sel = self.listbox.curselection()
        if not sel:
            return
        self._selected_id = self._accounts[sel[0]].id
        self._refresh_main_panel()

    def _selected_account(self) -> Account | None:
        """Return the currently selected Account, or None."""
        if self._selected_id is None:
            return None
        idx = self._index_of(self._selected_id)
        return self._accounts[idx] if idx is not None else None

    def _index_of(self, account_id: str) -> int | None:
        """Return the list index of an account by id, or None."""
        for i, a in enumerate(self._accounts):
            if a.id == account_id:
                return i
        return None

    def _navigate_up(self, _event: tk.Event = None) -> None:  # type: ignore[type-arg, assignment]
        """Select the previous account via keyboard."""
        if not self._accounts:
            return
        idx = self._index_of(self._selected_id) if self._selected_id else 0
        idx = max(0, (idx or 0) - 1)
        self.listbox.selection_clear(0, "end")
        self.listbox.selection_set(idx)
        self.listbox.activate(idx)
        self.listbox.see(idx)
        self._on_select(None)

    def _navigate_down(self, _event: tk.Event = None) -> None:  # type: ignore[type-arg, assignment]
        """Select the next account via keyboard."""
        if not self._accounts:
            return
        idx = self._index_of(self._selected_id) if self._selected_id else -1
        idx = min(len(self._accounts) - 1, (idx if idx is not None else -1) + 1)
        self.listbox.selection_clear(0, "end")
        self.listbox.selection_set(idx)
        self.listbox.activate(idx)
        self.listbox.see(idx)
        self._on_select(None)

    def _on_window_configure(self, event: tk.Event) -> None:  # type: ignore[type-arg]
        """Save the window position when it is moved."""
        if event.widget == self.root:
            self._settings.window_x = self.root.winfo_x()
            self._settings.window_y = self.root.winfo_y()
            # We don't save to file immediately to avoid spamming disk IO;
            # this gets saved via save_settings on Exit or Theme toggle.

    # ── Main panel helpers ─────────────────────────────────────────────────────

    def _refresh_main_panel(self) -> None:
        """Update main panel labels to reflect the selected account."""
        account = self._selected_account()
        if account:
            self.account_name_var.set(account.name)
            self.hint_var.set("")
            self.copy_btn.config(state="normal")
        else:
            self.account_name_var.set("")
            self.code_var.set("------")
            self.timer_var.set("")
            self.hint_var.set('Click "+ Add" to add your first account.')
            self.copy_btn.config(state="disabled")

    # ── Dialogs ────────────────────────────────────────────────────────────────

    def _open_add_dialog(self) -> None:
        """Open a dialog to add a new account."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Add Account")
        dialog.geometry("360x250")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        for row, (label_text, _) in enumerate(
            [("Account Name:", ""), ("Secret Key:", "*")]
        ):
            tk.Label(
                dialog, text=label_text, font=("Segoe UI", 10), bg=self.c["bg"], fg=self.c["fg"]
            ).grid(row=row, column=0, padx=16, pady=(18 if row == 0 else 8, 4), sticky="w")

        name_entry = tk.Entry(
            dialog, font=("Segoe UI", 10), bg=self.c["bg_entry"], fg=self.c["fg"],
            relief="flat", insertbackground="white", width=28,
        )
        name_entry.grid(row=0, column=1, padx=(0, 16), pady=(18, 4))
        name_entry.focus_set()

        secret_entry = tk.Entry(
            dialog, font=("Segoe UI", 10), bg=self.c["bg_entry"], fg=self.c["fg"],
            relief="flat", insertbackground="white", width=28, show="*",
        )
        secret_entry.grid(row=1, column=1, padx=(0, 16), pady=(0, 4))

        # URI Integration
        lbl_uri = tk.Label(
            dialog, text="Or paste otpauth:// URI:", font=("Segoe UI", 9),
            bg=self.c["bg"], fg=self.c["fg_dim"]
        )
        lbl_uri.grid(row=2, column=0, columnspan=2, pady=(12, 2))

        uri_entry = tk.Entry(
            dialog, font=("Segoe UI", 9), bg=self.c["bg_entry"], fg=self.c["fg"],
            relief="flat", insertbackground="white", width=48
        )
        uri_entry.grid(row=3, column=0, columnspan=2, padx=16, pady=(0, 4))

        def _on_uri_change(*args: object) -> None:
            uri = uri_entry.get().strip()
            if uri.startswith("otpauth://"):
                try:
                    parsed = parse_uri(uri)
                    name_entry.delete(0, "end")
                    name_entry.insert(0, parsed.name)
                    secret_entry.delete(0, "end")
                    secret_entry.insert(0, parsed.secret)
                except InvalidURIError:
                    pass

        uri_entry.bind("<KeyRelease>", _on_uri_change)

        def _save() -> None:
            name = name_entry.get().strip()
            secret = secret_entry.get().strip().replace(" ", "")
            if not name:
                messagebox.showwarning("Warning", "Account name cannot be empty.", parent=dialog)
                return
            if not validate_secret(secret):
                messagebox.showerror(
                    "Error",
                    "Invalid Secret Key.\nPlease check and try again.",
                    parent=dialog,
                )
                return
            new_account = add_account(name, secret, self._current_key)
            self._accounts = load_accounts(self._current_key)
            self._selected_id = new_account.id
            self._refresh_sidebar()
            dialog.destroy()

        btn_frame = tk.Frame(dialog, bg=self.c["bg"])
        btn_frame.grid(row=4, column=0, columnspan=2, pady=16)
        tk.Button(
            btn_frame, text="Save", font=("Segoe UI", 10, "bold"),
            bg=self.c["blue"], fg=self.c["bg"], relief="flat", padx=20, pady=5,
            cursor="hand2", command=_save,
        ).pack(side="left", padx=6)
        tk.Button(
            btn_frame, text="Cancel", font=("Segoe UI", 10),
            bg=self.c["surface"], fg=self.c["fg"], relief="flat", padx=12, pady=5,
            cursor="hand2", command=dialog.destroy,
        ).pack(side="left", padx=6)

        dialog.bind("<Return>", lambda _: _save())
        dialog.bind("<Escape>", lambda _: dialog.destroy())

    def _open_rename_dialog(self) -> None:
        """Open a simple dialog to rename the selected account."""
        account = self._selected_account()
        if not account:
            messagebox.showinfo("Info", "Please select an account first.")
            return
        new_name = simpledialog.askstring(
            "Rename Account",
            f'New name for "{account.name}":',
            initialvalue=account.name,
            parent=self.root,
        )
        if new_name and new_name.strip():
            rename_account(account.id, new_name.strip(), self._current_key)
            self._accounts = load_accounts(self._current_key)
            self._refresh_sidebar()

    def _open_delete_dialog(self) -> None:
        """Ask for confirmation, then delete the selected account."""
        account = self._selected_account()
        if not account:
            messagebox.showinfo("Info", "Please select an account first.")
            return
        confirmed = messagebox.askyesno(
            "Delete Account",
            f'Delete "{account.name}"?\nThis cannot be undone.',
            icon="warning",
            parent=self.root,
        )
        if confirmed:
            delete_account(account.id, self._current_key)
            self._accounts = load_accounts(self._current_key)
            self._selected_id = self._accounts[0].id if self._accounts else None
            self._refresh_sidebar()

    # ── Copy & update loop ─────────────────────────────────────────────────────

    def _copy_code(self) -> None:
        """Copy the current OTP code for the selected account to clipboard."""
        account = self._selected_account()
        if not account:
            return
        code = get_code(account.secret)
        if code:
            self.copy_btn.config(text="✅  Copied!", bg=self.c["green"])
            self.root.update_idletasks()  # Provide immediate visual feedback
            pyperclip.copy(code)

            if self._copy_timer:
                self.root.after_cancel(self._copy_timer)
            self._copy_timer = self.root.after(
                1500,
                lambda: self.copy_btn.config(text="📋  Copy Code", bg=self.c["blue"]),
            )
        else:
            messagebox.showerror(
                "Error",
                "Could not generate a code.\nThe secret key may be invalid.",
            )

    def _update_loop(self) -> None:
        """Refresh the OTP code and countdown timer every second."""
        if is_config_encrypted():
            timeout_secs = self._settings.lock_timeout_minutes * 60
            if time.time() - self._last_activity > timeout_secs:
                self._lock_app()
                return

        account = self._selected_account()
        if account:
            code = get_code(account.secret)
            if code:
                self.code_var.set(code)
                remaining = get_remaining_seconds()
                bar_filled = remaining // 2
                bar_empty = 15 - bar_filled
                self.timer_var.set(f"{remaining}s  {'█' * bar_filled}{'░' * bar_empty}")
                self.code_label.config(fg=self.c["red"] if remaining <= 5 else self.c["green"])
            else:
                self.code_var.set("INVALID")
                self.timer_var.set("Secret key is invalid")
                self.code_label.config(fg=self.c["red"])

        self._update_job = self.root.after(1000, self._update_loop)

    # ── Lock Screen & Security ─────────────────────────────────────────────────

    def _build_lock_screen(self) -> None:
        """Build the master password lock screen."""
        self.lock_frame = tk.Frame(self.root, bg=self.c["bg"])
        self.lock_frame.pack(fill="both", expand=True)

        tk.Label(
            self.lock_frame, text="🔒 App Locked", font=("Segoe UI", 16, "bold"),
            bg=self.c["bg"], fg=self.c["fg"],
        ).pack(pady=(50, 16))

        tk.Label(
            self.lock_frame, text="Enter Master Password:", font=("Segoe UI", 10),
            bg=self.c["bg"], fg=self.c["fg_dim"],
        ).pack(pady=(0, 8))

        self.pwd_entry = tk.Entry(
            self.lock_frame, font=("Segoe UI", 14), bg=self.c["bg_entry"], fg=self.c["fg"],
            relief="flat", insertbackground="white", width=20, show="*", justify="center",
        )
        self.pwd_entry.pack(pady=8)
        self.pwd_entry.focus_set()

        self.lbl_pwd_error = tk.Label(
            self.lock_frame, text="", font=("Segoe UI", 9), bg=self.c["bg"], fg=self.c["red"]
        )
        self.lbl_pwd_error.pack()

        btn = tk.Button(
            self.lock_frame, text="Unlock", font=("Segoe UI", 11, "bold"),
            bg=self.c["blue"], fg=self.c["bg"], relief="flat", padx=24, pady=6,
            cursor="hand2", command=self._try_unlock,
        )
        btn.pack(pady=(16, 8))

        btn_reset = tk.Button(
            self.lock_frame,
            text="Forgot password? Reset vault",
            font=("Segoe UI", 9, "underline"),
            bg=self.c["bg"],
            fg=self.c["fg_dim"],
            activebackground=self.c["bg"],
            activeforeground=self.c["red"],
            relief="flat",
            borderwidth=0,
            cursor="hand2",
            command=self._confirm_reset_vault,
        )
        btn_reset.pack(pady=(0, 10))

        self.root.bind("<Return>", lambda e: self._try_unlock())

    def _try_unlock(self) -> None:
        pwd = self.pwd_entry.get()
        try:
            key = verify_password(pwd)
            self.root.unbind("<Return>")
            self._init_main_app(key)
        except InvalidPasswordError:
            self.pwd_entry.delete(0, "end")
            self.lbl_pwd_error.config(text="Incorrect password. Please try again.")

    def _confirm_reset_vault(self) -> None:
        """Open a confirmation modal to reset vault and master password."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Reset Vault Confirmation")
        dialog.geometry("420x290")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.transient(self.root)

        tk.Label(
            dialog,
            text="⚠️ Reset Master Password",
            font=("Segoe UI", 13, "bold"),
            bg=self.c["bg"],
            fg=self.c["red"],
        ).pack(pady=(18, 8))

        warning_text = (
            "Resetting your vault will remove password protection\n"
            "and permanently delete all encrypted accounts.\n\n"
            "An automatic backup of your current config will be\n"
            "saved to your home directory before wiping.\n\n"
            "Type RESET to confirm:"
        )
        tk.Label(
            dialog,
            text=warning_text,
            font=("Segoe UI", 9),
            bg=self.c["bg"],
            fg=self.c["fg"],
            justify="center",
        ).pack(pady=(0, 10))

        confirm_entry = tk.Entry(
            dialog,
            font=("Segoe UI", 11),
            bg=self.c["bg_entry"],
            fg=self.c["fg"],
            relief="flat",
            insertbackground="white",
            width=14,
            justify="center",
        )
        confirm_entry.pack(pady=4)
        confirm_entry.focus_set()

        lbl_error = tk.Label(
            dialog, text="", font=("Segoe UI", 8), bg=self.c["bg"], fg=self.c["red"]
        )
        lbl_error.pack()

        btn_box = tk.Frame(dialog, bg=self.c["bg"])
        btn_box.pack(pady=14)

        def _do_reset() -> None:
            if confirm_entry.get().strip().upper() != "RESET":
                lbl_error.config(text="Please type RESET to proceed.")
                return

            backup_path = reset_vault(backup=True)
            dialog.destroy()

            backup_msg = f"\n\nA backup copy was created at:\n{backup_path}" if backup_path else ""
            messagebox.showinfo(
                "Vault Reset",
                (
                    f"Your vault has been reset successfully.{backup_msg}\n\n"
                    "You can now use the app or set a new password in Security Settings."
                ),
                parent=self.root,
            )

            # Unbind lock screen hotkeys and transition to clean main app
            self.root.unbind("<Return>")
            self._init_main_app(None)

        btn_cancel = tk.Button(
            btn_box,
            text="Cancel",
            font=("Segoe UI", 9),
            bg=self.c["surface"],
            fg=self.c["fg"],
            relief="flat",
            padx=14,
            pady=4,
            cursor="hand2",
            command=dialog.destroy,
        )
        btn_cancel.pack(side="left", padx=8)

        btn_confirm = tk.Button(
            btn_box,
            text="Reset Vault",
            font=("Segoe UI", 9, "bold"),
            bg=self.c["red"],
            fg=self.c["bg"],
            relief="flat",
            padx=14,
            pady=4,
            cursor="hand2",
            command=_do_reset,
        )
        btn_confirm.pack(side="left", padx=8)

        confirm_entry.bind("<Return>", lambda e: _do_reset())

    def _open_security_dialog(self) -> None:
        dialog = tk.Toplevel(self.root)
        dialog.title("Security Settings")
        dialog.geometry("380x380")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        is_enc = is_config_encrypted()
        status_text = "Status: Locked 🔒" if is_enc else "Status: Unlocked 🔓"
        tk.Label(
            dialog, text=status_text, font=("Segoe UI", 11, "bold"),
            bg=self.c["bg"], fg=self.c["fg"]
        ).pack(pady=16)

        # Timeout setting
        frame_time = tk.Frame(dialog, bg=self.c["bg"])
        frame_time.pack(pady=10)
        tk.Label(
            frame_time, text="Auto-lock timeout (minutes):", font=("Segoe UI", 9),
            bg=self.c["bg"], fg=self.c["fg"]
        ).pack(side="left", padx=8)

        timeout_var = tk.StringVar(value=str(self._settings.lock_timeout_minutes))
        tk.Entry(
            frame_time, textvariable=timeout_var, width=5, justify="center",
            bg=self.c["bg_entry"], fg=self.c["fg"], relief="flat", insertbackground="white"
        ).pack(side="left")

        # Password setting
        frame_pwd = tk.Frame(dialog, bg=self.c["bg"])
        frame_pwd.pack(pady=10, fill="x", padx=20)

        tk.Label(
            frame_pwd, text="New Password:", font=("Segoe UI", 9),
            bg=self.c["bg"], fg=self.c["fg"], anchor="w"
        ).pack(fill="x")
        pwd_entry = tk.Entry(
            frame_pwd,
            show="*",
            bg=self.c["bg_entry"],
            fg=self.c["fg"],
            relief="flat",
            insertbackground="white"
        )
        pwd_entry.pack(fill="x", pady=(4, 10))

        def _save() -> None:
            try:
                mins = int(timeout_var.get())
                self._settings.lock_timeout_minutes = max(1, mins)
                save_settings(self._settings)
            except ValueError:
                pass

            pwd = pwd_entry.get()
            if pwd:
                self._current_key = set_encryption(pwd, self._current_key)
                messagebox.showinfo("Success", "Password updated successfully.", parent=dialog)
            dialog.destroy()

        def _remove() -> None:
            msg = (
                "Are you sure you want to remove password protection?\n"
                "Secrets will be stored in plaintext."
            )
            if messagebox.askyesno("Remove Password", msg, parent=dialog):
                if self._current_key:
                    remove_encryption(self._current_key)
                    self._current_key = None
                    messagebox.showinfo("Success", "Password protection removed.", parent=dialog)
                dialog.destroy()

        tk.Button(
            dialog,
            text="Save Settings",
            font=("Segoe UI", 10, "bold"),
            bg=self.c["blue"],
            fg=self.c["bg"],
            relief="flat",
            cursor="hand2",
            command=_save,
        ).pack(pady=10)

        if is_enc:
            tk.Button(
                dialog,
                text="Remove Password",
                font=("Segoe UI", 9),
                bg=self.c["red"],
                fg=self.c["bg"],
                relief="flat",
                cursor="hand2",
                command=_remove,
            ).pack(pady=5)

        def _export_backup() -> None:
            path = filedialog.asksaveasfilename(
                title="Export Encrypted Backup",
                defaultextension=".totp_backup",
                filetypes=[("TOTP Backup Files", "*.totp_backup")],
                parent=dialog
            )
            if not path:
                return
            pwd = simpledialog.askstring(
                "Backup Password", "Create a password to encrypt this backup:",
                show="*", parent=dialog
            )
            if not pwd:
                return
            try:
                create_backup(pwd, path, self._current_key)
                messagebox.showinfo(
                    "Success", f"Backup created successfully at:\n{path}", parent=dialog
                )
            except Exception as e:
                messagebox.showerror("Export Failed", str(e), parent=dialog)

        def _import_backup() -> None:
            path = filedialog.askopenfilename(
                title="Restore from Backup",
                defaultextension=".totp_backup",
                filetypes=[("TOTP Backup Files", "*.totp_backup")],
                parent=dialog
            )
            if not path:
                return
            pwd = simpledialog.askstring(
                "Backup Password", "Enter the password for this backup:",
                show="*", parent=dialog
            )
            if not pwd:
                return
            try:
                added = restore_backup(pwd, path, self._current_key)
                self._accounts = load_accounts(self._current_key)
                self._refresh_sidebar()
                messagebox.showinfo("Success", f"Restored {added} new account(s).", parent=dialog)
            except InvalidPasswordError:
                messagebox.showerror(
                    "Import Failed", "Incorrect password or corrupted backup.", parent=dialog
                )
            except Exception as e:
                messagebox.showerror("Import Failed", str(e), parent=dialog)

        tk.Frame(dialog, height=1, bg=self.c["fg_dim"]).pack(fill="x", padx=30, pady=10)

        lbl_backup = tk.Label(
            dialog, text="Data Backup & Restore:", font=("Segoe UI", 9, "bold"),
            bg=self.c["bg"], fg=self.c["fg"]
        )
        lbl_backup.pack(pady=(0, 5))

        backup_frame = tk.Frame(dialog, bg=self.c["bg"])
        backup_frame.pack(pady=5)
        tk.Button(
            backup_frame, text="Export Backup", font=("Segoe UI", 9),
            bg=self.c["surface"], fg=self.c["fg"], relief="flat",
            cursor="hand2", command=_export_backup
        ).pack(side="left", padx=5)

        tk.Button(
            backup_frame, text="Import Backup", font=("Segoe UI", 9),
            bg=self.c["surface"], fg=self.c["fg"], relief="flat",
            cursor="hand2", command=_import_backup
        ).pack(side="left", padx=5)

    def _open_sync_dialog(self) -> None:
        dialog = tk.Toplevel(self.root)
        dialog.title("Cloud Sync")
        dialog.geometry("380x450")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        def _refresh_ui() -> None:
            for w in dialog.winfo_children():
                w.destroy()

            tk.Label(
                dialog, text="Cloud Sync (E2EE) ☁️", font=("Segoe UI", 12, "bold"),
                bg=self.c["bg"], fg=self.c["fg"], pady=10
            ).pack()

            if self._settings.sync_token:
                # Logged in UI
                tk.Label(
                    dialog,
                    text="Status: Connected to Server",
                    bg=self.c["bg"],
                    fg=self.c["green"],
                    font=("Segoe UI", 10),
                ).pack(pady=5)

                def _do_sync(action: str) -> None:
                    pwd = simpledialog.askstring(
                        "E2EE Password",
                        f"Enter E2EE/Sync Password to {action} data:",
                        show="*",
                        parent=dialog,
                    )
                    if not pwd:
                        return

                    manager = SyncManager(self._settings, pwd)
                    try:
                        if action == "Push":
                            manager.push()
                            messagebox.showinfo(
                                "Success", "Data securely pushed to cloud.", parent=dialog
                            )
                        else:
                            manager.pull_and_merge()
                            self._accounts = load_accounts(self._current_key)
                            self._refresh_sidebar()
                            messagebox.showinfo(
                                "Success",
                                "Data pulled and merged to local device.",
                                parent=dialog,
                            )
                    except (AuthenticationError, ConflictError, SyncClientError) as e:
                        messagebox.showerror("Sync Error", str(e), parent=dialog)
                    except Exception as e:
                        messagebox.showerror("Error", f"Failed: {e}", parent=dialog)

                tk.Button(
                    dialog,
                    text="Pull down from Cloud (Merge)",
                    bg=self.c["surface"],
                    fg=self.c["fg"],
                    cursor="hand2",
                    command=lambda: _do_sync("Pull"),
                ).pack(pady=10, fill="x", padx=40)
                tk.Button(
                    dialog,
                    text="Push up to Cloud",
                    bg=self.c["surface"],
                    fg=self.c["fg"],
                    cursor="hand2",
                    command=lambda: _do_sync("Push"),
                ).pack(pady=10, fill="x", padx=40)

                def _logout() -> None:
                    self._settings.sync_token = ""
                    save_settings(self._settings)
                    _refresh_ui()

                tk.Button(
                    dialog,
                    text="Logout",
                    bg=self.c["red"],
                    fg=self.c["bg"],
                    cursor="hand2",
                    command=_logout,
                ).pack(pady=30)

            else:
                # Login UI
                tk.Label(
                    dialog, text="Server URL:", bg=self.c["bg"], fg=self.c["fg"]
                ).pack(anchor="w", padx=40)
                url_entry = tk.Entry(
                    dialog, bg=self.c["bg_entry"], fg=self.c["fg"], insertbackground="white"
                )
                url_entry.insert(0, self._settings.sync_server_url)
                url_entry.pack(fill="x", padx=40, pady=2)

                tk.Label(
                    dialog, text="Username:", bg=self.c["bg"], fg=self.c["fg"]
                ).pack(anchor="w", padx=40, pady=(15, 0))
                user_entry = tk.Entry(
                    dialog, bg=self.c["bg_entry"], fg=self.c["fg"], insertbackground="white"
                )
                user_entry.pack(fill="x", padx=40, pady=2)

                tk.Label(
                    dialog, text="Password:", bg=self.c["bg"], fg=self.c["fg"]
                ).pack(anchor="w", padx=40, pady=(10, 0))
                pwd_entry = tk.Entry(
                    dialog,
                    show="*",
                    bg=self.c["bg_entry"],
                    fg=self.c["fg"],
                    insertbackground="white",
                )
                pwd_entry.pack(fill="x", padx=40, pady=2)

                def _auth(is_register: bool) -> None:
                    self._settings.sync_server_url = url_entry.get().strip()
                    save_settings(self._settings)

                    u = user_entry.get().strip()
                    p = pwd_entry.get().strip()
                    if not u or not p:
                        messagebox.showerror("Error", "Missing credentials", parent=dialog)
                        return

                    manager = SyncManager(self._settings, p)
                    try:
                        # For login API we only need any string as sync_password
                        if is_register:
                            manager.client.register(u, p)
                            messagebox.showinfo(
                                "Success", "Registered! You can now log in.", parent=dialog
                            )
                        else:
                            manager.client.login(u, p)
                            self._settings.sync_token = manager.client.token
                            save_settings(self._settings)
                            _refresh_ui()
                    except Exception as e:
                        messagebox.showerror("Error", str(e), parent=dialog)

                tk.Button(
                    dialog,
                    text="Login",
                    bg=self.c["blue"],
                    fg=self.c["bg"],
                    font=("Segoe UI", 10, "bold"),
                    cursor="hand2",
                    command=lambda: _auth(False),
                ).pack(pady=20)
                tk.Button(
                    dialog,
                    text="Register new Account",
                    bg=self.c["surface"],
                    fg=self.c["fg"],
                    cursor="hand2",
                    command=lambda: _auth(True),
                ).pack()

        _refresh_ui()

