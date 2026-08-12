param(
    [string]$Repository = 'repos-of/repos-of',
    [int]$PullRequest = 1,
    [string]$Reviewer = 'ottopoet-thesean',
    [int]$PollSeconds = 300,
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$stateRoot = Join-Path $PSScriptRoot '..\.local\repository-lifecycle'
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$statePath = Join-Path $stateRoot "pr-$PullRequest.json"
$eventsPath = Join-Path $stateRoot "events.jsonl"

function Invoke-GhJson([string[]]$Arguments) {
    $raw = & gh @Arguments --jq '.'
    if ($LASTEXITCODE -ne 0) { throw "gh failed: $($Arguments -join ' ')" }
    return ($raw | ConvertFrom-Json)
}

function Get-CollaboratorAccepted {
    & gh api "repos/$Repository/collaborators/$Reviewer" *> $null
    return ($LASTEXITCODE -eq 0)
}

function Get-Snapshot {
    $pr = Invoke-GhJson @('pr','view',"$PullRequest",'--repo',$Repository,'--json','state,headRefOid,updatedAt,comments,reviews,statusCheckRollup')
    $collaboratorAccepted = Get-CollaboratorAccepted
    $requestedReviewers = Invoke-GhJson @('api',"repos/$Repository/pulls/$PullRequest/requested_reviewers")
    $reviewRequested = @($requestedReviewers.users | ForEach-Object { $_.login }) -contains $Reviewer
    [ordered]@{
        collaboratorAccepted = $collaboratorAccepted
        reviewRequested = $reviewRequested
        state = $pr.state
        headRefOid = $pr.headRefOid
        comments = @($pr.comments | ForEach-Object { "$($_.author.login)|$($_.updatedAt)|$($_.body)" })
        reviews = @($pr.reviews | ForEach-Object { "$($_.author.login)|$($_.submittedAt)|$($_.state)" })
        checks = @($pr.statusCheckRollup | ForEach-Object { "$($_.context)|$($_.state)|$($_.completedAt)" })
    }
}

function Save-Event($Type, $Snapshot) {
    $event = [ordered]@{ type = $Type; observedAtUtc = [DateTime]::UtcNow.ToString('o'); snapshot = $Snapshot }
    ($event | ConvertTo-Json -Depth 8 -Compress) | Add-Content -LiteralPath $eventsPath -Encoding UTF8
    $event | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8
    Write-Output "REPOSITORY_LIFECYCLE_$($Type.ToUpperInvariant()): $Repository#$PullRequest"
}

$previous = $null
if (Test-Path -LiteralPath $statePath) { $previous = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json }

while ($true) {
    $snapshot = Get-Snapshot
    if ($snapshot.collaboratorAccepted -and -not $snapshot.reviewRequested) {
        & gh api --method POST "repos/$Repository/pulls/$PullRequest/requested_reviewers" -f "reviewers[]=$Reviewer" *> $null
        if ($LASTEXITCODE -ne 0) { throw "Unable to request review from $Reviewer" }
        $snapshot.reviewRequested = $true
        Save-Event 'REVIEW_REQUESTED' $snapshot
    } elseif ($null -eq $previous -or ($snapshot | ConvertTo-Json -Depth 8 -Compress) -ne ($previous.snapshot | ConvertTo-Json -Depth 8 -Compress)) {
        Save-Event 'PR_CHANGED' $snapshot
        if ($null -ne $previous) {
            Write-Output "REPOSITORY_LIFECYCLE_TRIGGERED: $Repository#$PullRequest"
            break
        }
    } else {
        Write-Output "REPOSITORY_LIFECYCLE_WAITING: collaborator=$($snapshot.collaboratorAccepted) reviewRequested=$($snapshot.reviewRequested)"
    }
    $previous = [pscustomobject]@{ snapshot = $snapshot }
    if ($Once) { break }
    Start-Sleep -Seconds $PollSeconds
}
