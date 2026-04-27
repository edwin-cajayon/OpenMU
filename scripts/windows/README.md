# Windows dev helpers

PowerShell 7+ scripts for the most common developer actions on Windows.
All scripts are safe to run repeatedly (idempotent where possible).

Run them from the repo root:

```powershell
# Check that all prerequisites are installed
./scripts/windows/bootstrap.ps1

# Boot the all-in-one Docker stack (Postgres + OpenMU + nginx)
./scripts/windows/docker-up.ps1
./scripts/windows/docker-down.ps1

# Run the server from source (manual dev build)
./scripts/windows/dev-run.ps1                 # -autostart -resolveIP:loopback
./scripts/windows/dev-run.ps1 -Lan            # -autostart -resolveIP:local
./scripts/windows/dev-run.ps1 -Demo           # in-memory, no DB
./scripts/windows/dev-reset-db.ps1            # -autostart -resolveIP:loopback -reinit

# PostgreSQL backup / restore (writes to local/db-backups/, gitignored)
./scripts/windows/db-backup.ps1               # snapshot openmu DB, keep last 14
./scripts/windows/db-backup.ps1 -Retain 0     # one-off dump, no pruning
./scripts/windows/db-restore.ps1              # restore newest dump (with confirm)
./scripts/windows/db-restore.ps1 -DumpFile <path> -Force   # restore specific dump

# Windows Firewall rules (requires admin PowerShell)
./scripts/windows/firewall-open.ps1
./scripts/windows/firewall-close.ps1
```

**Backup before every `-reinit`.** `dev-reset-db.ps1` does not snapshot
automatically; if you reset the DB without dumping first, your seeded
accounts/characters are gone for good. Recommended pattern:

```powershell
./scripts/windows/db-backup.ps1               # snapshot first
./scripts/windows/dev-reset-db.ps1            # then wipe + re-seed
```

To schedule routine backups via Task Scheduler, register the script with
`schtasks` -- e.g. nightly at 03:00:

```powershell
schtasks /Create /SC DAILY /TN "OpenMU DB Backup" /ST 03:00 ^
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\path\to\OpenMU\scripts\windows\db-backup.ps1"
```

If PowerShell blocks script execution with an "execution policy" error, run
this once (as your user, not as admin):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

See `PLAN.md` §4–§7 for the full Windows setup story.
