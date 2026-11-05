"""TOTP Authenticator UI — modern Windows 11 Fluent Tkinter desktop interface."""

import time
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog

import pyperclip

from totp_authenticator.api import ConflictError
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

# ── Colour palettes (Windows 11 Fluent & Modern Slate) ─────────────────────
THEMES = {
    "dark": {
        "bg": "#0b0f19",
        "bg_sidebar": "#111827",
        "bg_card": "#1e293b",
        "bg_card_hover": "#283548",
        "bg_card_selected": "#1e3a5f",
        "bg_entry": "#1e293b",
        "border": "#334155",
        "border_focus": "#38bdf8",
        "fg": "#f8fafc",
        "fg_dim": "#94a3b8",
        "fg_selected": "#38bdf8",
        "blue": "#2563eb",
        "blue_hover": "#1d4ed8",
        "green": "#22c55e",
        "amber": "#f59e0b",
        "red": "#ef4444",
        "surface": "#1e293b",
        "surface_hover": "#334155",
        "progress_bg": "#1e293b",
    },
    "light": {
        "bg": "#f8fafc",
        "bg_sidebar": "#f1f5f9",
        "bg_card": "#ffffff",
        "bg_card_hover": "#f1f5f9",
        "bg_card_selected": "#e0f2fe",
        "bg_entry": "#ffffff",
        "border": "#cbd5e1",
        "border_focus": "#2563eb",
        "fg": "#0f172a",
        "fg_dim": "#64748b",
        "fg_selected": "#0284c7",
        "blue": "#2563eb",
        "blue_hover": "#1d4ed8",
        "green": "#16a34a",
        "amber": "#d97706",
        "red": "#dc2626",
        "surface": "#e2e8f0",
        "surface_hover": "#cbd5e1",
        "progress_bg": "#e2e8f0",
    },
}

AVATAR_PALETTE = [
    ("#2563eb", "#ffffff"),  # Blue
    ("#7c3aed", "#ffffff"),  # Purple
    ("#db2777", "#ffffff"),  # Pink
    ("#059669", "#ffffff"),  # Emerald
    ("#d97706", "#ffffff"),  # Amber
    ("#0891b2", "#ffffff"),  # Cyan
    ("#4f46e5", "#ffffff"),  # Indigo
]


def get_avatar_colors(name: str) -> tuple[str, str]:
    """Deterministically pick an avatar background and foreground color."""
    idx = sum(ord(c) for c in name) % len(AVATAR_PALETTE)
    return AVATAR_PALETTE[idx]


def get_initials(name: str) -> str:
    """Get 1-2 character initials for an account display."""
    parts = name.strip().split()
    if not parts:
        return "?"
    if len(parts) == 1:
        return parts[0][:2].upper()
    return (parts[0][0] + parts[-1][0]).upper()


class TOTPApp:
    """Main application window for the TOTP Authenticator (multi-account)."""

    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("TOTP Authenticator")
        self.root.resizable(False, False)
        self.root.attributes("-topmost", True)

        self._settings = load_settings()
        self.c = THEMES.get(self._settings.theme, THEMES["dark"])

        width, height = 680, 430
        if self._settings.window_x is not None and self._settings.window_y is not None:
            self.root.geometry(
                f"{width}x{height}+{self._settings.window_x}+{self._settings.window_y}"
            )
        else:
            self.root.geometry(f"{width}x{height}")

        self.root.configure(bg=self.c["bg"])
        self._copy_timer: str | None = None
        self._current_key: bytes | None = None
        self._last_activity = time.time()
        self._update_job: str | None = None
        self._card_widgets: dict[str, list[tk.Widget]] = {}

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

    # ── UI Builder Helpers ─────────────────────────────────────────────────────

    def _create_modern_entry(
        self,
        parent: tk.Widget,
        width: int = 28,
        show: str = "",
        justify: str = "left",
    ) -> tuple[tk.Frame, tk.Entry]:
        """Create a modern styled text entry with a 1px border and focus ring."""
        container = tk.Frame(parent, bg=self.c["border"], padx=1, pady=1)
        entry = tk.Entry(
            container,
            font=("Segoe UI", 10),
            bg=self.c["bg_entry"],
            fg=self.c["fg"],
            relief="flat",
            insertbackground=self.c["fg"],
            width=width,
            show=show,
            justify=justify,
        )
        entry.pack(fill="both", expand=True, ipady=5, padx=6)

        def _on_focus_in(_event: tk.Event = None) -> None:  # type: ignore[assignment]
            container.configure(bg=self.c["border_focus"])

        def _on_focus_out(_event: tk.Event = None) -> None:  # type: ignore[assignment]
            container.configure(bg=self.c["border"])

        entry.bind("<FocusIn>", _on_focus_in)
        entry.bind("<FocusOut>", _on_focus_out)
        entry.on_focus_in = _on_focus_in  # type: ignore[attr-defined]
        entry.on_focus_out = _on_focus_out  # type: ignore[attr-defined]
        return container, entry

    def _create_pill_button(
        self,
        parent: tk.Widget,
        text: str,
        command: object,
        is_primary: bool = False,
        is_danger: bool = False,
        font: tuple = ("Segoe UI", 9, "bold"),
        padx: int = 14,
        pady: int = 5,
    ) -> tk.Button:
        """Create a modern button with flat relief and hover highlight."""
        if is_danger:
            bg = self.c["red"]
            fg = "#ffffff"
            hover_bg = "#b91c1c"
        elif is_primary:
            bg = self.c["blue"]
            fg = "#ffffff"
            hover_bg = self.c["blue_hover"]
        else:
            bg = self.c["surface"]
            fg = self.c["fg"]
            hover_bg = self.c["surface_hover"]

        btn = tk.Button(
            parent,
            text=text,
            font=font,
            bg=bg,
            fg=fg,
            activebackground=hover_bg,
            activeforeground=fg,
            relief="flat",
            borderwidth=0,
            padx=padx,
            pady=pady,
            cursor="hand2",
            command=command,
        )

        def _on_enter(_e: tk.Event) -> None:
            btn.configure(bg=hover_bg)

        def _on_leave(_e: tk.Event) -> None:
            btn.configure(bg=bg)

        btn.bind("<Enter>", _on_enter)
        btn.bind("<Leave>", _on_leave)
        return btn

    # ── Main UI Tree ───────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        """Construct the two-panel widget tree."""
        # ── Sidebar (left) ─────────────────────────────────────────────────────
        self.sidebar = tk.Frame(self.root, bg=self.c["bg_sidebar"], width=230)
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)

        # Header contains "Accounts" label and action buttons
        self.header_frame = tk.Frame(self.sidebar, bg=self.c["bg_sidebar"])
        self.header_frame.pack(fill="x", pady=(16, 10), padx=12)

        self.lbl_accounts = tk.Label(
            self.header_frame,
            text="Accounts (0)",
            font=("Segoe UI", 11, "bold"),
            bg=self.c["bg_sidebar"],
            fg=self.c["fg"],
        )
        self.lbl_accounts.pack(side="left")

        # Header Action Buttons
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
        self.btn_theme_toggle.pack(side="right", padx=(2, 0))

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
        self.btn_sync.pack(side="right", padx=2)

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
        self.btn_security.pack(side="right", padx=2)

        # Card-based scrollable container
        self.list_frame = tk.Frame(self.sidebar, bg=self.c["bg_sidebar"])
        self.list_frame.pack(fill="both", expand=True, padx=4)

        self.card_canvas = tk.Canvas(
            self.list_frame,
            bg=self.c["bg_sidebar"],
            highlightthickness=0,
            borderwidth=0,
        )
        self.card_frame = tk.Frame(self.card_canvas, bg=self.c["bg_sidebar"])
        self.card_window = self.card_canvas.create_window(
            (0, 0), window=self.card_frame, anchor="nw"
        )

        def _on_card_frame_configure(_e: tk.Event = None) -> None:  # type: ignore[assignment]
            self.card_canvas.configure(scrollregion=self.card_canvas.bbox("all"))

        def _on_card_canvas_configure(e: tk.Event) -> None:
            self.card_canvas.itemconfig(self.card_window, width=e.width)

        self.card_frame.bind("<Configure>", _on_card_frame_configure)
        self.card_canvas.bind("<Configure>", _on_card_canvas_configure)
        self.card_canvas.pack(side="left", fill="both", expand=True)

        def _on_mousewheel(e: tk.Event) -> None:
            self.card_canvas.yview_scroll(int(-1 * (e.delta / 120)), "units")

        self.card_canvas.bind(
            "<Enter>", lambda _e: self.card_canvas.bind_all("<MouseWheel>", _on_mousewheel)
        )
        self.card_canvas.bind(
            "<Leave>", lambda _e: self.card_canvas.unbind_all("<MouseWheel>")
        )

        # Sidebar action buttons
        self.btn_bar = tk.Frame(self.sidebar, bg=self.c["bg_sidebar"])
        self.btn_bar.pack(fill="x", padx=10, pady=(8, 12))

        self.sidebar_buttons = []

        btn_add = self._create_pill_button(
            self.btn_bar,
            text="+ Add",
            command=self._open_add_dialog,
            is_primary=True,
            font=("Segoe UI", 9, "bold"),
            padx=10,
            pady=4,
        )
        btn_add.pack(side="left", padx=(0, 4))
        self.sidebar_buttons.append(btn_add)

        btn_rename = self._create_pill_button(
            self.btn_bar,
            text="Rename",
            command=self._open_rename_dialog,
            font=("Segoe UI", 9),
            padx=8,
            pady=4,
        )
        btn_rename.pack(side="left", padx=2)
        self.sidebar_buttons.append(btn_rename)

        btn_delete = self._create_pill_button(
            self.btn_bar,
            text="Delete",
            command=self._open_delete_dialog,
            font=("Segoe UI", 9),
            padx=8,
            pady=4,
        )
        btn_delete.pack(side="left", padx=2)
        self.sidebar_buttons.append(btn_delete)

        # ── Main panel (right) ─────────────────────────────────────────────────
        self.main = tk.Frame(self.root, bg=self.c["bg"])
        self.main.pack(side="left", fill="both", expand=True)

        # 1. Active Code Display Container
        self.code_container = tk.Frame(self.main, bg=self.c["bg"])

        self.account_name_var = tk.StringVar(value="")
        self.lbl_acc_name = tk.Label(
            self.code_container,
            textvariable=self.account_name_var,
            font=("Segoe UI", 15, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        )
        self.lbl_acc_name.pack(pady=(40, 4))

        self.lbl_acc_badge = tk.Label(
            self.code_container,
            text="RFC 6238 · SHA-1 · 30s",
            font=("Segoe UI", 8, "bold"),
            bg=self.c["surface"],
            fg=self.c["fg_dim"],
            padx=8,
            pady=2,
        )
        self.lbl_acc_badge.pack(pady=(0, 16))

        self.code_var = tk.StringVar(value="------")
        self.code_label = tk.Label(
            self.code_container,
            textvariable=self.code_var,
            font=("Segoe UI", 38, "bold"),
            bg=self.c["bg"],
            fg=self.c["green"],
        )
        self.code_label.pack(pady=(0, 6))

        # Modern Progress Bar
        self.progress_canvas = tk.Canvas(
            self.code_container,
            width=240,
            height=6,
            bg=self.c["progress_bg"],
            highlightthickness=0,
            borderwidth=0,
        )
        self.progress_canvas.pack(pady=(0, 6))

        self.timer_var = tk.StringVar(value="")
        self.lbl_timer = tk.Label(
            self.code_container,
            textvariable=self.timer_var,
            font=("Segoe UI", 9),
            bg=self.c["bg"],
            fg=self.c["fg_dim"],
        )
        self.lbl_timer.pack(pady=(0, 18))

        self.copy_btn = tk.Button(
            self.code_container,
            text="📋  Copy Code",
            font=("Segoe UI", 10, "bold"),
            bg=self.c["blue"],
            fg="#ffffff",
            activebackground=self.c["blue_hover"],
            activeforeground="#ffffff",
            relief="flat",
            borderwidth=0,
            padx=24,
            pady=7,
            cursor="hand2",
            command=self._copy_code,
        )
        self.copy_btn.pack(pady=(0, 10))

        # 2. Empty State Container
        self.empty_frame = tk.Frame(self.main, bg=self.c["bg"])

        icon_cv = tk.Canvas(
            self.empty_frame,
            width=56,
            height=56,
            bg=self.c["bg"],
            highlightthickness=0,
        )
        icon_cv.pack(pady=(60, 14))
        icon_cv.create_oval(4, 4, 52, 52, fill=self.c["surface"], outline="")
        icon_cv.create_text(28, 28, text="🔐", font=("Segoe UI", 20))

        tk.Label(
            self.empty_frame,
            text="No Accounts Yet",
            font=("Segoe UI", 14, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(pady=(0, 6))

        tk.Label(
            self.empty_frame,
            text="Add your first 2FA account to begin generating secure time-based OTP codes.",
            font=("Segoe UI", 9),
            bg=self.c["bg"],
            fg=self.c["fg_dim"],
            wraplength=280,
            justify="center",
        ).pack(pady=(0, 20))

        btn_empty_add = self._create_pill_button(
            self.empty_frame,
            text="➕  Add Your First Account",
            command=self._open_add_dialog,
            is_primary=True,
            font=("Segoe UI", 10, "bold"),
            padx=20,
            pady=8,
        )
        btn_empty_add.pack()

    def _toggle_theme(self) -> None:
        """Switch between light and dark themes and update UI."""
        self._settings.theme = "light" if self._settings.theme == "dark" else "dark"
        save_settings(self._settings)
        self.c = THEMES[self._settings.theme]

        self.root.configure(bg=self.c["bg"])
        self.sidebar.configure(bg=self.c["bg_sidebar"])
        self.header_frame.configure(bg=self.c["bg_sidebar"])
        self.lbl_accounts.configure(bg=self.c["bg_sidebar"], fg=self.c["fg"])
        self.btn_security.configure(bg=self.c["bg_sidebar"], fg=self.c["fg_dim"])
        self.btn_sync.configure(bg=self.c["bg_sidebar"], fg=self.c["fg_dim"])
        self.btn_theme_toggle.configure(
            bg=self.c["bg_sidebar"],
            fg=self.c["fg_dim"],
            text="☀️" if self._settings.theme == "dark" else "🌙",
        )
        self.list_frame.configure(bg=self.c["bg_sidebar"])
        self.card_canvas.configure(bg=self.c["bg_sidebar"])
        self.card_frame.configure(bg=self.c["bg_sidebar"])
        self.btn_bar.configure(bg=self.c["bg_sidebar"])

        for btn in self.sidebar_buttons:
            if btn.cget("text") == "+ Add":
                btn.configure(bg=self.c["blue"], fg="#ffffff")
            else:
                btn.configure(bg=self.c["surface"], fg=self.c["fg"])

        self.main.configure(bg=self.c["bg"])
        self.code_container.configure(bg=self.c["bg"])
        self.lbl_acc_name.configure(bg=self.c["bg"], fg=self.c["fg"])
        self.lbl_acc_badge.configure(bg=self.c["surface"], fg=self.c["fg_dim"])
        self.code_label.configure(bg=self.c["bg"])
        self.lbl_timer.configure(bg=self.c["bg"], fg=self.c["fg_dim"])
        self.progress_canvas.configure(bg=self.c["progress_bg"])
        self.copy_btn.configure(bg=self.c["blue"], fg="#ffffff")

        self.empty_frame.configure(bg=self.c["bg"])
        for w in self.empty_frame.winfo_children():
            if isinstance(w, tk.Label):
                is_title = "Accounts" in w.cget("text")
                w.configure(bg=self.c["bg"], fg=self.c["fg"] if is_title else self.c["fg_dim"])

        self._refresh_sidebar()

    # ── Sidebar & Account Cards ────────────────────────────────────────────────

    def _refresh_sidebar(self) -> None:
        """Rebuild the card list from in-memory accounts list."""
        self.lbl_accounts.configure(text=f"Accounts ({len(self._accounts)})")

        for w in self.card_frame.winfo_children():
            w.destroy()
        self._card_widgets.clear()

        # Context Menu
        menu = tk.Menu(self.root, tearoff=0)
        menu.add_command(label="📋  Copy Code", command=self._copy_code)
        menu.add_command(label="✏️  Rename", command=self._open_rename_dialog)
        menu.add_command(label="🗑️  Delete", command=self._open_delete_dialog)

        # Context menu launcher
        def _popup_menu(e: tk.Event, acc_id: str) -> None:
            self._select_account(acc_id)
            menu.tk_popup(e.x_root, e.y_root)

        for account in self._accounts:
            is_selected = account.id == self._selected_id
            card_bg = self.c["bg_card_selected"] if is_selected else self.c["bg_sidebar"]
            name_color = self.c["fg_selected"] if is_selected else self.c["fg"]

            card = tk.Frame(self.card_frame, bg=card_bg, cursor="hand2")
            card.pack(fill="x", padx=6, pady=2)

            stripe = tk.Frame(
                card,
                width=3,
                bg=self.c["blue"] if is_selected else card_bg,
            )
            stripe.pack(side="left", fill="y", padx=(0, 6))

            # Avatar circle
            av_bg, av_fg = get_avatar_colors(account.name)
            initials = get_initials(account.name)

            cv = tk.Canvas(card, width=30, height=30, bg=card_bg, highlightthickness=0)
            cv.pack(side="left", padx=(0, 8), pady=4)
            cv.create_oval(2, 2, 28, 28, fill=av_bg, outline="")
            cv.create_text(15, 15, text=initials, fill=av_fg, font=("Segoe UI", 9, "bold"))

            text_box = tk.Frame(card, bg=card_bg)
            text_box.pack(side="left", fill="x", expand=True, pady=4)

            lbl_name = tk.Label(
                text_box,
                text=account.name,
                font=("Segoe UI", 9, "bold"),
                bg=card_bg,
                fg=name_color,
                anchor="w",
            )
            lbl_name.pack(fill="x")

            lbl_sub = tk.Label(
                text_box,
                text="TOTP · 30s",
                font=("Segoe UI", 8),
                bg=card_bg,
                fg=self.c["fg_dim"],
                anchor="w",
            )
            lbl_sub.pack(fill="x")

            widgets = [card, stripe, cv, text_box, lbl_name, lbl_sub]
            self._card_widgets[account.id] = widgets

            acc_id = account.id

            def _on_click(_e: tk.Event, i: str = acc_id) -> None:
                self._select_account(i)

            def _on_hover_enter(
                _e: tk.Event, wl: list[tk.Widget] = widgets, i: str = acc_id
            ) -> None:
                if i != self._selected_id:
                    for widget in (wl[0], wl[2], wl[3], wl[4], wl[5]):
                        widget.configure(bg=self.c["bg_card_hover"])

            def _on_hover_leave(
                _e: tk.Event, wl: list[tk.Widget] = widgets, i: str = acc_id
            ) -> None:
                if i != self._selected_id:
                    for widget in (wl[0], wl[2], wl[3], wl[4], wl[5]):
                        widget.configure(bg=self.c["bg_sidebar"])

            for w in widgets:
                w.bind("<Button-1>", _on_click)
                w.bind("<Button-3>", lambda e, i=acc_id: _popup_menu(e, i))
                w.bind("<Enter>", _on_hover_enter)
                w.bind("<Leave>", _on_hover_leave)

        self._refresh_main_panel()

    def _select_account(self, account_id: str) -> None:
        """Select an account by id and update UI views."""
        self._selected_id = account_id
        self._refresh_sidebar()

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

    def _navigate_up(self, _event: tk.Event = None) -> None:  # type: ignore[assignment]
        """Select the previous account via keyboard."""
        if not self._accounts:
            return
        idx = self._index_of(self._selected_id) if self._selected_id else 0
        idx = max(0, (idx or 0) - 1)
        self._select_account(self._accounts[idx].id)

    def _navigate_down(self, _event: tk.Event = None) -> None:  # type: ignore[assignment]
        """Select the next account via keyboard."""
        if not self._accounts:
            return
        idx = self._index_of(self._selected_id) if self._selected_id else -1
        idx = min(len(self._accounts) - 1, (idx if idx is not None else -1) + 1)
        self._select_account(self._accounts[idx].id)

    def _on_window_configure(self, event: tk.Event) -> None:  # type: ignore[type-arg]
        """Save the window position when it is moved."""
        if event.widget == self.root:
            self._settings.window_x = self.root.winfo_x()
            self._settings.window_y = self.root.winfo_y()

    # ── Main Panel Helpers ─────────────────────────────────────────────────────

    def _refresh_main_panel(self) -> None:
        """Update main panel labels to reflect the selected account or show empty state."""
        account = self._selected_account()
        if account:
            self.empty_frame.pack_forget()
            self.code_container.pack(fill="both", expand=True)
            self.account_name_var.set(account.name)
            self.copy_btn.config(state="normal")
        else:
            self.code_container.pack_forget()
            self.empty_frame.pack(fill="both", expand=True)
            self.account_name_var.set("")
            self.code_var.set("------")
            self.timer_var.set("")
            self.copy_btn.config(state="disabled")

    def _update_progress_bar(self, remaining: int, color: str) -> None:
        """Draw an animated horizontal progress bar."""
        if not hasattr(self, "progress_canvas"):
            return
        self.progress_canvas.delete("all")
        width = 240
        height = 6
        self.progress_canvas.create_rectangle(
            0, 0, width, height, fill=self.c["progress_bg"], outline=""
        )
        bar_w = int(width * (max(0, min(30, remaining)) / 30.0))
        if bar_w > 0:
            self.progress_canvas.create_rectangle(
                0, 0, bar_w, height, fill=color, outline=""
            )

    # ── Dialogs ────────────────────────────────────────────────────────────────

    def _open_add_dialog(self) -> None:
        """Open a modern dialog to add a new account."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Add Account")
        dialog.geometry("420x350")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        # Header
        header = tk.Frame(dialog, bg=self.c["bg"])
        header.pack(fill="x", padx=24, pady=(20, 14))

        tk.Label(
            header, text="➕ Add 2FA Account", font=("Segoe UI", 12, "bold"),
            bg=self.c["bg"], fg=self.c["fg"]
        ).pack(anchor="w")
        tk.Label(
            header, text="Enter account details or paste an otpauth:// URI",
            font=("Segoe UI", 9), bg=self.c["bg"], fg=self.c["fg_dim"]
        ).pack(anchor="w", pady=(2, 0))

        # Form fields
        form = tk.Frame(dialog, bg=self.c["bg"])
        form.pack(fill="x", padx=24)

        tk.Label(
            form, text="Account Name", font=("Segoe UI", 9, "bold"),
            bg=self.c["bg"], fg=self.c["fg"]
        ).pack(anchor="w", pady=(0, 2))
        name_container, name_entry = self._create_modern_entry(form, width=36)
        name_container.pack(fill="x", pady=(0, 10))
        name_entry.focus_set()

        tk.Label(
            form, text="Secret Key", font=("Segoe UI", 9, "bold"),
            bg=self.c["bg"], fg=self.c["fg"]
        ).pack(anchor="w", pady=(0, 2))
        secret_container, secret_entry = self._create_modern_entry(form, width=36, show="*")
        secret_container.pack(fill="x", pady=(0, 10))

        tk.Label(
            form, text="Or paste otpauth:// URI", font=("Segoe UI", 8),
            bg=self.c["bg"], fg=self.c["fg_dim"]
        ).pack(anchor="w", pady=(0, 2))
        uri_container, uri_entry = self._create_modern_entry(form, width=36)
        uri_container.pack(fill="x", pady=(0, 16))

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

        # Action buttons
        btn_box = tk.Frame(dialog, bg=self.c["bg"])
        btn_box.pack(fill="x", padx=24, pady=(6, 20))

        btn_cancel = self._create_pill_button(
            btn_box, text="Cancel", command=dialog.destroy, padx=16, pady=5
        )
        btn_cancel.pack(side="right", padx=(8, 0))

        btn_save = self._create_pill_button(
            btn_box, text="Save Account", command=_save, is_primary=True, padx=20, pady=5
        )
        btn_save.pack(side="right")

        dialog.bind("<Return>", lambda e: _save())

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

    # ── Copy & Update Loop ─────────────────────────────────────────────────────

    def _copy_code(self) -> None:
        """Copy current OTP code with responsive visual feedback."""
        account = self._selected_account()
        if not account:
            return
        code = get_code(account.secret)
        if not code:
            return
        pyperclip.copy(code)

        # Micro-interaction feedback
        self.copy_btn.configure(
            text="✓  Copied to Clipboard!",
            bg=self.c["green"],
        )
        if self._copy_timer:
            self.root.after_cancel(self._copy_timer)
        self._copy_timer = self.root.after(1500, self._reset_copy_btn)

    def _reset_copy_btn(self) -> None:
        """Restore default copy button appearance."""
        self.copy_btn.configure(
            text="📋  Copy Code",
            bg=self.c["blue"],
        )
        self._copy_timer = None

    def _update_loop(self) -> None:
        """Periodic 1-second refresh for TOTP code, progress bar, and auto-lock."""
        account = self._selected_account()
        if account:
            raw_code = get_code(account.secret)
            remaining = get_remaining_seconds()

            if remaining > 10:
                color = self.c["green"]
            elif remaining > 5:
                color = self.c["amber"]
            else:
                color = self.c["red"]

            # Split code: "123  456"
            if raw_code and len(raw_code) == 6:
                formatted_code = f"{raw_code[:3]}  {raw_code[3:]}"
            else:
                formatted_code = raw_code or "------"

            self.code_var.set(formatted_code)
            self.code_label.config(fg=color)
            self.timer_var.set(f"Refreshes in {remaining}s")

            # Update progress bar
            self._update_progress_bar(remaining, color)
        else:
            self.code_var.set("------")
            self.timer_var.set("")
            self._update_progress_bar(0, self.c["border"])

        # Check auto-lock timeout
        if (
            is_config_encrypted()
            and self._settings.lock_timeout_minutes > 0
            and time.time() - self._last_activity > self._settings.lock_timeout_minutes * 60
        ):
            self._lock_app()
            return

        self._update_job = self.root.after(1000, self._update_loop)

    # ── Lock Screen & Security ─────────────────────────────────────────────────

    def _build_lock_screen(self) -> None:
        """Build the master password lock screen."""
        self.lock_frame = tk.Frame(self.root, bg=self.c["bg"])
        self.lock_frame.pack(fill="both", expand=True)

        # Centered shield icon
        icon_cv = tk.Canvas(
            self.lock_frame,
            width=52,
            height=52,
            bg=self.c["bg"],
            highlightthickness=0,
        )
        icon_cv.pack(pady=(45, 10))
        icon_cv.create_oval(2, 2, 50, 50, fill=self.c["surface"], outline="")
        icon_cv.create_text(26, 26, text="🔒", font=("Segoe UI", 18))

        tk.Label(
            self.lock_frame,
            text="App Locked",
            font=("Segoe UI", 16, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(pady=(0, 4))

        tk.Label(
            self.lock_frame,
            text="Enter Master Password to decrypt your accounts",
            font=("Segoe UI", 9),
            bg=self.c["bg"],
            fg=self.c["fg_dim"],
        ).pack(pady=(0, 14))

        # Modern Password Entry
        form_frame = tk.Frame(self.lock_frame, bg=self.c["bg"])
        form_frame.pack()

        pwd_container, self.pwd_entry = self._create_modern_entry(
            form_frame, width=22, show="*", justify="center"
        )
        pwd_container.pack(pady=4)
        self.pwd_entry.focus_set()

        self.lbl_pwd_error = tk.Label(
            self.lock_frame,
            text="",
            font=("Segoe UI", 9),
            bg=self.c["bg"],
            fg=self.c["red"],
        )
        self.lbl_pwd_error.pack(pady=(2, 0))

        btn_unlock = self._create_pill_button(
            self.lock_frame,
            text="Unlock",
            command=self._try_unlock,
            is_primary=True,
            font=("Segoe UI", 10, "bold"),
            padx=28,
            pady=6,
        )
        btn_unlock.pack(pady=(12, 10))

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
        dialog.geometry("420x300")
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
            insertbackground=self.c["fg"],
            width=14,
            justify="center",
            highlightthickness=1,
            highlightbackground=self.c["border"],
            highlightcolor=self.c["border_focus"],
        )
        confirm_entry.pack(pady=4, ipady=4)
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

        btn_cancel = self._create_pill_button(
            btn_box, text="Cancel", command=dialog.destroy, padx=14, pady=5
        )
        btn_cancel.pack(side="left", padx=8)

        btn_confirm = self._create_pill_button(
            btn_box, text="Reset Vault", command=_do_reset, is_danger=True, padx=14, pady=5
        )
        btn_confirm.pack(side="left", padx=8)

        confirm_entry.bind("<Return>", lambda e: _do_reset())

    def _open_security_dialog(self) -> None:
        """Open the modernized Security Settings dialog."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Security Settings")
        dialog.geometry("420x460")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        header = tk.Frame(dialog, bg=self.c["bg"])
        header.pack(fill="x", padx=24, pady=(20, 12))

        tk.Label(
            header,
            text="⚙️ Security & Vault Settings",
            font=("Segoe UI", 12, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(anchor="w")

        # Status badge card
        is_enc = is_config_encrypted()
        status_bg = self.c["bg_card"]
        status_card = tk.Frame(
            dialog,
            bg=status_bg,
            padx=16,
            pady=12,
            highlightbackground=self.c["border"],
            highlightthickness=1,
        )
        status_card.pack(fill="x", padx=24, pady=(0, 14))

        status_icon = "🔒" if is_enc else "🔓"
        status_title = (
            "Vault Protected with Master Password"
            if is_enc
            else "No Master Password (Unencrypted)"
        )
        status_color = self.c["green"] if is_enc else self.c["amber"]

        tk.Label(
            status_card,
            text=f"{status_icon}  {status_title}",
            font=("Segoe UI", 9, "bold"),
            bg=status_bg,
            fg=status_color,
        ).pack(anchor="w")

        form = tk.Frame(dialog, bg=self.c["bg"])
        form.pack(fill="x", padx=24)

        # Timeout setting
        tk.Label(
            form,
            text="Auto-Lock Timeout (minutes)",
            font=("Segoe UI", 9, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(anchor="w", pady=(0, 2))
        timeout_var = tk.StringVar(value=str(self._settings.lock_timeout_minutes))
        timeout_cnt, timeout_entry = self._create_modern_entry(
            form, width=8, justify="center"
        )
        timeout_entry.config(textvariable=timeout_var)
        timeout_cnt.pack(anchor="w", pady=(0, 10))

        # Password setting
        pwd_label_text = "Change Master Password" if is_enc else "Set Master Password"
        tk.Label(
            form,
            text=pwd_label_text,
            font=("Segoe UI", 9, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(anchor="w", pady=(0, 2))
        pwd_cnt, pwd_entry = self._create_modern_entry(form, width=34, show="*")
        pwd_cnt.pack(fill="x", pady=(0, 12))

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

        btn_box = tk.Frame(dialog, bg=self.c["bg"])
        btn_box.pack(fill="x", padx=24, pady=(0, 14))

        btn_save = self._create_pill_button(
            btn_box, text="Save Settings", command=_save, is_primary=True, padx=18, pady=5
        )
        btn_save.pack(side="left", padx=(0, 8))

        if is_enc:
            btn_remove = self._create_pill_button(
                btn_box, text="Remove Password", command=_remove, is_danger=True, padx=14, pady=5
            )
            btn_remove.pack(side="left")

        # Divider
        tk.Frame(dialog, height=1, bg=self.c["border"]).pack(fill="x", padx=24, pady=8)

        # Backup & restore card
        tk.Label(
            dialog,
            text="Data Backup & Recovery",
            font=("Segoe UI", 9, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(anchor="w", padx=24, pady=(4, 6))

        def _export_backup() -> None:
            path = filedialog.asksaveasfilename(
                title="Export Encrypted Backup",
                defaultextension=".totp_backup",
                filetypes=[("TOTP Backup Files", "*.totp_backup")],
                parent=dialog,
            )
            if not path:
                return
            pwd = simpledialog.askstring(
                "Backup Password",
                "Create a password to encrypt this backup:",
                show="*",
                parent=dialog,
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
                parent=dialog,
            )
            if not path:
                return
            pwd = simpledialog.askstring(
                "Backup Password",
                "Enter the password for this backup:",
                show="*",
                parent=dialog,
            )
            if not pwd:
                return
            try:
                added = restore_backup(pwd, path, self._current_key)
                self._accounts = load_accounts(self._current_key)
                self._refresh_sidebar()
                messagebox.showinfo(
                    "Success", f"Restored {added} new account(s).", parent=dialog
                )
            except InvalidPasswordError:
                messagebox.showerror(
                    "Import Failed", "Incorrect password or corrupted backup.", parent=dialog
                )
            except Exception as e:
                messagebox.showerror("Import Failed", str(e), parent=dialog)

        backup_box = tk.Frame(dialog, bg=self.c["bg"])
        backup_box.pack(fill="x", padx=24)

        btn_export = self._create_pill_button(
            backup_box, text="📦 Export Backup", command=_export_backup, padx=14, pady=5
        )
        btn_export.pack(side="left", padx=(0, 8))

        btn_import = self._create_pill_button(
            backup_box, text="📥 Import Backup", command=_import_backup, padx=14, pady=5
        )
        btn_import.pack(side="left")

    def _open_sync_dialog(self) -> None:
        """Open the modernized Cloud Sync dialog."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Cloud Sync")
        dialog.geometry("420x440")
        dialog.configure(bg=self.c["bg"])
        dialog.resizable(False, False)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        header = tk.Frame(dialog, bg=self.c["bg"])
        header.pack(fill="x", padx=24, pady=(20, 14))

        tk.Label(
            header,
            text="☁️ Cloud Synchronization",
            font=("Segoe UI", 12, "bold"),
            bg=self.c["bg"],
            fg=self.c["fg"],
        ).pack(anchor="w")
        tk.Label(
            header,
            text="End-to-End Encrypted backup and sync across devices",
            font=("Segoe UI", 9),
            bg=self.c["bg"],
            fg=self.c["fg_dim"],
        ).pack(anchor="w", pady=(2, 0))

        body = tk.Frame(dialog, bg=self.c["bg"])
        body.pack(fill="both", expand=True, padx=24)

        def _refresh_ui() -> None:
            for w in body.winfo_children():
                w.destroy()

            if self._settings.sync_token:
                # Connected status card
                status_card = tk.Frame(
                    body,
                    bg=self.c["bg_card"],
                    padx=16,
                    pady=16,
                    highlightbackground=self.c["border"],
                    highlightthickness=1,
                )
                status_card.pack(fill="x", pady=10)

                tk.Label(
                    status_card,
                    text="● Connected to Sync Server",
                    font=("Segoe UI", 10, "bold"),
                    bg=self.c["bg_card"],
                    fg=self.c["green"],
                ).pack(anchor="w")

                tk.Label(
                    status_card,
                    text=f"Server: {self._settings.sync_server_url}",
                    font=("Segoe UI", 8),
                    bg=self.c["bg_card"],
                    fg=self.c["fg_dim"],
                ).pack(anchor="w", pady=(4, 0))

                def _do_sync(action: str) -> None:
                    pwd = simpledialog.askstring(
                        "Vault Password",
                        "Enter Master/Sync password to encrypt/decrypt cloud vault:",
                        show="*",
                        parent=dialog,
                    )
                    if not pwd:
                        return

                    manager = SyncManager(self._settings, pwd)
                    try:
                        if action == "push":
                            manager.push(self._current_key)
                            messagebox.showinfo(
                                "Success", "Vault uploaded successfully!", parent=dialog
                            )
                        elif action == "pull":
                            count = manager.pull(self._current_key)
                            self._accounts = load_accounts(self._current_key)
                            self._refresh_sidebar()
                            messagebox.showinfo(
                                "Success",
                                f"Vault synchronized! Added {count} new accounts.",
                                parent=dialog,
                            )
                    except ConflictError:
                        msg = (
                            "Cloud vault was modified by another device.\n"
                            "Do you want to force overwrite cloud data?"
                        )
                        if messagebox.askyesno("Conflict Detected", msg, parent=dialog):
                            try:
                                manager.resolve_conflict_overwrite(self._current_key)
                                messagebox.showinfo(
                                    "Success", "Vault overwritten successfully!", parent=dialog
                                )
                            except Exception as e:
                                messagebox.showerror("Error", str(e), parent=dialog)
                    except Exception as e:
                        messagebox.showerror("Sync Failed", str(e), parent=dialog)

                actions_frame = tk.Frame(body, bg=self.c["bg"])
                actions_frame.pack(fill="x", pady=16)

                btn_push = self._create_pill_button(
                    actions_frame,
                    text="⬆️  Push to Cloud",
                    command=lambda: _do_sync("push"),
                    is_primary=True,
                    padx=14,
                    pady=6,
                )
                btn_push.pack(side="left", padx=(0, 8))

                btn_pull = self._create_pill_button(
                    actions_frame,
                    text="⬇️  Pull from Cloud",
                    command=lambda: _do_sync("pull"),
                    padx=14,
                    pady=6,
                )
                btn_pull.pack(side="left")

                def _logout() -> None:
                    self._settings.sync_token = ""
                    save_settings(self._settings)
                    _refresh_ui()

                btn_logout = self._create_pill_button(
                    body,
                    text="Logout from Cloud",
                    command=_logout,
                    is_danger=True,
                    padx=14,
                    pady=5,
                )
                btn_logout.pack(pady=20)
            else:
                # Login / Register Form
                tk.Label(
                    body,
                    text="Server URL",
                    font=("Segoe UI", 9, "bold"),
                    bg=self.c["bg"],
                    fg=self.c["fg"],
                ).pack(anchor="w", pady=(0, 2))
                url_cnt, url_entry = self._create_modern_entry(body, width=34)
                url_entry.insert(0, self._settings.sync_server_url)
                url_cnt.pack(fill="x", pady=(0, 10))

                tk.Label(
                    body,
                    text="Username",
                    font=("Segoe UI", 9, "bold"),
                    bg=self.c["bg"],
                    fg=self.c["fg"],
                ).pack(anchor="w", pady=(0, 2))
                user_cnt, user_entry = self._create_modern_entry(body, width=34)
                user_cnt.pack(fill="x", pady=(0, 10))

                tk.Label(
                    body,
                    text="Password",
                    font=("Segoe UI", 9, "bold"),
                    bg=self.c["bg"],
                    fg=self.c["fg"],
                ).pack(anchor="w", pady=(0, 2))
                pwd_cnt, pwd_entry = self._create_modern_entry(body, width=34, show="*")
                pwd_cnt.pack(fill="x", pady=(0, 16))

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

                btn_box = tk.Frame(body, bg=self.c["bg"])
                btn_box.pack(fill="x", pady=6)

                btn_login = self._create_pill_button(
                    btn_box,
                    text="Login",
                    command=lambda: _auth(False),
                    is_primary=True,
                    padx=22,
                    pady=6,
                )
                btn_login.pack(side="left", padx=(0, 8))

                btn_reg = self._create_pill_button(
                    btn_box,
                    text="Register New Account",
                    command=lambda: _auth(True),
                    padx=14,
                    pady=6,
                )
                btn_reg.pack(side="left")

        _refresh_ui()
