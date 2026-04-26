# OpenMU Setup Journal & FAQ

Running log of setting up a MU Online private server from the [MUnique/OpenMU](https://github.com/MUnique/OpenMU) repository on Windows. Captures what was done, bugs encountered, and the exact fix for each.

**Machine:** Windows, PowerShell
**Repo location:** `C:\Users\Lvl 100 Mafia Boss\Downloads\Telegram Desktop\Rotating Earth\Rotating Earth\OpenMU\`
**Path chosen:** Manual build with .NET SDK (Docker installation was not possible).
**Phase approach:**
- **Phase A** = in-memory demo run (no database) — smoke test that the server + admin panel come up and a real client can log in. ✅ done
- **Phase B** = real run with PostgreSQL (persistent accounts/characters). ✅ done — verified end-to-end on 2026-04-26: custom account `edwin` created in admin panel, Dark Knight character `6GOD` created in-game, played + leveled to EXP 5671 / 30 stat pts, character + progression confirmed to persist across server restart
- **Phase C** = customisation (game version, XP/drop rates, plugin toggles, GM commands per `GMchat.md`) — pending
- **Phase D** = public hosting on a Linux VPS via the `deploy/all-in-one` Docker stack — pending

---

## Progress log

| # | Status | Step | Evidence |
|---|---|---|---|
| 1 | done | Read top-level docs: `OpenMU/README.md`, `OpenMU/QuickStart.md`, `OpenMU/CONTRIBUTING.md`, `OpenMU/docs/Readme.md`, `OpenMU/docs/Progress.md` | — |
| 2 | done | Read + committed to follow `OpenMU/.cursorrules` | — |
| 3 | done | Decided on manual-build path (Docker not installable on this machine) | — |
| 4 | done | Verified no .NET SDK was present (`dotnet --list-sdks` returned "No .NET SDKs were found") | — |
| 5 | done | Installed **.NET SDK 10.0.203** via `winget install Microsoft.DotNet.SDK.10` | `dotnet --list-sdks` now reports `10.0.203 [C:\Program Files\dotnet\sdk]` |
| 6 | done | Confirmed all 10 required TCP ports free: `80, 44405, 44406, 55901–55906, 55980` | — |
| 7 | done | Built the solution in **Release** configuration | 0 errors, ~1000 pre-existing StyleCop/XML-doc warnings. Build time ~60s on warm cache |
| 8 | done | Launched server in demo mode | All 10 sockets listening under PID of `MUnique.OpenMU.Startup`, admin panel returns `HTTP 200 OK` at `http://localhost/` |
| 9 | done | Loaded admin panel at `http://localhost/` in browser, confirmed connect + game + chat servers listed | — |
| 10 | done | Connected **MUnique.OpenMU.ClientLauncher v0.9.6** pointing at `127.127.127.127:44405` using a Season 6 client, logged in with `test0`/`test0` — **end-to-end Phase A verified** | User confirmed login works in-game |
| 11 | done | Stopped demo server cleanly (all 10 ports freed) before switching to real DB | — |
| 12 | done | Installed **PostgreSQL 17.9** via `winget install PostgreSQL.PostgreSQL.17` with silent-install args, service `postgresql-x64-17` is `Automatic/Running` on port `5432`, superuser `postgres` password set to `admin` | `psql --version` = `17.9`; login test `SELECT 't'::text` returned `t` |
| 13 | done | Confirmed `ConnectionSettings.xml` already matches (`postgres`/`admin` on the first two contexts) — **no edit needed** | See file contents at `src/Persistence/EntityFramework/ConnectionSettings.xml` |
| 14 | done | Discovered + fixed **Bug 3** (two migrations missing `[Migration]` attribute, silently skipped) | See Bug 3 below |
| 15 | done | Rebuilt `Startup` project so its `bin\Release\` picked up the new `EntityFramework.dll` (Bug 3 sub-gotcha) | — |
| 16 | done | Launched server in real-DB mode. Initialization took ~22s: EF migrations applied, subordinate roles created, initial Season-6 data seeded, host started in 27.6 s total | DB has `openmu` database + `config/account/friend/guild` roles; `GameConfiguration` table has the `ExcellentItemDropLevelDelta` + `MasterExperienceRate` columns; all 10 ports listening |
| 17a | done | Phase B re-launch on 2026-04-26: server came up clean in 12.6 s (no reinit needed, DB survived from previous session). All 12 expected ports listening: 80 (admin panel), 44405–44408 (4 Connect Servers — extra `44407/44408` were configured in admin panel earlier), 55901–55906 (6 Game Servers), 55980 (Chat Server). `Invoke-WebRequest http://localhost/` returns `HTTP 200 OK` on Kestrel. | Server log shows `Host started, elapsed time: 00:00:12.5882078`; all 3 game servers labelled "PREMIUM PROMAX" registered with endpoint `127.127.127.127:55901-55906` against all 4 connect servers |
| 17b | done | Pre-launch DB sanity check: `data."Account"` has 20 rows (all seeded test accounts present including `testgm`/`testgm2`/`testunlock`); `config."GameConfiguration"` has 1 row. Note: `config."__EFMigrationsHistory"` does NOT exist — confirms the previous Phase B init went through the EF `EnsureCreated` fallback path, not `Migrate`. Schema and seed data are correct, but a future migration would not be auto-applied. | psql `\dt` + counts |
| 17c | done | Admin-panel walkthrough verified: created custom account `edwin` (State=GameMaster, BCrypt-hashed password) via the Accounts → "Create new" modal — row landed in `data."Account"` correctly. Implies Accounts page, modal, and EF write path all work against the real DB. | `data."Account"` row for `edwin` registered 2026-04-26 11:33:53 |
| 18 | done | Persistence test passed end-to-end. Logged in as `edwin/edwin` via launcher (port 44405, host 127.127.127.127), created a Dark Knight character `6GOD` (4 chars — see Gotcha below). Spawned at Lorencia entry gate (150,129). Played, leveled up. Verified row persists across disconnect+reconnect; user confirmed character + progression also persist across server restart. Final captured state: Experience=5671, LevelUpPoints=30, position (149,121), CharacterStatus=0. **Phase B fully verified.** | psql query against `data."Character"` |
| 19 | pending | Phase C — customise game version / XP / drop rates / plugin toggles via admin panel | — |
| 20 | pending | Phase C — set up a `pg_dump` backup before any `-reinit` | — |
| 21 | pending | Phase D — rent Linux VPS, deploy `OpenMU/deploy/all-in-one/` there with `RESOLVE_IP=public` or domain name | — |

---

## Bugs encountered & fixes

### Bug 1 — `dotnet build` fails on first run: `MUnique.OpenMU.Persistence.SourceGenerator.exe` not found

#### Symptom

```
Unhandled exception: An error occurred trying to start process
  'C:\...\src\Persistence\SourceGenerator\bin\Release\MUnique.OpenMU.Persistence.SourceGenerator.exe'
  with working directory 'C:\...\src\Persistence\EntityFramework'.
  The system cannot find the file specified.

error MSB3073: The command "dotnet run -p ../SourceGenerator/... -c:Release
  MUnique.OpenMU.Persistence.EntityFramework ... --no-build" exited with code 1.
```

Build output at end: `Build FAILED. 2 Error(s)`.

#### Root cause

Two projects have MSBuild `<Target Name="PreBuild">` steps that invoke the source-generator tool with `--no-build`:

- `src/Persistence/EntityFramework/MUnique.OpenMU.Persistence.EntityFramework.csproj` line **52**
- `src/Persistence/MUnique.OpenMU.Persistence.csproj` line **45**

`--no-build` tells `dotnet run` to assume the target executable already exists. But there is **no `ProjectReference` edge from these projects to the SourceGenerator project** — they call it via CLI. Because `dotnet build SLN` builds projects in parallel, MSBuild can start the PreBuild steps of the Persistence projects before the SourceGenerator has finished compiling, so the `.exe` doesn't exist yet.

#### Fix

Build the SourceGenerator project explicitly first, then build the full solution:

```powershell
cd "C:\Users\Lvl 100 Mafia Boss\Downloads\Telegram Desktop\Rotating Earth\Rotating Earth\OpenMU\src"

# 1. Build the source generator first
dotnet build Persistence\SourceGenerator\MUnique.OpenMU.Persistence.SourceGenerator.csproj -c Release

# 2. Now build the full solution
dotnet build MUnique.OpenMU.sln -c Release
```

Second build succeeded: `0 Error(s)`, ~58 s.

#### Alternatives (not used)

- Set `-p:ci=true` to skip the PreBuild target (but then auto-generated EF model files may be stale/missing and compile will fail elsewhere).
- Force serial build: `dotnet build MUnique.OpenMU.sln -m:1` (works but dramatically slower).

---

### Bug 2 — Server crashes on startup with `-resolveIP:loopback`

#### Symptom

```
[Fatal] Unhandled exception leading to terminating application:
  System.ArgumentException: When using a custom resolver type, a parameter with an IP
  or host name is required. (Parameter 'parameter')
    at MUnique.OpenMU.Network.ConfigurableIpResolver.ApplyConfiguration(
       IpResolverType resolverType, String parameter, Boolean raiseEvent)
       in ...\src\Network\ConfigurableIpResolver.cs:line 70
```

But `-resolveIP:loopback` is documented as a valid flag in `OpenMU/src/Startup/Readme.md` (lines 44–50) and the code at `src/Network/IpAddressResolverFactory.cs` lines 54–60 handles it as a built-in (no parameter needed).

#### Root cause

**PowerShell's native-command argument parser mangles `-flag:value` patterns.** When you type:

```powershell
dotnet run --project Startup -- -demo -autostart -resolveIP:loopback
```

PowerShell can split `-resolveIP:loopback` and drop the part after the colon, so the program actually receives the bare string `"-resolveIP:"`. The factory's switch statement doesn't match any built-in (`-resolveIP:loopback`, `-resolveIP:local`, `-resolveIP:public`), falls into the default `Custom` case (`src/Network/IpAddressResolverFactory.cs` line 59), which then extracts the substring after the colon — an **empty string**. `ConfigurableIpResolver` sees `IpResolverType.Custom` with a null/empty parameter and throws at `ConfigurableIpResolver.cs` line 68–70.

#### Fix

Use the `RESOLVE_IP` environment variable instead. The factory reads it at `src/Network/IpAddressResolverFactory.cs` lines 63–78 and it takes bare values (`loopback`, `local`, `public`) — no colon parsing involved.

```powershell
$env:RESOLVE_IP = "loopback"
dotnet run --project Startup -c Release --no-build -- -demo -autostart -deamon
```

The server now binds correctly and registers each game server with the ConnectServer using endpoint `127.127.127.127:55901–55906`, confirmed in the logs.

#### Alternatives

- **Quote the argument:** `dotnet run ... -- "-resolveIP:loopback"` — should also work in PowerShell but not tested this session.
- **Put the arg after `--%`:** PowerShell's stop-parsing symbol — also avoids the native parser entirely.
- **Configure via admin panel** (`Configuration → System`) instead of CLI: the setting persists (in-memory in demo mode, in DB otherwise).

---

### Bug 3 — Phase B first-launch crash: `column "ExcellentItemDropLevelDelta" of relation "GameConfiguration" does not exist`

#### Symptom

On the very first run against a real PostgreSQL database (no `-demo`), the server logs:

```
The database is getting (re-)initialized...
[Fatal] Unhandled exception leading to terminating application:
  Microsoft.EntityFrameworkCore.DbUpdateException:
  Npgsql.PostgresException (0x80004005):
  42703: column "ExcellentItemDropLevelDelta" of relation "GameConfiguration" does not exist
```

Stack trace lands in `DataInitializationBase.CreateInitialDataAsync` at line 97 during `SaveChangesAsync` — the schema was created, but an INSERT is referencing a column that isn't there.

#### Investigation

Inspected the live DB state after the crash:

```
\dt config.*                              -- 70+ tables created ✓
\d config."GameConfiguration"             -- table exists, column missing ✗
SELECT to_regclass('config."__EFMigrationsHistory"');   -- NULL ✗
```

So `MigrateAsync()` ran but left the `__EFMigrationsHistory` table uncreated and the recent migration un-applied.

Listed the migrations folder:

```
Migrations\20260402113000_AddGlobalMasterExperienceRate.cs          1231 B   (no .Designer.cs)
Migrations\20260404225637_AddExcellentItemDropLevelDelta.cs          968 B   (no .Designer.cs)
Migrations\20260405170905_UpdateDaybreakWeaponDimensions.cs          866 B   (no .Designer.cs)
```

Every migration before these has a paired `.Designer.cs`; these three don't.

The **working** one (`20260402113000_AddGlobalMasterExperienceRate.cs`) has the migration-identifying attributes inlined in the `.cs` file:

```csharp
[DbContext(typeof(EntityDataContext))]
[Migration("20260402113000_AddGlobalMasterExperienceRate")]
public partial class AddGlobalMasterExperienceRate : Migration
```

The **broken** two don't — they just have `public partial class ... : Migration`.

#### Root cause

Without the `[Migration("<id>")]` attribute, **EF Core's `IMigrationsAssembly` does not discover the class as a migration at all.** The migrations are silently skipped; `MigrateAsync()` reports success; `EnsureCreated`-style fallback then lays down a schema from the model snapshot but without running any `Up()`, so the `__EFMigrationsHistory` table is never populated. When it works — that's pure coincidence here, because the model snapshot does contain the new column; but on some EF versions the fallback uses the last-known-good snapshot state and misses recent additions, which is exactly what happened.

In practice, someone committed these three migrations without generating the Designer files (where these attributes are normally emitted by `dotnet ef migrations add`).

#### Fix

Add the missing attributes inline. For `20260404225637_AddExcellentItemDropLevelDelta.cs` the patched top is:

```csharp
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MUnique.OpenMU.Persistence.EntityFramework.Migrations
{
    [DbContext(typeof(EntityDataContext))]
    [Migration("20260404225637_AddExcellentItemDropLevelDelta")]
    public partial class AddExcellentItemDropLevelDelta : Migration
    { ... }
}
```

Same change applied to `20260405170905_UpdateDaybreakWeaponDimensions.cs`. (The third bare file, `20260402113000_AddGlobalMasterExperienceRate.cs`, was already correct.)

#### Sub-gotcha — `--no-build` + project refs don't propagate

After fixing the migrations I rebuilt **only** `Persistence.EntityFramework.csproj`, then re-ran `dotnet run --project Startup --no-build`. Server crashed with the same error. Reason: `Startup/bin/Release/net10.0/` still had the **old** `MUnique.OpenMU.Persistence.EntityFramework.dll` — rebuilding a project-ref does not automatically update the `bin` of projects that consume it unless you build them too.

The fix: rebuild `Startup` (which pulls in the fresh transitive DLL):

```powershell
dotnet build Startup\MUnique.OpenMU.Startup.csproj -c Release
```

Then `dotnet run --no-build` picks up the right DLL.

#### Verification after the fix

```
psql openmu -c "\d config.\"GameConfiguration\""
-- now lists: ExcellentItemDropLevelDelta smallint, MasterExperienceRate real, ...

psql openmu -c 'SELECT count(*) FROM config."GameConfiguration";'
-- 1

Server log:
  The database is getting (re-)initialized...
  ...initialization finished.
  Host started, elapsed time: 00:00:27.6511883
```

---

### Gotcha: `-deamon` (typo) is the flag to skip stdin handling

`src/Startup/Readme.md` line 32 documents the flag as **`-deamon`** — note the typo (should be `daemon`). When running detached / in the background on Windows, pass `-deamon` or the process will sit waiting for keyboard input.

---

### Gotcha: MU client (`Main.exe`) UI rejects 3-letter character names

The OpenMU server-side `GameConfiguration.CharacterNameRegex` defaults to `^[a-zA-Z0-9]{3,10}$` — i.e. 3–10 alphanumeric chars are allowed at the protocol/server/DB level. But the Webzen `Main.exe` character-creation dialog has a **client-side hardcoded minimum of 4 characters** that fires before any packet reaches the server. Source-of-truth flow: `src/GameLogic/PlayerActions/Character/CreateCharacterAction.cs:56` does `Regex.IsMatch(name, GameConfiguration.CharacterNameRegex)` against the configured regex; the wire format `docs/Packets/C1-F3-01-CharacterCreationSuccessful_by-server.md` reserves 10 bytes; DB column `data."Character"."Name"` is plain `text` with only the unique index `IX_Character_Name`. So if you want 3-letter names, the only real fix is a hex edit of `Main.exe` (risky) or use the open-source MuMain client on port 44406 (rougher but no Webzen UI lock).

### Gotcha: Account creation has no in-game / launcher path

`src/GameLogic/PlayerActions/LoginAction.cs:58-77` shows the login flow: if `AuthenticateAsync` returns null (account-not-found OR wrong password), the client just gets `LoginResult.InvalidPassword` — the misleading "incorrect password" message even when the account doesn't exist. There is no auto-create-on-first-login branch. The only built-in account-creation path is the **admin panel** (`src/Web/Shared/Services/AccountService.cs:82` — `CreateNewInModalDialogAsync`). The form requires LoginName (3-10), Password (3-20), SecurityCode (3-10, **required even though the launcher never asks for it**), and an optional EMail. Password is hashed with BCrypt before INSERT.

### Gotcha: MU client window mode lives in the registry

The Webzen client reads display settings from `HKEY_CURRENT_USER\SOFTWARE\WebZen\Mu\Config` at startup (DWORDs: `WindowMode 0|1`, `Resolution`, `ColorDepth`, `MusicOnOff`, `SoundOnOff`, `VolumeLevel`; string: `LangSelection`). Source: `src/ClientLauncher/ClientSettings.cs:67-93`. Setting it via `Set-ItemProperty -Path 'HKCU:\SOFTWARE\WebZen\Mu\Config' -Name WindowMode -Value 1 -Type DWord` works (verified). The OpenMU launcher's "Settings" button opens a dialog that toggles the same registry values — either path is fine. Note the launcher uses `RegistryView.Registry32` so on some Windows installs it may write to the WoW6432Node redirect — on this machine it ended up at the non-redirected key.

### Gotcha: Serilog writes logs relative to the **working directory**, not the project

`src/Startup/appsettings.json` has `"path": "logs/log.txt"` for the file sink. When launched with `dotnet run --project Startup` from the `src/` folder, the CWD at runtime is **`src/Startup/`** (the project folder, not where you ran the command). So the real log path is:

```
OpenMU\src\Startup\logs\log<YYYYMMDD>.txt
```

Daily-rolling file. Use this for `Get-Content -Tail 50 -Wait` when live-debugging.

---

## Working commands (known good)

### Build from scratch (fixes Bug 1)

```powershell
cd "C:\Users\Lvl 100 Mafia Boss\Downloads\Telegram Desktop\Rotating Earth\Rotating Earth\OpenMU\src"
dotnet build Persistence\SourceGenerator\MUnique.OpenMU.Persistence.SourceGenerator.csproj -c Release
dotnet build MUnique.OpenMU.sln -c Release
```

### Run in demo mode (no PostgreSQL, volatile state)

```powershell
cd "C:\Users\Lvl 100 Mafia Boss\Downloads\Telegram Desktop\Rotating Earth\Rotating Earth\OpenMU\src"
$env:RESOLVE_IP = "loopback"
dotnet run --project Startup -c Release --no-build -- -demo -autostart -deamon
```

### Run against the real PostgreSQL DB (Phase B)

```powershell
cd "C:\Users\Lvl 100 Mafia Boss\Downloads\Telegram Desktop\Rotating Earth\Rotating Earth\OpenMU\src"
$env:RESOLVE_IP = "loopback"

# First-ever run: omit -autostart so we can inspect/fix data before servers start.
dotnet run --project Startup -c Release --no-build -- -deamon

# Subsequent runs after setup is verified:
dotnet run --project Startup -c Release --no-build -- -autostart -deamon
```

Expected log on first-ever run:
```
The database is getting (re-)initialized...
...initialization finished.
Game Server 0..2 initialized
Host started, elapsed time: 00:00:27.x
Admin Panel bound to urls: "http://[::]:80"
Client Listener started, Port 44405
Client Listener started, Port 44406
```

### Nuke the DB and start fresh (e.g. to re-apply migrations after a code change)

```powershell
$env:PGPASSWORD = "admin"
$psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
& $psql -h localhost -U postgres -d postgres -c "DROP DATABASE IF EXISTS openmu;"
& $psql -h localhost -U postgres -d postgres -c "DROP ROLE IF EXISTS config;"
& $psql -h localhost -U postgres -d postgres -c "DROP ROLE IF EXISTS account;"
& $psql -h localhost -U postgres -d postgres -c "DROP ROLE IF EXISTS friend;"
& $psql -h localhost -U postgres -d postgres -c "DROP ROLE IF EXISTS guild;"
$env:PGPASSWORD = $null
```

Alternative (in-process): pass `-reinit` to the Startup CLI — it wipes and rebuilds automatically.

### Back up the real DB (do this before any `-reinit`!)

```powershell
$env:PGPASSWORD = "admin"
& "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" -h localhost -U postgres -F c -f "openmu-$(Get-Date -Format yyyyMMdd-HHmmss).dump" openmu
$env:PGPASSWORD = $null
```

Restore:

```powershell
$env:PGPASSWORD = "admin"
& "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe" -h localhost -U postgres -d openmu -c "openmu-20260423-195500.dump"
$env:PGPASSWORD = $null
```

### Verify the running server

```powershell
$ports = 80,44405,44406,55901,55902,55903,55904,55905,55906,55980
foreach ($p in $ports) {
  $hit = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
  if ($hit) {
    $proc = Get-Process -Id $hit[0].OwningProcess -ErrorAction SilentlyContinue
    "LISTEN $p -> PID $($hit[0].OwningProcess) ($($proc.ProcessName))"
  } else {
    "NO     $p"
  }
}

Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -MaximumRedirection 0
```

### Tail the live log

```powershell
Get-Content "C:\Users\Lvl 100 Mafia Boss\Downloads\Telegram Desktop\Rotating Earth\Rotating Earth\OpenMU\src\Startup\logs\log$(Get-Date -Format yyyyMMdd).txt" -Tail 50 -Wait
```

### Stop the server

```powershell
Get-Process -Name "MUnique.OpenMU.Startup"   # find PID
Stop-Process -Name "MUnique.OpenMU.Startup"  # kill it
```

### Start / stop the PostgreSQL service

```powershell
Get-Service postgresql-x64-17              # status
Start-Service postgresql-x64-17
Stop-Service postgresql-x64-17
Restart-Service postgresql-x64-17
```

---

## Flag reference

From `src/Startup/Readme.md`:

| Flag | Effect |
|---|---|
| `-demo` | In-memory database, no PostgreSQL. **Progress is not persisted.** |
| `-autostart` | Start all TCP listeners automatically (no manual click in admin panel) |
| `-deamon` | Don't read stdin (needed when running detached) |
| `-reinit` | Wipe and recreate the database (ignored with `-demo`) |
| `-version:season6` / `-version:0.75` / `-version:0.95d` | Only with `-reinit` or `-demo`, picks the initial game data |
| `-adminpanel:disabled` | Hide the admin panel (implies `-autostart`) |

Env var alternative for `-resolveIP:` (avoids PowerShell colon bug):

| Value | Meaning |
|---|---|
| `RESOLVE_IP=loopback` | Reports `127.127.127.127` to clients (use for local-only play) |
| `RESOLVE_IP=local` | Auto-picks a LAN IP (use for play within your home network) |
| `RESOLVE_IP=public` | Queries ipify.org for your public IP (use for internet-facing hosting) |
| `RESOLVE_IP=203.0.113.42` | A literal IPv4 or host name |

Other env vars (`src/Startup/Readme.md` lines 53–62):

| Env var | Effect |
|---|---|
| `ASPNETCORE_ENVIRONMENT=Development` / `Production` | Picks `appsettings.{Environment}.json` |
| `ASPNETCORE_URLS=http://+:80;https://+:443` | Override admin-panel bindings |
| `DB_HOST=hostname` | Override the Postgres host from `ConnectionSettings.xml` |
| `DB_ADMIN_USER=postgres` | Override the admin user |
| `DB_ADMIN_PW=…` | Override the admin password |

---

## Important file/path references

| What | Where |
|---|---|
| Solution | `OpenMU/src/MUnique.OpenMU.sln` |
| Startup project (main entry) | `OpenMU/src/Startup/MUnique.OpenMU.Startup.csproj` |
| Startup docs (flags, env vars) | `OpenMU/src/Startup/Readme.md` |
| Logging config | `OpenMU/src/Startup/appsettings.json` |
| Live log file (runtime) | `OpenMU/src/Startup/logs/log<YYYYMMDD>.txt` |
| DB connection strings | `OpenMU/src/Persistence/EntityFramework/ConnectionSettings.xml` |
| EF migrations folder | `OpenMU/src/Persistence/EntityFramework/Migrations/` |
| EF model snapshot | `OpenMU/src/Persistence/EntityFramework/Migrations/EntityDataContextModelSnapshot.cs` |
| `MigrateAsync()` entry point | `OpenMU/src/Persistence/EntityFramework/PersistenceContextProvider.cs` line 66 |
| Data seed logic | `OpenMU/src/Persistence/Initialization/DataInitializationBase.cs` (line 97 is where Bug 3 crashes) |
| EF PreBuild target (Bug 1) | `OpenMU/src/Persistence/EntityFramework/MUnique.OpenMU.Persistence.EntityFramework.csproj` line 52 |
| Persistence PreBuild target (Bug 1) | `OpenMU/src/Persistence/MUnique.OpenMU.Persistence.csproj` line 45 |
| IP resolver parser (Bug 2) | `OpenMU/src/Network/IpAddressResolverFactory.cs` |
| Error source (Bug 2) | `OpenMU/src/Network/ConfigurableIpResolver.cs` line 70 |
| Bug 3 migration files (patched) | `Migrations/20260404225637_AddExcellentItemDropLevelDelta.cs`, `Migrations/20260405170905_UpdateDaybreakWeaponDimensions.cs` |
| Docker path (not used) | `OpenMU/deploy/all-in-one/docker-compose.yml` |

---

## Credentials & connection info (LOCAL DEV ONLY — do not reuse in production)

### PostgreSQL (installed by this session)

| Field | Value |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Superuser | `postgres` |
| Superuser password | `admin` |
| Service name | `postgresql-x64-17` |
| Service start type | `Automatic` |
| Install path | `C:\Program Files\PostgreSQL\17\` |
| `psql.exe` | `C:\Program Files\PostgreSQL\17\bin\psql.exe` |
| `pg_dump.exe` | `C:\Program Files\PostgreSQL\17\bin\pg_dump.exe` |
| Version | `17.9` |

### OpenMU application database

| Field | Value |
|---|---|
| Database | `openmu` |
| Owner | `postgres` |
| Schema | `config` (and others) |

The server auto-creates these additional role logins on first launch (password = username):

| Role | Password | Used by |
|---|---|---|
| `config` | `config` | `ConfigurationContext` (select config schema only) |
| `account` | `account` | `AccountContext`, `TradeContext` |
| `friend` | `friend` | `FriendContext` |
| `guild` | `guild` | `GuildContext` |

Source: `src/Persistence/EntityFramework/ConnectionSettings.xml`. To rotate these passwords, edit that XML file and run the server once with `-reinit` (or `DROP ROLE` + restart).

### Admin panel

- **Manual-run path (this setup):** admin panel is reachable at `http://localhost/` with **no auth** by default.
- **Docker `deploy/all-in-one` path (not used here):** goes through nginx basic-auth, default `admin` / `openmu`.

### Baked-in test game accounts

From `OpenMU/QuickStart.md` lines 131–145. Password always equals the username.

| Username | Level / notes |
|---|---|
| `test0` – `test9` | levels 1, 10, 20, …, 90 |
| `test300` | level 300 |
| `test400` | level 400, master characters |
| `testgm` | game master |
| `testgm2` | game master + summoner + rage fighter |
| `testunlock` | no characters, all classes unlocked |
| `quest1`, `quest2`, `quest3` | quests at levels 150, 220, 400 |
| `ancient` | level 330, ancient sets |
| `socket` | level 380, socket sets |

### Client

- **Version:** Season 6 (user-supplied).
- **Launcher used:** `MUnique.OpenMU.ClientLauncher v0.9.6`, download URL: `https://github.com/MUnique/OpenMU/releases/download/v0.9.0/MUnique.OpenMU.ClientLauncher_0.9.6.zip`.
- **Launcher config:** Server IP = `127.127.127.127`, Port = `44405`, Client path = the folder containing `Main.exe`.
- **Window mode:** the Webzen client reads `HKCU:\SOFTWARE\WebZen\Mu\Config\WindowMode` (DWORD, 0=fullscreen, 1=windowed) on every launch. Currently set to `1` for this user. Either edit the registry directly (`Set-ItemProperty -Path 'HKCU:\SOFTWARE\WebZen\Mu\Config' -Name WindowMode -Value 1 -Type DWord`) or use the launcher's "Settings" dialog (`MainForm.cs:137-149` → `ClientSettingsDialog`).

### Custom account & character (created on 2026-04-26)

| Account | Password | State | Char | Class | Notes |
|---|---|---|---|---|---|
| `edwin` | `edwin` | `GameMaster` (=2) | `6GOD` | Dark Knight | Created via admin panel modal. Character created via in-game launcher. CharacterStatus on 6GOD is still 0 (Normal) — to use slash-commands per `GMchat.md`, run `UPDATE data."Character" SET "CharacterStatus" = 32 WHERE "Name" = '6GOD';` |

---

## Open questions / things to investigate later

- [ ] Does the PowerShell argument-quoting workaround (`"-resolveIP:loopback"`) actually work? Not tested — env var was used instead.
- [ ] Do the source-generator pre-build targets produce code that gets committed, or is it always regenerated? (Affects whether a fresh clone on another machine needs the two-step build or a clean git pull is enough.)
- [ ] What does the `Web/ItemEditor` project expose? Spotted during build, not yet explored.
- [ ] The three "orphan" migrations (no `.Designer.cs`) — is there a repo convention where Designer files are git-ignored and regenerated? If so, the `[Migration]` attributes should probably be enforced inline on every future migration by a code-review rule. Upstream bug candidate.
- [ ] `OpenMU/deploy/distributed/` is marked **broken and unsupported** in `OpenMU/deploy/README.md` line 60 — skip unless we want to fix it.
- [ ] Security for Phase D: admin panel currently has NO auth on the manual-run path. Before exposing publicly, either put it behind nginx basic-auth (like the Docker stack does) or add `-adminpanel:disabled` and administer via local-only SSH tunnel.
- [ ] **EF migration history is missing** (`config."__EFMigrationsHistory"` doesn't exist) because the first Phase B init hit the `EnsureCreated` fallback path. Schema is correct *now*, but if upstream ships a future migration, `MigrateAsync()` may not detect that none have been applied. Either reinit cleanly, or manually populate the history table with the IDs of every migration in `Migrations/`. Worth resolving before Phase D.
- [ ] Account.State = 2 = `GameMaster` on the account (set during admin-panel modal) does NOT automatically promote characters created on that account — character `6GOD` was created with `CharacterStatus = 0` despite the parent account being GM. The two are independent fields. Worth reading `src/GameLogic/PlayerActions/Character/CreateCharacterAction.cs` to see why and whether it's intentional.
- [ ] `ClientLauncher/ClientSettings.cs` uses `RegistryView.Registry32` but on this machine the values landed in the non-redirected `HKCU:\SOFTWARE\WebZen\Mu\Config`, not `HKCU:\SOFTWARE\WOW6432Node\WebZen\Mu\Config`. Worth confirming what governs this — likely the bitness of the launcher process, since on 64-bit Windows registry redirection only kicks in for 32-bit processes. The launcher's TFM might be `net10.0-windows` not `net10.0-windows-x86`, so it's a 64-bit process and writes go straight to the unredirected key.
- [ ] **3-letter character names**: server regex (`^[a-zA-Z0-9]{3,10}$`) and packet wire format both allow 3 chars, but the Webzen `Main.exe` UI hardcodes a 4-char minimum. Either hex-edit `Main.exe` or use the open-source MuMain client (port 44406). Punted for now.
