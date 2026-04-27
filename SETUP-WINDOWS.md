# OpenMU — Quickstart on a Fresh Windows PC

> Goal: get this fork running locally on a brand-new Windows machine in ~10 minutes.
> Companion docs: `PLAN.md` (project plan), `faq.md` (deep gotchas), `GMchat.md` (in-game GM commands).

## 1. Install prerequisites (one-time)

Run in an **elevated PowerShell** (winget needs admin to install services):

```powershell
winget install --id Git.Git -e
winget install --id Microsoft.DotNet.SDK.10 -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id PostgreSQL.PostgreSQL.17 -e --override "--unattendedmodeui none --mode unattended --superpassword admin"
```

When the PostgreSQL installer is done:

- Service name: `postgresql-x64-17` (auto-starts on boot)
- Superuser: `postgres` / `admin`
- Install path: `C:\Program Files\PostgreSQL\17\`

Open a **new** PowerShell window so `dotnet`, `git`, `psql` resolve on PATH.

## 2. Clone the repo

```powershell
cd $HOME\source\repos    # or wherever you keep code
git clone <YOUR_FORK_URL> OpenMU
cd OpenMU\OpenMU         # important: nested repo layout — server lives in OpenMU/OpenMU
```

> The repo layout has a top-level wrapper folder; the actual project is one level deeper. `dev-run.ps1` and friends only resolve from inside the inner `OpenMU/` directory.

## 3. Verify prerequisites

```powershell
./scripts/windows/bootstrap.ps1
```

Expect green checkmarks for Git, .NET SDK, Node, Docker (Docker is optional — only red is OK if you skip it). PostgreSQL 17.x must show OK.

## 4. Create the PostgreSQL database

```powershell
$env:PGPASSWORD = "admin"
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -c "CREATE DATABASE openmu;"
```

The OpenMU server will create the schemas, tables, and per-context login roles (`config`, `account`, `friend`, `guild` — passwords = role names) on first launch.

## 5. Build first, then run (Bug 1 workaround)

**Do not skip the build step.** The Persistence project has a Roslyn source generator that gets compiled into `bin\Release` only on a Release build. If you go straight to `dotnet run`, you'll hit `MUnique.OpenMU.Persistence.SourceGenerator.exe not found`.

```powershell
dotnet build src\MUnique.OpenMU.sln -c Release
```

First build pulls a lot of NuGet packages — expect 2–4 minutes.

## 6. Start the server

```powershell
./scripts/windows/dev-run.ps1
```

That runs `dotnet run --project src/Startup -- -autostart -resolveIP:loopback`. Watch for these log lines:

```
[Information] Host started, elapsed time: 00:00:11.x
[Information] Admin Panel bound to urls: "http://[::]:80"
[Information] Starting Server Listener, port 55901
... ports 55902, 55903, 55980 (chat), 44405, 44406 (connect) ...
```

Leave this terminal open — it's your live server log. To stop: **Ctrl+C** in this window, or `Stop-Process -Id <pid>` from another window.

## 7. Confirm the admin panel is up

Browse to <http://localhost/>. You should see the OpenMU admin panel (no auth on the manual-run path). Check:

- **Servers** page → 3 game servers, 1 chat server, 2 connect servers, all green
- **Accounts** page → ~20 seeded test accounts (`test0`–`test9`, `testgm`, `testgm2`, `test300`, `test400`, etc.)

If accounts list is empty, the DB schema didn't seed. See `faq.md` Bug 3 for the fix (`-reinit` or migration column patch).

## 8. Connect with the game client

You need an **MU Online Season 6 EP3 ENG** client (not in this repo — get it via the OpenMU Discord FAQ).

1. Edit the client's connect-server IP to `127.127.127.127` (any `127.x.x.x` except `127.0.0.1` works; `127.0.0.1` is blocked by the client).
2. Launch with the launcher binary or directly via `Main.exe`.
3. To run the client in **windowed mode**, set the registry first:
   ```powershell
   New-ItemProperty -Path "HKCU:\SOFTWARE\WebZen\Mu\Config" -Name WindowMode -Value 1 -PropertyType DWord -Force
   ```
4. Log in with one of the seeded accounts:

| Login | Password | Notes |
|---|---|---|
| `test0` … `test9` | same as login | Levels 1, 10, 20 … 90 |
| `testgm` | `testgm` | All 5 classes, all GameMaster |
| `testgm2` | `testgm2` | Rage Fighter + Summoner, GM |

5. Character names: client UI **rejects names < 4 characters** even though the server allows 3. Use 4+ chars.
6. Account creation has **no in-game / launcher path** — create new accounts via admin panel → Accounts → "Create new".

## 9. Daily start/stop after first time

Subsequent launches don't need build or DB-create:

```powershell
cd $HOME\source\repos\OpenMU\OpenMU
./scripts/windows/dev-run.ps1            # start
# Ctrl+C in that window to stop
```

PostgreSQL service auto-starts on boot, so it's already running.

Useful one-offs:

```powershell
./scripts/windows/db-backup.ps1           # snapshot DB to local/db-backups/
./scripts/windows/db-restore.ps1          # restore newest snapshot (server must be stopped)
./scripts/windows/dev-reset-db.ps1        # nuke + reseed DB (always backup first)
./scripts/windows/dev-run.ps1 -Lan        # bind to LAN IP for friends on the same network
./scripts/windows/firewall-open.ps1       # open Windows Firewall for game ports
```

## 10. Where to go next

- **GM commands & gearing** → `GMchat.md` (full `/item` recipe book, Phase C plug-in toggles, Dark Knight gearing case study in §6).
- **Deep troubleshooting / known bugs** → `faq.md` (every error this project hit, with the fix).
- **Project plan, phases, status** → `PLAN.md`.
- **Going public on a VPS** → `PLAN.md` §8 (Phase D, not done yet).

## 11. If something breaks

Quick triage order:

1. Is the PostgreSQL service running? `Get-Service postgresql-x64-17`
2. Did `dotnet build -c Release` succeed at least once? Re-run it.
3. Is anything else holding ports 80, 55901-55906, 44405-44406, 55980? `Get-NetTCPConnection -LocalPort 80 -State Listen`
4. Check `faq.md` "Bugs encountered & fixes" — every issue this project ever hit is logged there.
5. Last resort: `./scripts/windows/dev-reset-db.ps1` (after `db-backup.ps1`!) and start clean.
