#Requires -Version 5.1
<#
.SYNOPSIS
    Take a `pg_dump` backup of the OpenMU PostgreSQL database.
.DESCRIPTION
    Writes a custom-format (`-F c`, gzip-compressed) dump to
    `local/db-backups/openmu-YYYYMMDD-HHmmss.dump` under the repo root.
    `local/` is gitignored so backups never leave the machine.

    Custom format (vs. plain SQL) is the canonical choice for production
    backups: smaller files, parallel restore (`pg_restore -j N`), and the
    ability to selectively restore individual tables.

    Run before any `-reinit`, before applying schema migrations, and on a
    cron / scheduled task for routine snapshots.
.PARAMETER Database
    Database name. Default: openmu.
.PARAMETER PgHost
    PostgreSQL host. Default: localhost.
.PARAMETER Port
    PostgreSQL port. Default: 5432.
.PARAMETER Username
    PostgreSQL admin user. Default: postgres.
.PARAMETER Password
    Admin password. Default: admin (matches ConnectionSettings.xml).
    Override with $env:PGPASSWORD before running for non-default setups.
.PARAMETER Retain
    Keep this many most-recent dumps; older ones are deleted. Default: 14.
    Pass 0 to disable retention pruning.
.PARAMETER OutputDir
    Override the dump destination. Default: <repo>/local/db-backups/.
.PARAMETER PgBinDir
    Override the PostgreSQL bin directory. Default: auto-detect from
    common install paths (PG 17 / 16 / 15).
.PARAMETER Verify
    After dumping, run `pg_restore --list` and assert that it lists at
    least 100 archive entries. Default: on. Pass -Verify:$false to skip.
.EXAMPLE
    ./scripts/windows/db-backup.ps1
    Default backup of `openmu` to local/db-backups/, keep last 14.
.EXAMPLE
    ./scripts/windows/db-backup.ps1 -Retain 0 -OutputDir D:\backups
    One-off dump to a different folder, no pruning.
#>
param(
    [string]$Database = 'openmu',
    [string]$PgHost = 'localhost',
    [int]$Port = 5432,
    [string]$Username = 'postgres',
    [string]$Password = 'admin',
    [int]$Retain = 14,
    [string]$OutputDir,
    [string]$PgBinDir,
    [switch]$Verify = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if (-not $OutputDir) {
    $OutputDir = Join-Path $repoRoot 'local/db-backups'
}

if (-not $PgBinDir) {
    $candidates = @(
        'C:\Program Files\PostgreSQL\17\bin',
        'C:\Program Files\PostgreSQL\16\bin',
        'C:\Program Files\PostgreSQL\15\bin'
    )
    $PgBinDir = $candidates | Where-Object { Test-Path (Join-Path $_ 'pg_dump.exe') } | Select-Object -First 1
    if (-not $PgBinDir) {
        Write-Host "Could not find pg_dump.exe under any of: $($candidates -join '; ')" -ForegroundColor Red
        Write-Host "Pass -PgBinDir explicitly." -ForegroundColor Red
        exit 1
    }
}

$pgDump    = Join-Path $PgBinDir 'pg_dump.exe'
$pgRestore = Join-Path $PgBinDir 'pg_restore.exe'

if (-not (Test-Path $pgDump))    { Write-Host "Missing: $pgDump"    -ForegroundColor Red; exit 1 }
if ($Verify -and -not (Test-Path $pgRestore)) {
    Write-Host "Missing: $pgRestore (needed for -Verify)" -ForegroundColor Red; exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$dumpPath = Join-Path $OutputDir "openmu-$stamp.dump"

Write-Host ("Backing up {0}@{1}:{2}/{3} -> {4}" -f $Username, $PgHost, $Port, $Database, $dumpPath) -ForegroundColor Cyan

$prevPgPassword = $env:PGPASSWORD
$env:PGPASSWORD = $Password
try {
    & $pgDump -h $PgHost -p $Port -U $Username -F c -f $dumpPath $Database
    if ($LASTEXITCODE -ne 0) {
        Write-Host "pg_dump failed with exit code $LASTEXITCODE" -ForegroundColor Red
        if (Test-Path $dumpPath) { Remove-Item $dumpPath -Force }
        exit $LASTEXITCODE
    }

    $sizeBytes = (Get-Item $dumpPath).Length
    $sizeMb    = [math]::Round($sizeBytes / 1MB, 2)
    Write-Host ("OK -- wrote {0} bytes ({1} MB)" -f $sizeBytes, $sizeMb) -ForegroundColor Green

    if ($Verify) {
        $tocLines = & $pgRestore --list $dumpPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "pg_restore --list failed (corrupt dump?)" -ForegroundColor Red
            exit 1
        }
        $tocCount = ($tocLines | Where-Object { $_ -match '^\d+; ' } | Measure-Object).Count
        if ($tocCount -lt 100) {
            Write-Host ("Verify FAILED: only {0} TOC entries (expected >=100)" -f $tocCount) -ForegroundColor Red
            exit 1
        }
        Write-Host ("Verify OK -- {0} TOC entries" -f $tocCount) -ForegroundColor Green
    }
}
finally {
    $env:PGPASSWORD = $prevPgPassword
}

if ($Retain -gt 0) {
    $all = Get-ChildItem -Path $OutputDir -Filter 'openmu-*.dump' | Sort-Object LastWriteTime -Descending
    if ($all.Count -gt $Retain) {
        $toDelete = $all | Select-Object -Skip $Retain
        foreach ($f in $toDelete) {
            Write-Host ("Pruning old dump: {0}" -f $f.Name) -ForegroundColor DarkGray
            Remove-Item $f.FullName -Force
        }
    }
    Write-Host ("Retained {0} most recent dump(s) in {1}" -f [Math]::Min($Retain, $all.Count), $OutputDir) -ForegroundColor Cyan
}
