# Casetracker

Casetracker is a SeraphIRC script for Fuel Rats dispatchers. It watches MechaSqueak (or DrillSqueak) and remembers the details of every open case: client nick, platform, game mode and language. It updates them when Mecha reports a change and removes the case when it is closed or marked for deletion.

It is written in standard mIRC scripting and based on the original [fuelrats-casetracker](https://github.com/LittleFool/fuelrats-casetracker) by LittleFool, adapted from AdiIRC for SeraphIRC.

**The script never sends anything to IRC.** It only listens and prints to your own windows. The DispatchAliases scripts use the stored cases so that you can type a case number instead of the client's nick.

## Installation

1. Copy `casetracker.mrc` into your SeraphIRC scripts folder, e.g. `scripts\SeraphIRC\Casetracker\`.
2. Load it in SeraphIRC as a **remote** script.
3. Type `/cttest` to check it works. You should see:
   ```
   new client 999 => Test_Client - speaking en on PC (Odyssey)
   Casetracker test OK - remove with /delcase 999
   ```
   Then remove the test case with `/delcase 999`.

## How it works

When MechaSqueak posts a RATSIGNAL in `#fuelrats` or `#ratchat`, a line appears in your status window:

```
new client 4 => Some_Cmdr - speaking en on PC (Odyssey)
```

Casetracker then follows Mecha's messages for that case:

| Mecha reports                                      | Casetracker does                                          |
| -------------------------------------------------- | --------------------------------------------------------- |
| Client nickname changed (`!nick`, nick change, rejoin under another name) | Updates the nick                         |
| Language changed                                   | Updates the language                                      |
| Platform changed                                   | Updates the platform; on Xbox/PlayStation also sets mode to Legacy |
| Case marked as Legacy / Horizons / Odyssey         | Updates the mode                                          |
| Case closed (`!close`)                             | Removes the case                                          |
| Case added to the deletion list (`!md`)            | Removes the case                                          |
| Client trashed for using a banned VPN              | Removes the case and prints a warning                     |

Cases are only kept in memory. They are lost when SeraphIRC closes, and cases that were signalled before you started SeraphIRC are not known. Add those by hand with `/addcase`.

### Dispatch mode and drill mode

Casetracker follows the `%spmode` setting from the DispatchAliases scripts (toggled with `/drillmode`):

- **Dispatch mode** (`%spmode` = 1 or not set): tracks MechaSqueak in `#fuelrats` and `#ratchat`.
- **Drill mode** (`%spmode` = 2): tracks DrillSqueak in `#beyond`, `#horizons`, `#odyssey`, `#drillrats`, `#drillrats2` and `#drillrats3`.

## Commands

| Command | What it does |
| ------- | ------------ |
| `/addcase <case#> <client> <PC\|xb\|ps> <leg\|hor\|ody> <lang>` | Add a case by hand, e.g. `/addcase 7 Some_Cmdr xb leg de` |
| `/delcase <case#>` | Delete one case |
| `/getcase <case#>` | Show one case |
| `/listcases` | Show all tracked cases, sorted by case number |
| `/clearcases` | Delete all cases |
| `/cttest [case#]` | Self-test: runs a sample RATSIGNAL through the script (default case 999). Nothing is sent. |
| `/ctdebug` | Turn debug logging on or off |
| `/ctdebug clear` | Delete the debug log |

## Debug log

If a case is tracked wrongly or not at all, turn on `/ctdebug` and leave it on while cases come in. Every bot message in the tracked channels is written to `casetracker_debug.log`, next to the script, with what Casetracker did with it:

```
2026-09-30 21:15:40 RECV #fuelrats <MechaSqueak[BOT]> RATSIGNAL Case #4 PC ODY – CMDR ...
2026-09-30 21:15:40 -> MATCH signal: case=4 platform=PC modeTag=ODY cmdr=Some Cmdr lang=en nick=Some_Cmdr
2026-09-30 21:15:40 -> STORED case 4 => Some_Cmdr - speaking en on PC (Odyssey)
2026-09-30 21:17:12 -> CHANGED case 4 platform: PC => Xbox - now: Some_Cmdr - speaking en on Xbox (Odyssey)
2026-09-30 21:40:05 -> MATCH close: case 4 removed
```

Lines worth a closer look:

- **`NO MATCH (check this line …)`**: the message mentions a signal or case number but no rule matched. Mecha's wording has probably changed and the script needs updating. The `RECV` line above it shows the exact text.
- **`IGNORED: case N is not tracked`**: an update arrived for a case Casetracker doesn't know, usually because it was signalled before SeraphIRC started.
- **`NOTE case N already existed …, overwriting`**: a case number was reused while the old case was still stored, e.g. after a missed close.
- **`IGNORED (drill mode active)`** / **`IGNORED (dispatch mode active)`**: the message came in while `%spmode` was set to the other mode.

The setting survives restarts. Turn it off with `/ctdebug` when you no longer need it.

## For script authors

These aliases can be called from other scripts. The DispatchAliases scripts depend on them.

| Alias | Returns / does |
| ----- | -------------- |
| `$getClientNames(<words>)` | Looks at the first three words: known case numbers become the client's nick, unknown case numbers are dropped, other words are kept. If no known case number was found, it returns the input unchanged. |
| `$getMode(<case#>)` | `Legacy`, `Horizons` or `Odyssey` |
| `$getLanguage(<case#>)` | Two-letter language code, e.g. `en` |
| `/changeTokenValue <case#> <nickname\|platform\|mode\|language> <value>` | Changes one field of a case |

`%caseTracker` is set to `$true` once the first case has been stored. Cases live in the hash table `cases`, one entry per case number, stored as `nick$platform$mode$language` (fields separated by `$chr(36)`).

## Credits

Based on the original work by **LittleFool**: [github.com/LittleFool/fuelrats-casetracker](https://github.com/LittleFool/fuelrats-casetracker). This version adapts it for SeraphIRC.
