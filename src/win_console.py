"""Windows console helpers — enable ANSI colors for uvicorn/logging."""

from __future__ import annotations

import os
import sys


def enable_ansi_colors() -> bool:
    """Turn on ENABLE_VIRTUAL_TERMINAL_PROCESSING for stdout/stderr on Windows.

    Without this, uvicorn and other tools emit raw escape sequences like
    ``\\x1b[32m`` which show up as ``←[32m`` in older consoles. Returns True
    when the mode was enabled (or already active).
    """
    if os.name != "nt":
        return False

    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
    except Exception:
        return False

    enable_vt = 0x0004
    # STD_OUTPUT_HANDLE = -11, STD_ERROR_HANDLE = -12
    ok = False
    for handle_id in (-11, -12):
        handle = kernel32.GetStdHandle(handle_id)
        if handle in (0, -1):
            continue
        mode = ctypes.c_uint32()
        if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            continue
        if mode.value & enable_vt:
            ok = True
            continue
        if kernel32.SetConsoleMode(handle, mode.value | enable_vt):
            ok = True
    return ok


def should_disable_access_log() -> bool:
    """Default to quieter HTTP logs on native Windows unless opted in."""
    if os.name != "nt":
        return False
    raw = os.getenv("ODYSSEUS_ACCESS_LOG", "").strip().lower()
    if raw in ("1", "true", "yes", "on"):
        return False
    if raw in ("0", "false", "no", "off"):
        return True
    # Default: hide per-request access lines (UI polls every few seconds).
    return True
