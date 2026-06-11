"""Git-backed code workspaces for the agent.

Clones repos under data/workspaces/<id>/repo, tracks metadata in
data/workspaces.json, and binds an active workspace to a chat session so
file/shell tools are confined to that folder.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import shutil
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

from core.atomic_io import atomic_write_json
from src.constants import DATA_DIR, WORKSPACES_DIR, WORKSPACES_STATE_FILE

logger = logging.getLogger(__name__)

_GIT_URL_RE = re.compile(
    r"^(?:https?://|git@|ssh://)[^\s]+|"
    r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$",
    re.IGNORECASE,
)


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _normalize_git_url(url: str) -> str:
    """Normalize common git URL shapes for clone + dedup."""
    raw = (url or "").strip()
    if not raw:
        raise ValueError("url is required")
    # owner/repo shorthand
    if re.match(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?$", raw):
        raw = f"https://github.com/{raw}"
    # github.com/owner/repo (no scheme)
    elif re.match(r"^(?:www\.)?[A-Za-z0-9.-]+\.[A-Za-z]{2,}/", raw, re.I):
        raw = f"https://{raw.lstrip('/')}"
    if raw.startswith("git@"):
        return raw
    parsed = urlparse(raw)
    if not parsed.scheme or not parsed.netloc:
        raise ValueError(f"invalid git url: {url}")
    path = (parsed.path or "").rstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    return f"{parsed.scheme}://{parsed.netloc}{path}"


def _repo_name_from_url(url: str) -> str:
    norm = _normalize_git_url(url)
    if norm.startswith("git@"):
        # git@github.com:owner/repo
        tail = norm.split(":", 1)[-1]
        return tail.rstrip("/").split("/")[-1].replace(".git", "") or "repo"
    path = urlparse(norm).path.rstrip("/")
    return (path.split("/")[-1] if path else "repo").replace(".git", "") or "repo"


def _workspace_root() -> str:
    os.makedirs(WORKSPACES_DIR, exist_ok=True)
    return os.path.realpath(WORKSPACES_DIR)


def _repo_dir(workspace_id: str) -> str:
    return os.path.join(_workspace_root(), workspace_id, "repo")


def _load_state() -> Dict[str, Any]:
    if not os.path.isfile(WORKSPACES_STATE_FILE):
        return {"workspaces": []}
    try:
        with open(WORKSPACES_STATE_FILE, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            return {"workspaces": []}
        workspaces = data.get("workspaces")
        if not isinstance(workspaces, list):
            data["workspaces"] = []
        return data
    except (OSError, json.JSONDecodeError) as e:
        logger.warning("workspaces state unreadable: %s", e)
        return {"workspaces": []}


def _save_state(data: Dict[str, Any]) -> None:
    atomic_write_json(WORKSPACES_STATE_FILE, data, indent=2)


async def _run_git(args: List[str], *, cwd: Optional[str] = None, timeout: float = 600) -> tuple[int, str, str]:
    proc = await asyncio.create_subprocess_exec(
        *args,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout_b, stderr_b = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        try:
            proc.kill()
        except ProcessLookupError:
            pass
        raise TimeoutError(f"git timed out after {timeout}s: {' '.join(args)}")
    stdout = (stdout_b or b"").decode("utf-8", errors="replace")
    stderr = (stderr_b or b"").decode("utf-8", errors="replace")
    return proc.returncode or 0, stdout, stderr


class WorkspaceManager:
    """Persisted git workspace registry."""

    def list(self) -> List[Dict[str, Any]]:
        return list(_load_state().get("workspaces") or [])

    def get(self, workspace_id: str) -> Optional[Dict[str, Any]]:
        wid = (workspace_id or "").strip()
        for ws in self.list():
            if ws.get("id") == wid:
                return dict(ws)
        return None

    def _find_by_url(self, url: str) -> Optional[Dict[str, Any]]:
        norm = _normalize_git_url(url)
        for ws in self.list():
            if ws.get("url") == norm:
                return dict(ws)
        return None

    def repo_path(self, workspace_id: str) -> Optional[str]:
        ws = self.get(workspace_id)
        if not ws:
            return None
        path = ws.get("repo_path") or _repo_dir(workspace_id)
        if os.path.isdir(path):
            return os.path.realpath(path)
        return None

    def resolve_for_session(self, session_id: str) -> Optional[str]:
        """Return the repo path bound to a chat session, if any."""
        if not session_id:
            return None
        try:
            from core.database import SessionLocal, Session
            db = SessionLocal()
            try:
                row = db.query(Session.workspace_id).filter(Session.id == session_id).first()
                wid = row[0] if row else None
            finally:
                db.close()
        except Exception as e:
            logger.debug("workspace session lookup failed: %s", e)
            return None
        if not wid:
            return None
        return self.repo_path(wid)

    def bind_session(self, workspace_id: str, session_id: str) -> bool:
        wid = (workspace_id or "").strip()
        sid = (session_id or "").strip()
        if not wid or not sid:
            raise ValueError("workspace_id and session_id are required")
        if not self.get(wid):
            raise ValueError(f"workspace {wid} not found")
        from core.database import SessionLocal, Session
        db = SessionLocal()
        try:
            updated = db.query(Session).filter(Session.id == sid).update({"workspace_id": wid})
            db.commit()
            return bool(updated)
        finally:
            db.close()

    def unbind_session(self, session_id: str) -> bool:
        sid = (session_id or "").strip()
        if not sid:
            raise ValueError("session_id is required")
        from core.database import SessionLocal, Session
        db = SessionLocal()
        try:
            updated = db.query(Session).filter(Session.id == sid).update({"workspace_id": None})
            db.commit()
            return bool(updated)
        finally:
            db.close()

    async def attach(
        self,
        url: str,
        *,
        branch: Optional[str] = None,
        session_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Clone (or reuse) a repo and optionally bind it to a session."""
        try:
            norm = _normalize_git_url(url)
        except ValueError as e:
            raise ValueError(f"unsupported git url: {url}") from e
        if not _GIT_URL_RE.match(norm):
            raise ValueError(f"unsupported git url: {url}")
        existing = self._find_by_url(norm)
        if existing:
            ws = await self.sync(existing["id"])
            if session_id:
                self.bind_session(ws["id"], session_id)
            return ws

        ws_id = str(uuid.uuid4())[:8]
        dest = _repo_dir(ws_id)
        os.makedirs(os.path.dirname(dest), exist_ok=True)

        clone_args = ["git", "clone", "--depth", "1"]
        if branch:
            clone_args.extend(["--branch", branch.strip()])
        clone_args.extend([norm, dest])

        code, out, err = await _run_git(clone_args)
        if code != 0:
            shutil.rmtree(os.path.dirname(dest), ignore_errors=True)
            raise RuntimeError(err.strip() or out.strip() or f"git clone failed ({code})")

        detected_branch = (branch or "").strip()
        if not detected_branch:
            bcode, bout, _ = await _run_git(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=dest,
            )
            if bcode == 0:
                detected_branch = bout.strip()

        now = _utcnow_iso()
        entry = {
            "id": ws_id,
            "url": norm,
            "name": _repo_name_from_url(norm),
            "branch": detected_branch or "main",
            "repo_path": os.path.realpath(dest),
            "created_at": now,
            "updated_at": now,
            "last_synced_at": now,
            "status": "ready",
        }
        state = _load_state()
        state.setdefault("workspaces", []).append(entry)
        _save_state(state)

        if session_id:
            self.bind_session(ws_id, session_id)

        logger.info("attached workspace %s → %s", ws_id, norm)
        return dict(entry)

    async def sync(self, workspace_id: str) -> Dict[str, Any]:
        wid = (workspace_id or "").strip()
        ws = self.get(wid)
        if not ws:
            raise ValueError(f"workspace {wid} not found")
        repo = ws.get("repo_path") or _repo_dir(wid)
        if not os.path.isdir(os.path.join(repo, ".git")):
            raise RuntimeError(f"workspace {wid} is missing a git checkout")

        code, out, err = await _run_git(
            ["git", "-C", repo, "pull", "--ff-only"],
        )
        if code != 0:
            ws["status"] = "error"
            ws["error"] = (err or out or f"git pull failed ({code})").strip()[:500]
        else:
            ws["status"] = "ready"
            ws["error"] = None
            bcode, bout, _ = await _run_git(
                ["git", "-C", repo, "rev-parse", "--abbrev-ref", "HEAD"],
            )
            if bcode == 0 and bout.strip():
                ws["branch"] = bout.strip()
        now = _utcnow_iso()
        ws["updated_at"] = now
        ws["last_synced_at"] = now

        state = _load_state()
        workspaces = []
        for item in state.get("workspaces") or []:
            workspaces.append(ws if item.get("id") == wid else item)
        state["workspaces"] = workspaces
        _save_state(state)
        return dict(ws)

    def remove(self, workspace_id: str, *, confirm: bool = False) -> Dict[str, Any]:
        if not confirm:
            raise ValueError("pass confirm=true to delete a workspace")
        wid = (workspace_id or "").strip()
        ws = self.get(wid)
        if not ws:
            raise ValueError(f"workspace {wid} not found")

        root = os.path.realpath(os.path.join(_workspace_root(), wid))
        base = _workspace_root()
        if os.path.commonpath([root, base]) != base:
            raise ValueError("unsafe workspace path")

        shutil.rmtree(root, ignore_errors=True)

        state = _load_state()
        state["workspaces"] = [
            w for w in (state.get("workspaces") or []) if w.get("id") != wid
        ]
        _save_state(state)

        # Clear session bindings pointing at this workspace.
        try:
            from core.database import SessionLocal, Session
            db = SessionLocal()
            try:
                db.query(Session).filter(Session.workspace_id == wid).update({"workspace_id": None})
                db.commit()
            finally:
                db.close()
        except Exception as e:
            logger.warning("failed to clear session bindings for %s: %s", wid, e)

        return {"response": f"Removed workspace '{ws.get('name')}' ({wid})", "id": wid}


_manager: Optional[WorkspaceManager] = None


def get_workspace_manager() -> WorkspaceManager:
    global _manager
    if _manager is None:
        _manager = WorkspaceManager()
    return _manager
