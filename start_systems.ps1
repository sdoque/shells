# start_systems.ps1 — launch each system listed in systems.txt in its own window.
# Usage: .\start_systems.ps1 [systems.txt]
#
# The Windows counterpart of start_systems.sh. No tmux here: each system gets
# its own console window, titled after it, so a technician can see all of them
# at once and close one without touching the rest. A line may carry arguments
# after the system's name, as on Linux — "envoy -serve view cloudpicture".
param([string]$SystemsFile = "systems.txt")

if (-not (Test-Path $SystemsFile)) { Write-Error "systems file '$SystemsFile' not found"; exit 1 }

$entries = Get-Content $SystemsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
if ($entries.Count -eq 0) { Write-Error "no systems in '$SystemsFile'"; exit 1 }

foreach ($entry in $entries) {
    $parts = $entry -split '\s+', 2
    $name  = $parts[0]
    $args  = if ($parts.Count -gt 1) { $parts[1] } else { "" }
    $exe   = Join-Path $name "$($name)_win64.exe"
    if (-not (Test-Path $exe)) { Write-Warning "$exe not found — skipped"; continue }
    # Start in the system's own directory, because that is where it reads and
    # writes systemconfig.json, the certificate cache and its logs.
    Start-Process -FilePath (Resolve-Path $exe) -ArgumentList $args -WorkingDirectory $name -WindowStyle Normal
    Write-Host "started $entry"
    Start-Sleep -Milliseconds 500
}
Write-Host "Started $($entries.Count) system(s). Stop them with .\stop_systems.ps1"
