; ============================================================
; CT-Highlighter for SeraphIRC (standard mIRC scripting)
; Port of Delrynn/CT-Highlighter (AdiIRC) - works on top of casetracker.mrc
; ============================================================
; Messages from clients of open cases are shown as
;     #<case> <Nick> message
; and the whole line is coloured by case number.
;
; Needs casetracker.mrc (hash table "cases", entry = nick$platform$mode$language).
; Never sends anything to IRC, it only changes how lines are displayed.
;
; Commands:
;   /cthl on | off     Enable / disable highlighting
;   /cthl dark | light Colour set for dark or light window backgrounds (default: dark)
;   /cthl test         Show a sample line for every colour
;   /cthl              Show current status
;
; Colours cycle through 9 entries by case number (case 0-8 = entry 1-9, case 9 = entry 1 again, ...).
; Change the palettes in the aliases CTHL_PaletteDark / CTHL_PaletteLight below (mIRC colour numbers 0-15).
; Tracked channels follow %spmode like casetracker.mrc (1/unset = #fuelrats,#ratchat; 2 = drill channels).
; ============================================================


; ---------- Settings ----------

alias -l CTHL_PaletteDark { return 8 9 11 12 13 7 4 10 15 }
alias -l CTHL_PaletteLight { return 2 3 4 5 6 7 10 12 14 }

alias -l CTHL_Color {
  ; $1 = case number. Returns a two digit colour number
  var %idx = $calc($iif($1 isnum,$1,0) % 9) + 1
  var %pal = $iif(%cthl_theme == light,$CTHL_PaletteLight,$CTHL_PaletteDark)
  return $base($gettok(%pal,%idx,32),10,10,2)
}


; ---------- Helpers ----------

alias -l CTHL_Case {
  ; $1 = nick. Returns the case number of that client, or nothing.
  ; If the same nick is on several cases, the highest case number wins.
  if (%cthl_off == 1) return
  var %n = $hget(cases,0).item
  if (!%n) return
  var %i = 1, %best
  while (%i <= %n) {
    if ($gettok($hget(cases,%i).data,1,36) == $1) {
      var %case = $hget(cases,%i).item
      if ((%best == $null) || (%case > %best)) var %best = %case
    }
    inc %i
  }
  return %best
}

alias -l CTHL_Echo {
  ; $1 = channel, $2 = nick, $3 = case number, $4 = text|action, $5- = message
  var %c = $CTHL_Color($3)
  var %who = $nick($1,$2).pnick
  if (%who == $null) var %who = $2
  var %body = $strip($5-,c)
  if ($4 == action) echo -ti2 $1 $chr(3) $+ %c $+ $chr(35) $+ $3 * %who %body
  else echo -ti2 $1 $chr(3) $+ %c $+ $chr(35) $+ $3 < $+ %who $+ > %body
}


; ---------- Command ----------

alias cthl {
  if ($1 == on) { unset %cthl_off | echo -ag CT-Highlighter enabled }
  elseif ($1 == off) { set %cthl_off 1 | echo -ag CT-Highlighter disabled }
  elseif ($1 == dark) { set %cthl_theme dark | echo -ag CT-Highlighter: colour set for dark backgrounds }
  elseif ($1 == light) { set %cthl_theme light | echo -ag CT-Highlighter: colour set for light backgrounds }
  elseif ($1 == test) {
    var %i = 0
    while (%i < 9) {
      echo -ag $chr(3) $+ $CTHL_Color(%i) $+ $chr(35) $+ %i < $+ Test_Client $+ > sample line for case %i
      inc %i
    }
  }
  else echo -ag CT-Highlighter is $iif(%cthl_off == 1,OFF,ON) ( $+ $iif(%cthl_theme == light,light,dark) colour set). Usage: /cthl on|off|dark|light|test
}


; ---------- Events ----------
; The ^ prefix lets the script replace mIRC's normal display. For a case client the line
; is echoed in colour and haltdef suppresses the default line. All other lines are left
; alone (no haltdef), so mIRC shows them as usual.

on ^*:TEXT:*:#fuelrats,#ratchat:{
  if (%spmode != 2) {
    var %case = $CTHL_Case($nick)
    if (%case != $null) {
      CTHL_Echo $chan $nick %case text $1-
      haltdef
    }
  }
}

on ^*:TEXT:*:#beyond,#horizons,#odyssey,#drillrats,#drillrats2,#drillrats3:{
  if (%spmode == 2) {
    var %case = $CTHL_Case($nick)
    if (%case != $null) {
      CTHL_Echo $chan $nick %case text $1-
      haltdef
    }
  }
}

on ^*:ACTION:*:#fuelrats,#ratchat:{
  if (%spmode != 2) {
    var %case = $CTHL_Case($nick)
    if (%case != $null) {
      CTHL_Echo $chan $nick %case action $1-
      haltdef
    }
  }
}

on ^*:ACTION:*:#beyond,#horizons,#odyssey,#drillrats,#drillrats2,#drillrats3:{
  if (%spmode == 2) {
    var %case = $CTHL_Case($nick)
    if (%case != $null) {
      CTHL_Echo $chan $nick %case action $1-
      haltdef
    }
  }
}
