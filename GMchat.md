# OpenMU — GM Chat Command Reference

Compiled from source:
- `src/GameLogic/PlugIns/ChatCommands/*.cs` (all 60 command plug-ins)
- `src/DataModel/Entities/Character.cs` (`CharacterStatus` enum)
- `src/GameLogic/PlugIns/ChatCommands/IChatCommandPlugIn.cs` (permission model)

All chat commands are **plug-ins** registered under the "Chat commands" extension point. They're dispatched from the in-game chat bar whenever a message starts with `/`.

---

## 1. How to become a GM

There are two paths. Both rely on the single `CharacterStatus` field on a `Character` row.

### Path A — Use the built-in GM accounts (fastest)

The Season 6 data initializer seeds these accounts automatically:

| Login | Password | Characters |
|---|---|---|
| `testgm`  | `testgm`  | testgmDk, testgmDl, testgmDw, testgmElf, testgmMg  (all 5 classes at `CharacterStatus = 32 GameMaster`) |
| `testgm2` | `testgm2` | testgm2Rf, testgm2Sum  (Rage Fighter + Summoner, both GM) |

Just log in with these and you get GM on every character.

### Path B — Grant GM to any existing character

1. Open the admin panel → **Accounts**.
2. Search/filter to your account → click **Edit**.
3. In the form, find the **Characters** collection → edit your character.
4. Field **Character Status** → change from `Normal` to `GameMaster` → **Save**.
5. If the character is logged in, disconnect and reconnect for the change to take effect.

**SQL equivalent** (skips the UI):
```powershell
$env:PGPASSWORD = "admin"
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d openmu -c "UPDATE data.\"Character\" SET \"CharacterStatus\" = 32 WHERE \"Name\" = 'YourCharName';"
```

### CharacterStatus enum (for reference)

From `src/DataModel/Entities/Character.cs:55-71`:

| Value | Name | Meaning |
|---|---|---|
| 0  | Normal     | Regular player |
| 1  | Banned     | Can't log in |
| 32 | GameMaster | Can use GM commands, shows MU logo above head |

---

## 2. Full command catalog

Legend:
- `[GM]` = requires `CharacterStatus = GameMaster`
- `[Any]` = any player (including `Normal`) can run it
- `[off]` = plug-in is `IDisabledByDefault`. Turn it on in admin panel → Game Configuration → **Plug-Ins** before it responds.

### 2.1 Utility & help

| Command | Perm | Purpose |
|---|---|---|
| `/list`  | [Any]      | Lists every enabled command on this server |
| `/help <cmd>` | [Any] | Shows syntax + description for one command |
| `/language <lang>` | [Any] | Change your client's message language |

### 2.2 Movement

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/move <warpname>` | [Any] | `/move Devias` | Warps self via the **Warp List** (same destinations as the NPC). Case-insensitive partial match. |
| `/move <name> <warp>` | [GM] | `/move PlayerX Lorencia` | Warps another player to a warp destination. |
| `/teleport <x> <y>` | [GM] | `/teleport 140 120` | Teleport self to arbitrary coordinates on the current map. |

### 2.3 Item / inventory / money

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/item <grp> <num> [lvl] [exc] [opt] [luck] [anc] [skill] [ancBonusLvl]` | [GM] | `/item 0 13 10 9 1 1` | Drops an item at your feet. See §3 for the full argument spec. |
| `/clearinv` | [off] | `/clearinv` | Delete every item in your inventory. |
| `/openware` | [off] | `/openware` | Open the warehouse from any location (skips NPC). |
| `/npc` | [off] | `/npc <id>` | Open the NPC dialog/store identified by `id`. |
| `/setmoney <amount> [char]` | [off] | `/setmoney 1000000000` | Set zen to exact amount. Optional character name to target a different character. |
| `/getmoney [char]` | [off] | `/getmoney` | Read zen balance. |

### 2.4 Stats / level / resets

All in this group are `[off]` (disabled by default).

| Command | Syntax | Notes |
|---|---|---|
| `/add <stat> <points>` | `/add str 500` | Generic stat adder. Valid: `str agi vit ene cmd`. |
| `/addstr <points>`, `/addagi`, `/addvit`, `/addene`, `/addcmd` | `/addstr 500` | Dedicated shortcuts (each is a separate plug-in — enable the ones you want). |
| `/set <stat> <value>` | `/set str 1000` | Set a stat directly instead of adding to it. |
| `/get <stat> [char]` | `/get str` | Read current stat value. |
| `/setlevel <lvl> [char]` | `/setlevel 400` | Overwrite character level. |
| `/getlevel [char]` | `/getlevel` | Read character level. |
| `/setleveluppoints <n> [char]` | `/setleveluppoints 9999` | Overwrite unspent stat points. |
| `/getleveluppoints [char]` | | |
| `/setmasterlevel <mlvl> [char]` | `/setmasterlevel 200` | Overwrite master level (post-400 grind). |
| `/getmasterlevel [char]` | | |
| `/setmasterleveluppoints <n> [char]` | | |
| `/getmasterleveluppoints [char]` | | |
| `/setresets <n> [char]` | `/setresets 10` | Overwrite reset count. |
| `/getresets [char]` | | |

### 2.5 Monsters / NPCs / world edit

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/createmonster <id>` | [GM] | `/createmonster 2` | Spawn a monster adjacent to you. IDs are `MonsterDefinition.Number`. |
| `/walkmonster <id>` | [GM] | `/walkmonster <instanceId>` | Make a spawned monster walk around. |
| `/movemonster <id> <x> <y>` | [GM] | | Move a spawned monster to coords. |
| `/removenpc <id>` | [GM] | | Despawn an NPC/monster by instance id. |
| `/showids` | [GM] | | Display all visible monster/NPC instance ids as debug labels. |

### 2.6 Players / moderation

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/online` | [GM] | `/online` | List connected players + their maps. |
| `/charinfo <name>` | [GM] | | Inspect a character's stats/inventory from chat. |
| `/disconnect <name>` | [GM] | | Kick a player (their connection is dropped). |
| `/banacc <account>` | [GM] | | Ban an account (login blocked). |
| `/unbanacc <account>` | [GM] | | |
| `/banchar <name>` | [GM] | | Ban a single character, not the whole account. |
| `/unbanchar <name>` | [GM] | | |
| `/chatban <name>` | [GM] | | Mute a character in chat. |
| `/chatunban <name>` | [GM] | | |
| `/track <name>` / `/trace <name>` | [GM] | | See where a player currently is / follow their movement. |
| `/pk <name>` | [GM] | | Toggle a player's PK flag manually. |
| `/pkclear <name>` | [GM] | | Clear PK penalty on a player. |
| `/hide` / `/unhide` | [GM] | | Toggle GM invisibility. |
| `/skin <monsterId>` | [GM] | | Disguise as a monster model. |

### 2.7 Guilds

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/war <guild>` | [Any] | `/war Rivals` | Challenge another guild to guild war. |
| `/battlesoccer <guild>` | [Any] | | Challenge another guild to battle-soccer. |
| `/guildmove <guild> <warp>` | [GM] | | Warp an entire guild to a destination. |
| `/guilddisconnect <guild>` | [GM] | | Kick every online member of a guild. |

### 2.8 Events / effects / announcements

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/post <text>` | [Any] | `/post hey everyone` | Send a **blue** chat message to all players with your character name prefixed. Anyone can use this. |
| `/goldnotice <text>` | [GM] | | Send a **golden center-screen** banner to all players. GM-only. |
| `/startbc` | [GM] | | Force-start Blood Castle event. |
| `/startcc` | [GM] | | Force-start Chaos Castle event. |
| `/startds` | [GM] | | Force-start Devil Square event. |
| `/fireworks` | [GM] | `/fireworks 150 130` | Visual fireworks at given coords. |
| `/xmasfireworks` | [GM] | | Christmas fireworks variant. |

### 2.9 Misc

| Command | Perm | Syntax | Notes |
|---|---|---|---|
| `/offlevel` | [Any] | | Toggle **offline leveling** — your char keeps gaining XP after you log out. |

---

## 3. `/item` syntax in full

The most valuable GM command. Source: `src/GameLogic/PlugIns/ChatCommands/ItemChatCommandPlugIn.cs` + `Arguments/ItemChatCommandArgs.cs`.

```
/item <group> <number> [level] [excellentMask] [opt] [luck] [ancient] [skill] [ancientBonusLevel]
```

| Arg | Type | Meaning |
|---|---|---|
| `group`  | byte  | Item group. Canonical values from `src/Persistence/Initialization/Items/ItemGroups.cs`: 0 = swords, 1 = axes, 2 = scepters, 3 = spears, 4 = bows, 5 = staves, **6 = shields**, **7 = helms**, **8 = armors (chest)**, **9 = pants**, **10 = gloves**, **11 = boots**, 12 = orbs, 13 = pets/rings/pendants/misc, 14 = pots/misc, 15 = scrolls. See `ItemDefinition.Group`. |
| `number` | short | Item number within the group. Every item's `(group, number)` pair is visible in admin panel → Game Configuration → Items. |
| `level`  | byte  | +0 through +15 (capped by item's `MaximumItemLevel`). |
| `excellentMask` | byte | Bitmask of excellent options. Each bit = one excellent option (e.g. 1 = ExcellentOption #1, 2 = #2, 3 = both, 15 = four options). |
| `opt`    | byte  | Main bonus option level (0-7 for most items; dinorant uses it as a bitmask). |
| `luck`   | bool  | `1` adds the Luck option. |
| `ancient`| short | Ancient set discriminator (>0 turns the item into part of a named ancient set). |
| `skill`  | bool  | `1` adds the item's skill if it has one. |
| `ancientBonusLevel` | byte | Level of the ancient set bonus, if ancient. |

### Practical examples

```
/item 0 1 9                   -> Short Sword +9
/item 0 13 13 15 9 1 0 1      -> Lightning Sword +13, 4 excellent options, +9 damage, +Luck, has skill
/item 8 0 13 0 9 1            -> Bronze Armor (chest) +13 +Luck +Option9 for Dark Knight
/item 7 0 13 0 9 1            -> Bronze Helm +13 +Luck +Option9
/item 9 0 13 0 9 1            -> Bronze Pants +13 +Luck +Option9
/item 10 0 13 0 9 1           -> Bronze Gloves +13 +Luck +Option9
/item 11 0 13 0 9 1           -> Bronze Boots +13 +Luck +Option9
/item 6 0 13                  -> Small Shield +13
/item 14 3 0                  -> Dinorant pet (group 13 in some seeds; check item editor)
/item 14 4 0                  -> Fenrir pet
```

> **Off-by-one warning:** earlier revisions of this doc had the armor groups shifted by one (shield=7, helm=8, etc.). The values above match the `ItemGroups` enum in source. If a command says "item not found", verify the group/number in Admin Panel → Game Configuration → Items.

**Tip:** To find the `(group, number)` of any item, open the admin panel → **Game Configuration → Items** → search by name → the URL of the edit page contains the item's id and the form shows Group + Number as separate fields.

---

## 4. Enabling the disabled-by-default commands

22 commands ship disabled because they're powerful / easily abusable. To turn them on:

1. Admin panel → left nav → **Game Configuration** (cog) → click to expand.
2. Click **Plug-Ins** (puzzle piece, bottom of the dropdown).
3. The plug-in list is grouped by extension point. Scroll or filter to **"Chat commands"**.
4. For each plug-in you want, click **Edit** and toggle **Enabled** on.
5. **No restart needed *if* you toggle via the admin panel UI** — it mutates the tracked EF entity, which fires `PlugInConfiguration.PropertyChanged` → `PlugInManager.OnConfigurationChanged` → activate/deactivate live. Verified in `src/PlugIns/PlugInManager.cs:445-466`.

> **Caveat for SQL toggles:** if you flip `IsActive` directly in `config."PlugInConfiguration"` via psql, the in-memory `PlugInConfiguration` object stays stale (no `PropertyChanged` event fires). You **must restart the server** for SQL-based toggles to take effect. Take a backup with `./scripts/windows/db-backup.ps1`, stop the server, run the UPDATE, start the server.

Disabled-by-default commands (the full list, grep'd from `IDisabledByDefault` in the repo):

```
/add, /addstr, /addagi, /addvit, /addene, /addcmd
/set, /setlevel, /setleveluppoints
/setmasterlevel, /setmasterleveluppoints
/setmoney, /setresets
/get, /getlevel, /getleveluppoints
/getmasterlevel, /getmasterleveluppoints
/getmoney, /getresets
/clearinv, /openware, /npc
```

---

## 5. Quickstart cheat-sheet (after logging in as `testgm`)

Paste these into the in-game chat bar to prove GM works:

```
/post Hello world                    ->  blue chat msg to all players
/goldnotice Big event in 5 min        ->  golden banner, center screen
/teleport 180 125                     ->  warp to that coord on your map
/createmonster 2                      ->  spawn a Bull Fighter next to you
/item 0 13 13 15 9 1 0 1              ->  OP Lightning Sword at your feet
/move Devias                          ->  warp to Devias
/online                               ->  list every connected player
/hide                                 ->  become invisible
```

---

## 6. Gearing a low-stat Dark Knight (case study: `6GOD`)

This section is a worked example for kitting out a freshly-promoted GM character that started with default stats. `6GOD` is the project's own custom DK; the same logic applies to any low-level character.

### 6.1 Stat budget reality check

Default Dark Knight base stats (from `src/Persistence/Initialization/CharacterClasses/ClassDarkKnight.cs`):

| Stat | Base | + 30 unspent points (worst-case all-in-one) |
|---|---|---|
| Strength | 28 | 58 |
| Agility  | 20 | 50 |
| Vitality | 25 | 55 |
| Energy   | 10 | 40 |

**Lowest STR requirement on any DK-eligible armor piece in `Armors.cs` is 80** (Bronze Helm/Armor/Pants/Gloves/Boots, also Leather variants). Lowest shield is Small Shield at **70 STR**. Lowest DK weapon is **Small Axe at 18 STR / 0 AGI** — that's the *only* item the character can wear at default stats + 30 points.

> **Rule of thumb:** if the stat budget is < 80 STR, no armor piece will equip. Bump stats first (§6.2), then gear (§6.3 / §6.4).

### 6.2 Two ways to bump stats so armor actually equips

#### Option A — Enable `/add` chat commands (clean, in-game)

1. Admin panel → **Game Configuration → Plug-Ins** (see §4).
2. Filter to "Chat commands" → enable **`AddChatCommand`** (and optionally `AddStrengthChatCommand` etc.).
3. In-game type:

```
/add str 200 6GOD
/add agi 50 6GOD
/add vit 50 6GOD
```

Numbers above clear every armor requirement up to and including Dark Phoenix.

#### Option B — Direct SQL (fastest, dirtiest)

Stop the server, then:

```sql
UPDATE data."Character"
SET    "Strength" = 250,
       "Agility"  = 80,
       "Vitality" = 80,
       "Energy"   = 30
WHERE  "Name" = '6GOD';
```

Restart, log in. Take a snapshot first with `./scripts/windows/db-backup.ps1`.

### 6.3 Tier 1 — Bronze full set (str 80, the cheapest fit)

Useful as a sanity check before chasing endgame:

```
/item 7  0 15 15 7 1   -> Bronze Helm   +15, 4 exc, +7, +Luck
/item 8  0 15 15 7 1   -> Bronze Armor  +15, 4 exc, +7, +Luck
/item 9  0 15 15 7 1   -> Bronze Pants  +15, 4 exc, +7, +Luck
/item 10 0 15 15 7 1   -> Bronze Gloves +15, 4 exc, +7, +Luck
/item 11 0 15 15 7 1   -> Bronze Boots  +15, 4 exc, +7, +Luck
/item 6  0 15 15 7 1   -> Small Shield  +15, 4 exc, +7, +Luck (off-hand)
```

### 6.4 Tier 2 — Dark Phoenix endgame DK-exclusive set (item number 17)

The iconic Season 6 DK-only set (`darkKnightClassLevel=2` in `Armors.cs`, no other class can equip). Requires STR ≈ 198–214, AGI ≈ 60–65 — that's why §6.2 happens first.

```
/item 7  17 15 15 7 1   -> Dark Phoenix Helm   +15, 4 exc, +7, +Luck
/item 8  17 15 15 7 1   -> Dark Phoenix Armor  +15, 4 exc, +7, +Luck
/item 9  17 15 15 7 1   -> Dark Phoenix Pants  +15, 4 exc, +7, +Luck
/item 10 17 15 15 7 1   -> Dark Phoenix Gloves +15, 4 exc, +7, +Luck
/item 11 17 15 15 7 1   -> Dark Phoenix Boots  +15, 4 exc, +7, +Luck
```

### 6.5 Off-hand & weapon picks for DK

```
/item 6 17 15 15 7 1    -> Crimson Glory shield +15 (DK-exclusive, group 6 num 17)
/item 0 8 15 15 7 1     -> Bone Blade +15, 4 exc, +7, +Luck (the user's earlier pick)
/item 1 0 15 15 7 1     -> Small Axe +15 (the only weapon equippable at default DK stats)
```

### 6.6 Other DK-exclusive set numbers (for variety)

All use the same `(group, number)` pattern across the 5 armor slots (helm 7 / armor 8 / pants 9 / gloves 10 / boots 11). Pick one number, fire 5 `/item` commands.

| Set name | Item # | STR req (approx) | Notes |
|---|---|---|---|
| Bronze         | 0  | 80   | DK + DL |
| Dragon         | 1  | 120  | DK + DL |
| Leather        | 5  | 80   | DK + Elf + MG + RF |
| Scale          | 6  | 110  | DK + Elf + MG + RF |
| Brass          | 8  | 100  | DK + MG + RF |
| Plate          | 9  | 130  | DK + MG + RF |
| Black Dragon   | 16 | 170  | DK only |
| **Dark Phoenix** | **17** | **214** | **DK only — endgame canonical** |
| Great Dragon   | 21 | 200  | DK only (knightClass=2) |
| Ashcrow        | 34 | 160  | DK only |
| Titan          | 45 | 222  | DK only |
| Brave          | 46 | 74 STR / 162 AGI | DK only — AGI build |
| Dragon Knight  | 29 | 170 + level 380 | DK only, hardest gate |

> Source-of-truth for every requirement: `src/Persistence/Initialization/VersionSeasonSix/Items/Armors.cs`. The arg layout for `CreateArmor`/`CreateGloves`/`CreateBoots` is `number, name, dropLevel, defense, durability, levelReq, strReq, agiReq, eneReq, vitReq, ldrReq, dw, dk, elf, mg, dl, sm, rf` (with slight variations per signature — see `src/Persistence/Initialization/Items/ArmorInitializerBase.cs`).

---

## 7. File / source references

| What | Where |
|---|---|
| Permission model | `src/GameLogic/PlugIns/ChatCommands/IChatCommandPlugIn.cs` |
| `CharacterStatus` enum | `src/DataModel/Entities/Character.cs:55-71` |
| `/item` implementation | `src/GameLogic/PlugIns/ChatCommands/ItemChatCommandPlugIn.cs` |
| All other commands | `src/GameLogic/PlugIns/ChatCommands/*.cs` (one file per command) |
| Warp-list destinations for `/move` | admin panel → Game Configuration → Warp List |
| `IDisabledByDefault` marker | `src/PlugIns/IDisabledByDefault.cs` |

