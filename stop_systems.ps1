# stop_systems.ps1 — stop every running mbaigo system on this machine.
#
# Ctrl-C in each window is the graceful way, and what a technician will do by
# hand; this is for stopping all of them at once. Stop-Process does not deliver
# a signal, so a system stopped this way does not unregister — the registrar
# retires its records when they lapse, within a registration period.
Get-Process | Where-Object { $_.ProcessName -like '*_win64' } | ForEach-Object {
    Write-Host "stopping $($_.ProcessName) ($($_.Id))"
    Stop-Process -Id $_.Id
}
