---
name: desktop-nuitka-packaging
description: Standards and build workflows for compiling the Python Tkinter desktop application into an optimized Windows standalone executable (.exe) using Nuitka.
---

# Desktop Packaging with Nuitka Skill

This skill defines the packaging, compilation, and optimization standards for building the standalone Windows desktop binary for **`apps/ui`**.

---

## 1. Prerequisites for Compilation

Nuitka compiles Python code into C before building native machine code. It requires:
1. **Python 3.10+** (64-bit recommended).
2. **C Compiler**: Microsoft Visual C++ (MSVC Build Tools) or MinGW64.
3. **Nuitka**: `pip install nuitka zstandard` (inside `.venv`).

---

## 2. Standard Build Command

Run from `apps/ui/`:

```powershell
python -m nuitka `
    --standalone `
    --enable-plugin=tk-inter `
    --windows-console-mode=disable `
    --windows-icon-from-ico=../../assets/icon.ico `
    --include-data-dir=../../assets=assets `
    --output-dir=dist `
    --output-filename=totp-auth.exe `
    src/totp_authenticator/main.py
```

### Explanation of Critical Flags:
* `--standalone`: Bundles all dependencies (Python runtime, DLLs, standard library) into a redistributable folder without requiring Python installed on the target machine.
* `--enable-plugin=tk-inter`: Ensures Tk/Tcl binaries, DLLs, and library scripts (`init.tcl`) are properly discovered and packaged.
* `--windows-console-mode=disable`: Hides the black terminal console window when launching the desktop app.
* `--windows-icon-from-ico`: Sets the `.exe` file icon and taskbar icon on Windows.
* `--include-data-dir`: Embeds images, gifs, and static assets into the build directory.

---

## 3. High-DPI & Windows Desktop Polish

To ensure the Tkinter UI renders crisp text and widgets on modern 2K/4K Windows displays, include this snippet in `main.py` before initializing `Tk()`:

```python
import sys
import ctypes

def enable_windows_dpi_awareness():
    if sys.platform == "win32":
        try:
            # Per-monitor DPI aware (PerMonitorV2 = 2, PerMonitor = 1)
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
        except Exception:
            try:
                ctypes.windll.user32.SetProcessDPIAware()
            except Exception:
                pass
```

---

## 4. System Tray (`pystray`) & Event Loop Coexistence

* When minimizing to system tray, use `root.withdraw()` to hide the window instead of `root.destroy()`.
* Run `pystray.Icon.run_detached()` or run the icon in a background daemon thread so it doesn't block the Tkinter `root.mainloop()`.
* Restore window using:
  ```python
  root.deiconify()
  root.lift()
  root.focus_force()
  ```

---

## 5. Build Troubleshooting Checklist

- [ ] **Missing Tcl/Tk DLLs**: Ensure `--enable-plugin=tk-inter` is active.
- [ ] **Cryptography CFFI error**: Make sure `cffi` and `cryptography` are installed in the same virtualenv where Nuitka runs.
- [ ] **Antivirus false positives**: Code-signing with a certificate or testing in Windows Defender exclusion directory during local development is recommended.
- [ ] **Single-file `.exe` alternative**: If single-file distribution is preferred over a folder, replace `--standalone` with `--onefile`. Note that `--onefile` extracts to `%TEMP%` on startup.
