# Git workflow helpers for the Felix Odysseus fork.
# Usage: .\scripts\git-workflow.ps1 <command> [args]
#
# Commands:
#   experiment <name>   Create feature/<name> from develop
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
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

function Require-CleanTree {
    $status = git status --porcelain
    if ($status) {
        throw "Working tree is not clean. Commit or stash changes first."
    }
}

switch ($Command) {
    'experiment' {
        if (-not $Name) { throw "Usage: git-workflow.ps1 experiment <name>" }
        Require-CleanTree
        git checkout develop
        git pull --ff-only origin develop 2>$null
        git checkout -b "feature/$Name"
        Write-Host "Created feature/$Name from develop."
    }
    'finish' {
        $branch = git branch --show-current
        if ($branch -notlike 'feature/*') {
            throw "Switch to a feature/* branch first (currently on '$branch')."
        }
        Require-CleanTree
        git checkout develop
        git merge --no-ff $branch -m "Merge $branch into develop"
        Write-Host "Merged $branch into develop. Test on develop, then run: .\scripts\git-workflow.ps1 promote"
    }
    'promote' {
        Require-CleanTree
        git checkout main
        git merge --no-ff develop -m "Promote develop to main (stable)"
        Write-Host "Promoted develop -> main."
        Write-Host "Next: git push origin main"
        Write-Host "Optional: git push origin develop"
    }
    'sync-upstream' {
        Require-CleanTree
        git fetch upstream
        git checkout develop
        git merge --no-ff upstream/dev -m "Integrate upstream/dev into develop"
        Write-Host "Merged upstream/dev into develop. Test, then promote if ready."
    }
    'status' {
        git fetch origin 2>$null
        git fetch upstream 2>$null
        Write-Host "=== Local branches ==="
        git branch -vv
        Write-Host ""
        Write-Host "=== main vs origin/main ==="
        git rev-list --left-right --count main...origin/main 2>$null
        Write-Host "(left=ahead, right=behind)"
        Write-Host ""
        Write-Host "=== develop vs origin/develop ==="
        git rev-list --left-right --count develop...origin/develop 2>$null
        Write-Host "(left=ahead, right=behind; remote may not exist yet)"
    }
}
