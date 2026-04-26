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
| `group`  | byte  | Item group (0 = swords, 1 = axes, 2 = scepters, 5 = staves, 7 = shields, 8 = helms, 9 = armors, 10 = pants, 11 = gloves, 12 = boots, 13 = wings/misc, 14 = pets, etc.). See `ItemDefinition.Group`. |
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
/item 9 0 13 0 9 1            -> Bronze Armor +13 +Luck +Option9 for Dark Knight
/item 14 3 0                  -> Dinorant pet
/item 14 4 0                  -> Fenrir pet
/item 12 8 13                 -> Crimson Glory Pants +13
```

**Tip:** To find the `(group, number)` of any item, open the admin panel → **Game Configuration → Items** → search by name → the URL of the edit page contains the item's id and the form shows Group + Number as separate fields.

---

## 4. Enabling the disabled-by-default commands

22 commands ship disabled because they're powerful / easily abusable. To turn them on:

1. Admin panel → left nav → **Game Configuration** (cog) → click to expand.
2. Click **Plug-Ins** (puzzle piece, bottom of the dropdown).
3. The plug-in list is grouped by extension point. Scroll or filter to **"Chat commands"**.
4. For each plug-in you want, click **Edit** and toggle **Enabled** on.
5. **No restart needed** — plug-in state is hot-reloaded (verified in source: plug-in manager observes DB changes).

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

## 6. File / source references

| What | Where |
|---|---|
| Permission model | `src/GameLogic/PlugIns/ChatCommands/IChatCommandPlugIn.cs` |
| `CharacterStatus` enum | `src/DataModel/Entities/Character.cs:55-71` |
| `/item` implementation | `src/GameLogic/PlugIns/ChatCommands/ItemChatCommandPlugIn.cs` |
| All other commands | `src/GameLogic/PlugIns/ChatCommands/*.cs` (one file per command) |
| Warp-list destinations for `/move` | admin panel → Game Configuration → Warp List |
| `IDisabledByDefault` marker | `src/PlugIns/IDisabledByDefault.cs` |

