"""Code workspace management — clone git repos for agent sessions."""

from services.workspace.manager import WorkspaceManager, get_workspace_manager

__all__ = ["WorkspaceManager", "get_workspace_manager"]
