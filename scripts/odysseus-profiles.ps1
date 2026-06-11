# Shared prod/dev instance settings for git worktree launchers.
# Paths are resolved from the main repo root (E:\Odysseus).

$script:OdysseusMainRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script:OdysseusDevRoot = Join-Path (Split-Path $OdysseusMainRoot -Parent) "Odysseus-develop"

$script:OdysseusProfiles = @{
    Prod = [ordered]@{
        Label       = "Production"
        RepoRoot    = $OdysseusMainRoot
        Branch      = "main"
        Port        = 7000
        DataDir     = Join-Path (Split-Path $OdysseusMainRoot -Parent) "OdysseusData"
        ChromaPort  = 8100
        Shortcut    = "Napzter AI"
        Description = "Start Napzter production (main branch, port 7000)"
    }
    Dev = [ordered]@{
        Label       = "Development"
        RepoRoot    = $OdysseusDevRoot
        Branch      = "develop"
        Port        = 7001
        DataDir     = Join-Path (Split-Path $OdysseusMainRoot -Parent) "OdysseusData-dev"
        ChromaPort  = 8101
        Shortcut    = "Napzter Dev"
        Description = "Start Napzter staging (develop branch, port 7001)"
    }
}

function Get-OdysseusProfile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Prod", "Dev")]
        [string]$Name
    )
    return $script:OdysseusProfiles[$Name]
}
