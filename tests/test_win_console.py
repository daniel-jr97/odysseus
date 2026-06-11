"""Windows console helper tests."""

import os

from src.win_console import enable_ansi_colors, should_disable_access_log


def test_enable_ansi_noop_off_windows(monkeypatch):
    monkeypatch.setattr(os, "name", "posix")
    assert enable_ansi_colors() is False


def test_should_disable_access_log_default_windows(monkeypatch):
    monkeypatch.setattr(os, "name", "nt")
    monkeypatch.delenv("ODYSSEUS_ACCESS_LOG", raising=False)
    assert should_disable_access_log() is True


def test_should_disable_access_log_opt_in(monkeypatch):
    monkeypatch.setattr(os, "name", "nt")
    monkeypatch.setenv("ODYSSEUS_ACCESS_LOG", "1")
    assert should_disable_access_log() is False
