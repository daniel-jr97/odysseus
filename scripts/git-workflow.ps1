# Git workflow helpers for the Felix Odysseus fork.
# Usage: .\scripts\git-workflow.ps1 <command> [args]
#
# Commands:
#   experiment <name>   Create feature/<name> from develop (in develop worktree)
#   finish              Merge current feature branch into develop
#   promote             Merge develop into main (stable)
#   sync-upstream       Merge upstream/dev into develop
#   status              Show branch sync summary

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('experiment', 'finish', 'promote', 'sync-upstream', 'status')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$MainRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $MainRoot

. (Join-Path $MainRoot "scripts\odysseus-profiles.ps1")
$prod = Get-OdysseusProfile Prod
$dev = Get-OdysseusProfile Dev

function Require-CleanTree {
    param([string]$Path = (Get-Location).Path)
    Push-Location $Path
    try {
        $status = git status --porcelain
        if ($status) {
            throw "Working tree is not clean in ${Path}. Commit or stash changes first."
        }
    } finally {
        Pop-Location
    }
}

function Invoke-GitIn {
    param(
        [string]$Path,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$GitArgs
    )
    Push-Location $Path
    try {
        & git @GitArgs
        if ($LASTEXITCODE -ne 0) {
            throw "git $($GitArgs -join ' ') failed in $Path"
        }
    } finally {
        Pop-Location
    }
}

switch ($Command) {
    'experiment' {
        if (-not $Name) { throw "Usage: git-workflow.ps1 experiment <name>" }
        if (-not (Test-Path $dev.RepoRoot)) {
            throw "Develop worktree not found. Run .\scripts\setup-worktrees.ps1 first."
        }
        Require-CleanTree -Path $dev.RepoRoot
        Invoke-GitIn $dev.RepoRoot pull --ff-only origin develop
        Invoke-GitIn $dev.RepoRoot checkout -b "feature/$Name"
        Write-Host "Created feature/$Name in $($dev.RepoRoot)."
        Write-Host "Edit and test there, then run: .\scripts\git-workflow.ps1 finish"
    }
    'finish' {
        if (-not (Test-Path $dev.RepoRoot)) {
            throw "Develop worktree not found. Run .\scripts\setup-worktrees.ps1 first."
        }
        Push-Location $dev.RepoRoot
        try {
            $branch = git branch --show-current
            if ($branch -notlike 'feature/*') {
                throw "Switch to a feature/* branch in $($dev.RepoRoot) first (currently on '$branch')."
            }
            Require-CleanTree -Path $dev.RepoRoot
            Invoke-GitIn $dev.RepoRoot checkout develop
            Invoke-GitIn $dev.RepoRoot merge --no-ff $branch -m "Merge $branch into develop"
        } finally {
            Pop-Location
        }
        Write-Host "Merged $branch into develop. Test with Odysseus (Dev), then run: .\scripts\git-workflow.ps1 promote"
    }
    'promote' {
        Require-CleanTree -Path $prod.RepoRoot
        Require-CleanTree -Path $dev.RepoRoot
        Invoke-GitIn $prod.RepoRoot checkout main
        Invoke-GitIn $prod.RepoRoot merge --no-ff develop -m "Promote develop to main (stable)"
        Write-Host "Promoted develop -> main."
        Write-Host "Verify with Odysseus (Prod), then: git push origin main develop"
    }
    'sync-upstream' {
        if (-not (Test-Path $dev.RepoRoot)) {
            throw "Develop worktree not found. Run .\scripts\setup-worktrees.ps1 first."
        }
        Require-CleanTree -Path $dev.RepoRoot
        Invoke-GitIn $MainRoot fetch upstream
        Invoke-GitIn $dev.RepoRoot checkout develop
        Invoke-GitIn $dev.RepoRoot merge --no-ff upstream/dev -m "Integrate upstream/dev into develop"
        Write-Host "Merged upstream/dev into develop. Test with Odysseus (Dev), then promote if ready."
    }
    'status' {
        Invoke-GitIn $MainRoot fetch origin
        Invoke-GitIn $MainRoot fetch upstream
        Write-Host "=== Worktrees ==="
        git -C $MainRoot worktree list
        Write-Host ""
        Write-Host "=== Branches ==="
        git -C $MainRoot branch -vv
        Write-Host ""
        Write-Host "=== main vs origin/main ==="
        git -C $MainRoot rev-list --left-right --count main...origin/main
        Write-Host "(left=ahead, right=behind)"
        Write-Host ""
        Write-Host "=== develop vs origin/develop ==="
        $null = git -C $MainRoot rev-parse --verify origin/develop 2>$null
        if ($LASTEXITCODE -eq 0) {
            git -C $MainRoot rev-list --left-right --count develop...origin/develop
            Write-Host "(left=ahead, right=behind)"
        } else {
            Write-Host "origin/develop does not exist yet (push develop to create it)."
        }
    }
}
