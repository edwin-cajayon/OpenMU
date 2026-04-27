#Requires -Version 5.1
<#
.SYNOPSIS
    Restore the OpenMU PostgreSQL database from a `pg_dump -F c` backup.
.DESCRIPTION
    DESTRUCTIVE: drops every object in the target database and re-creates
    it from the dump. The OpenMU server MUST be stopped before running.

    Default behaviour: pick the newest dump under local/db-backups/,
    confirm with the user, then `pg_restore --clean --if-exists`.

    By default this restores INTO the existing `openmu` DB. The owner
    roles (`config`, `account`, `friend`, `guild`) must already exist --
    they're created automatically on the first OpenMU server boot, so
    if you're restoring after dropping the DB but keeping the cluster,
    you're fine. If you've also dropped the role logins (e.g. via the
    cleanup snippet in faq.md), recreate them by booting the server
    once with `-reinit` first, OR add `--no-owner --no-privileges` to
    the pg_restore call below to ignore role grants.
.PARAMETER DumpFile
    Path to the .dump file. Default: newest openmu-*.dump under
    local/db-backups/.
.PARAMETER Database
    Target database. Default: openmu.
.PARAMETER PgHost
    PostgreSQL host. Default: localhost.
.PARAMETER Port
    PostgreSQL port. Default: 5432.
.PARAMETER Username
    Admin user. Default: postgres.
.PARAMETER Password
    Admin password. Default: admin.
.PARAMETER PgBinDir
    Override PostgreSQL bin dir. Default: auto-detect (PG 17 / 16 / 15).
.PARAMETER Force
    Skip the confirmation prompt. Use with care.
.PARAMETER NoOwner
    Pass --no-owner --no-privileges to pg_restore (skips role grants).
    Use this if you've dropped the OpenMU subordinate role logins.
.EXAMPLE
    ./scripts/windows/db-restore.ps1
    Restore the newest dump from local/db-backups/, with confirmation.
.EXAMPLE
    ./scripts/windows/db-restore.ps1 -DumpFile local/db-backups/openmu-20260427-181727.dump -Force
    Restore a specific dump, no prompt.
#>
param(
    [string]$DumpFile,
    [string]$Database = 'openmu',
    [string]$PgHost = 'localhost',
    [int]$Port = 5432,
    [string]$Username = 'postgres',
    [string]$Password = 'admin',
    [string]$PgBinDir,
    [switch]$Force,
    [switch]$NoOwner
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if (-not $PgBinDir) {
    $candidates = @(
        'C:\Program Files\PostgreSQL\17\bin',
        'C:\Program Files\PostgreSQL\16\bin',
        'C:\Program Files\PostgreSQL\15\bin'
    )
    $PgBinDir = $candidates | Where-Object { Test-Path (Join-Path $_ 'pg_restore.exe') } | Select-Object -First 1
    if (-not $PgBinDir) {
        Write-Host "Could not find pg_restore.exe under any of: $($candidates -join '; ')" -ForegroundColor Red
        Write-Host "Pass -PgBinDir explicitly." -ForegroundColor Red
        exit 1
    }
}

$pgRestore = Join-Path $PgBinDir 'pg_restore.exe'
if (-not (Test-Path $pgRestore)) { Write-Host "Missing: $pgRestore" -ForegroundColor Red; exit 1 }

if (-not $DumpFile) {
    $defaultDir = Join-Path $repoRoot 'local/db-backups'
    if (-not (Test-Path $defaultDir)) {
        Write-Host "No dump folder at $defaultDir. Pass -DumpFile explicitly." -ForegroundColor Red
        exit 1
    }
    $latest = Get-ChildItem -Path $defaultDir -Filter 'openmu-*.dump' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Host "No openmu-*.dump files found under $defaultDir" -ForegroundColor Red
        exit 1
    }
    $DumpFile = $latest.FullName
}

if (-not (Test-Path $DumpFile)) {
    Write-Host "Dump file not found: $DumpFile" -ForegroundColor Red
    exit 1
}

$dumpInfo = Get-Item $DumpFile
$sizeMb   = [math]::Round($dumpInfo.Length / 1MB, 2)

Write-Host ""
Write-Host "About to RESTORE the OpenMU database. THIS IS DESTRUCTIVE." -ForegroundColor Yellow
Write-Host ("  Dump file: {0} ({1} MB, {2})" -f $dumpInfo.FullName, $sizeMb, $dumpInfo.LastWriteTime) -ForegroundColor Yellow
Write-Host ("  Target:    {0}@{1}:{2}/{3}" -f $Username, $PgHost, $Port, $Database) -ForegroundColor Yellow
Write-Host "Stop the OpenMU server first or restore will fail with 'database in use'." -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Type 'yes' to continue"
    if ($confirm -ne 'yes') {
        Write-Host "Aborted." -ForegroundColor Red
        exit 1
    }
}

$restoreArgs = @(
    '-h', $PgHost,
    '-p', $Port,
    '-U', $Username,
    '-d', $Database,
    '--clean',
    '--if-exists',
    '--no-password',
    $DumpFile
)
if ($NoOwner) {
    $restoreArgs = @('--no-owner', '--no-privileges') + $restoreArgs
}

Write-Host ("Running: pg_restore {0}" -f ($restoreArgs -join ' ')) -ForegroundColor Cyan

$prevPgPassword = $env:PGPASSWORD
$env:PGPASSWORD = $Password
try {
    & $pgRestore @restoreArgs
    $exit = $LASTEXITCODE
}
finally {
    $env:PGPASSWORD = $prevPgPassword
}

if ($exit -ne 0) {
    Write-Host ""
    Write-Host ("pg_restore returned exit code {0}." -f $exit) -ForegroundColor Yellow
    Write-Host "Non-zero exit is common when the dump references roles or" -ForegroundColor Yellow
    Write-Host "extensions that don't exist on the target -- the data itself" -ForegroundColor Yellow
    Write-Host "is usually fine. Spot-check with psql before re-running." -ForegroundColor Yellow
    exit $exit
}

Write-Host "Restore completed successfully." -ForegroundColor Green
