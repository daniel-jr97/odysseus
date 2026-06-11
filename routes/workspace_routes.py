"""REST routes for git-backed code workspaces (admin-only)."""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from core.middleware import require_admin
from services.workspace import get_workspace_manager

logger = logging.getLogger(__name__)


class AttachWorkspaceRequest(BaseModel):
    url: str
    branch: Optional[str] = None
    session_id: Optional[str] = None


class BindWorkspaceRequest(BaseModel):
    session_id: str


def setup_workspace_routes() -> APIRouter:
    router = APIRouter(prefix="/api/workspaces", tags=["workspaces"])
    mgr = get_workspace_manager()

    @router.get("")
    async def list_workspaces(request: Request):
        require_admin(request)
        return {"workspaces": mgr.list()}

    @router.get("/{workspace_id}")
    async def get_workspace(workspace_id: str, request: Request):
        require_admin(request)
        ws = mgr.get(workspace_id)
        if not ws:
            raise HTTPException(404, "Workspace not found")
        return ws

    @router.post("/attach")
    async def attach_workspace(body: AttachWorkspaceRequest, request: Request):
        require_admin(request)
        try:
            ws = await mgr.attach(
                body.url,
                branch=body.branch,
                session_id=body.session_id,
            )
            return ws
        except ValueError as e:
            raise HTTPException(400, str(e)) from e
        except RuntimeError as e:
            raise HTTPException(502, str(e)) from e

    @router.post("/{workspace_id}/sync")
    async def sync_workspace(workspace_id: str, request: Request):
        require_admin(request)
        try:
            return await mgr.sync(workspace_id)
        except ValueError as e:
            raise HTTPException(404, str(e)) from e
        except RuntimeError as e:
            raise HTTPException(502, str(e)) from e

    @router.post("/{workspace_id}/bind")
    async def bind_workspace(workspace_id: str, body: BindWorkspaceRequest, request: Request):
        require_admin(request)
        try:
            ok = mgr.bind_session(workspace_id, body.session_id)
            if not ok:
                raise HTTPException(404, "Session not found")
            return {"ok": True, "workspace_id": workspace_id, "session_id": body.session_id}
        except ValueError as e:
            raise HTTPException(400, str(e)) from e

    @router.delete("/{workspace_id}")
    async def delete_workspace(
        workspace_id: str,
        request: Request,
        confirm: bool = False,
    ):
        require_admin(request)
        try:
            return mgr.remove(workspace_id, confirm=confirm)
        except ValueError as e:
            raise HTTPException(400, str(e)) from e

    return router
