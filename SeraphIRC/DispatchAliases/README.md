# Dispatch Aliases

Dispatch Aliases is a SeraphIRC script for Fuel Rats dispatchers: short commands that post the standard dispatch texts in the client's language. Type `/hello-de 4` and the German welcome text goes to the client of case 4, with their nick filled in.

It is written in standard mIRC scripting and adapted from the AdiIRC version.

## Requirements

**[Casetracker](../Casetracker/) must be loaded.** Dispatch Aliases gets the client's nick, language and game mode from it. Without Casetracker the commands show a warning and send nothing.

## Installation

1. Copy `dispatchaliases.mrc` into your SeraphIRC scripts folder, e.g. `scripts\SeraphIRC\DispatchAliases\`.
2. Load it in SeraphIRC as a **remote** script, next to `casetracker.mrc`.
3. Turn on dry-run (`/dadry`) and try a few commands before using it for real (see below).

## Try it safely first: dry-run

```
/dadry
```

While dry-run is on, **nothing is sent to IRC**. Every message is only shown in your own window:

```
[DRY-RUN -> #fuelrats] Welcome to the Fuel Rats, Test_Client. Please tell us once ...
[DRY-RUN -> #fuelrats] !wing 999
```

This covers everything the script sends, including `!close` to #ratchat and the timed code red sequence. Create a test case with Casetracker's `/cttest`, then try e.g. `/hello-a 999`, `/wing 999` or `/close 999 SomeRat`. Type `/dadry` again to go live. The setting survives restarts, and SeraphIRC reminds you at startup if dry-run is still on.

## How to use it

```
/<macro>          English
/<macro>-<lang>   a specific language, e.g. /hello-de, /wing-ru
/<macro>-a        the language Casetracker has stored for the case
```

The first argument is normally the **case number**: it is replaced with the client's nick. A nick instead of a number is used as it is. The messages always go to the channel or query window you typed the command in.

- **Legacy or Horizons/Odyssey versions are picked automatically.** Casetracker knows the case's game mode, so `/wing` becomes the Team text for Horizons/Odyssey clients and `/team` becomes the Wing text for Legacy. The same applies to `/crgo` / `/crgoody`, `/crvideo` / `/crvideoleg` and `/crinst` / `/crinstleg`.
- **Some macros also send the Mecha command:** `/wing`, `/team`, `/beacon`, `/sc` and `/open` post the text and then e.g. `!wing 4` (or `!wing-de 4`).
- **Unknown case numbers are refused.** If Casetracker doesn't know the case, you get `== Warning - Case 5 not found ==` and nothing is sent.

### Languages

`en`, `de`, `ru`, `es`, `fr`, `pt`, `zh`, `it`, `pl`, `cs`, `tr`, `hu`, `nl` (and `nb` for `/eng`). If a macro has no text in the chosen language, the English text is used.

### Macros

| Command | Text |
| ------- | ---- |
| `/hello <case>` | Welcome to the Fuel Rats … tell us once you've completed the instructions |
| `/eng-<lang> <case>` | Asks in the client's language whether they speak English (no plain `/eng`) |
| `/offq <case>` | How are these modules going? |
| `/sr <case>` | Disable Silent Running immediately |
| `/o2 <case>` | Do you see an "oxygen depleted" timer? |
| `/navsys <case>` | Give me the full system name from the navigation panel |
| `/open <case>` | Exit to main menu and log back in to Open play (+ `!open`) |
| `/wing <case>` | Invite your rats to a wing (+ `!wing`) |
| `/team <case>` | Invite your rats to a team (+ `!team`) |
| `/beacon <case>` | Enable your beacon (+ `!beacon`) |
| `/ls <case>` | Turn on Life Support immediately |
| `/sc <case>` | You're too close to a stellar body (+ `!sc`) |
| `/scenter <case>` | How to enter supercruise |
| `/scdrop <case>` | How to drop from supercruise |
| `/eta <case> <minutes>` | Your rat will be with you in about N minutes |
| `/db <case>` | Join #debrief for fuel tips |
| `/sorry <case>` | Sorry we couldn't get to you in time |
| `/close <case> <rat> [client]` | You should be receiving fuel now … + `!close <case> <rat>` |

**Code red:**

| Command | Text |
| ------- | ---- |
| `/crm <case>` | Stay logged out in the main menu until "GO GO GO" |
| `/mmconf <case>` | Confirm you're in the main menu |
| `/mmsys <case>` | Confirm your full system name from the main menu |
| `/cro2 <case>` | How much O2 did you have left? |
| `/crpos <case>` | Where in the system were you? |
| `/plan <case>` | I'll go through the rescue plan with you … only log in on "GO GO GO" |
| `/crinst <case>` | Code red instructions, followed by the timed sequence below |
| `/crvideo <case>` | Video on how to do it (Odyssey video; Legacy clients automatically get the Legacy one) |
| `/crinstend <case>` | Please read everything carefully and tell me if you can do it quickly |
| `/crgo <case> <rats…>` | GO GO GO! Login, beacon, invite your rats … (`<rats…>` fills in the rat names) |
| `/abort` | Stops a running `/crinst` sequence |

`/crinst` posts the instructions and then, on a timer, the wing and beacon commands, the video and the "read everything carefully" text (5 s, 7 s, 7 s, 5 s apart). For Legacy clients the beacon comes before the wing. Use `/abort` to stop it.

**Other:**

| Command | What it does |
| ------- | ------------ |
| `/csay <case> <text>` | Says `<text>` prefixed with the client's nick |
| `/drillmode` | Switches between dispatch mode (#fuelrats; `!close` goes to #ratchat) and drill & training mode (`!close` goes to the current channel) |
| `/dadry` | Dry-run on/off |

### Closing a case

```
/close 4 SomeRat
/close-de 4 SomeRat
/close 4 SomeRat Some_Cmdr     only needed if Casetracker doesn't know case 4
```

This posts the close text to the client and sends `!close 4 SomeRat` to #ratchat (in drill mode: to the current channel). Closing to the client's own nick is refused.

## For translators

All texts are in `load_translations` at the end of `dispatchaliases.mrc`, one line per macro and language:

```
hadd -m13 da_hello de Willkommen bei den Fuel Rats, &clientNames&. ...
```

Placeholders: `&clientNames&` (all client names), `&clientName&` (first client name), `&rats&` (rat names given to `/crgo`), `&eta&` (minutes given to `/eta`).

Don't use `$`, `%`, `|` or a lone `#` in texts, because mIRC would interpret them. A new language also needs its command lines (e.g. `alias hello-xx say_alias hello xx $$1-`) in the Commands section. After editing, reload the script and type `/load_translations`. The texts are kept in memory, so a reload alone doesn't pick up changes.

## Credits

Original Dispatch Aliases by **LittleFool**, reworked by **SrF1xx** and **Blauregen**. This version adapts it for SeraphIRC.
