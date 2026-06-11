"""Tests for git code workspace manager."""

import json
import os
import uuid
from unittest.mock import AsyncMock, patch

import pytest

from services.workspace.manager import (
    WorkspaceManager,
    _normalize_git_url,
    _repo_name_from_url,
)


def test_normalize_github_shorthand():
    assert _normalize_git_url("owner/repo") == "https://github.com/owner/repo"
    assert _normalize_git_url("https://github.com/owner/repo.git") == "https://github.com/owner/repo"


def test_repo_name_from_url():
    assert _repo_name_from_url("https://github.com/foo/bar.git") == "bar"
    assert _repo_name_from_url("git@github.com:foo/bar.git") == "bar"


def test_list_and_get_empty(tmp_path, monkeypatch):
    state = tmp_path / "workspaces.json"
    root = tmp_path / "workspaces"
    monkeypatch.setattr("services.workspace.manager.WORKSPACES_STATE_FILE", str(state))
    monkeypatch.setattr("services.workspace.manager.WORKSPACES_DIR", str(root))

    mgr = WorkspaceManager()
    assert mgr.list() == []
    assert mgr.get("nope") is None


def test_remove_requires_confirm(tmp_path, monkeypatch):
    state = tmp_path / "workspaces.json"
    root = tmp_path / "workspaces"
    monkeypatch.setattr("services.workspace.manager.WORKSPACES_STATE_FILE", str(state))
    monkeypatch.setattr("services.workspace.manager.WORKSPACES_DIR", str(root))

    ws_id = "abc12345"
    repo = root / ws_id / "repo"
    repo.mkdir(parents=True)
    state.write_text(
        json.dumps({"workspaces": [{"id": ws_id, "url": "https://github.com/a/b", "name": "b", "repo_path": str(repo)}]}),
        encoding="utf-8",
    )

    mgr = WorkspaceManager()
    with pytest.raises(ValueError, match="confirm"):
        mgr.remove(ws_id)

    result = mgr.remove(ws_id, confirm=True)
    assert result["id"] == ws_id
    assert not (root / ws_id).exists()
    assert mgr.list() == []


@pytest.mark.asyncio
async def test_attach_clones_and_persists(tmp_path, monkeypatch):
    state = tmp_path / "workspaces.json"
    root = tmp_path / "workspaces"
    monkeypatch.setattr("services.workspace.manager.WORKSPACES_STATE_FILE", str(state))
    monkeypatch.setattr("services.workspace.manager.WORKSPACES_DIR", str(root))

    dest = root / "deadbeef" / "repo"
    dest.mkdir(parents=True)
    (dest / "README.md").write_text("hello", encoding="utf-8")

    async def fake_run_git(args, *, cwd=None, timeout=600):
        if args[:2] == ["git", "clone"]:
            return 0, "", ""
        if args[-2:] == ["HEAD"]:
            return 0, "main\n", ""
        return 0, "", ""

    with patch("services.workspace.manager._run_git", new=AsyncMock(side_effect=fake_run_git)):
        with patch(
            "services.workspace.manager.uuid.uuid4",
            return_value=uuid.UUID("deadbeef-0000-0000-0000-000000000000"),
        ):
            mgr = WorkspaceManager()
            ws = await mgr.attach("https://github.com/example/demo")

    assert ws["id"] == "deadbeef"
    assert ws["url"] == "https://github.com/example/demo"
    assert ws["name"] == "demo"
    assert ws["branch"] == "main"
    assert len(mgr.list()) == 1

    # Re-attach same URL reuses entry (sync path)
    with patch.object(WorkspaceManager, "sync", new=AsyncMock(return_value=ws)):
        ws2 = await mgr.attach("https://github.com/example/demo")
    assert ws2["id"] == "deadbeef"
