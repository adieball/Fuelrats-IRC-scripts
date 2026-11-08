; ============================================================
; Casetracker - tracks Fuel Rats cases announced by MechaSqueak / DrillSqueak (standard mIRC scripting)
; Based on the original work by LittleFool: https://github.com/LittleFool/fuelrats-casetracker
; Adapted from the AdiIRC version (casetracker.ini) for SeraphIRC
; ============================================================
; Commands:
;   /addcase <case#> <client> <PC|xb|ps> <leg|hor|ody> <lang>   Add a case manually
;   /delcase <case#>        Delete a case
;   /getcase <case#>        Show a case
;   /listcases              Show all tracked cases
;   /clearcases             Delete all cases
;   /cttest [case#]         Self-test with a sample RATSIGNAL (nothing is sent)
;   /ctdebug [clear]        Toggle debug logging to casetracker_debug.log (or delete the log)
;
; Identifiers used by the DispatchAliases scripts (also usable as commands, then read $result):
;   $getClientNames(<args>)   Replaces case numbers (first 3 words) with client nicknames
;   $getMode(<case#>)         Legacy / Horizons / Odyssey
;   $getLanguage(<case#>)     Two letter language code
;   /changeTokenValue <case#> <nickname|platform|mode|language> <value>
;
; Cases are held in the hash table "cases" (memory only, lost on exit).
; Each entry is "nickname$platform$mode$language" (tokens separated by $chr(36)).
; Signals are tracked in #fuelrats/#ratchat when %spmode is 1 (or unset),
; and in the drill channels when %spmode is 2 (see /drillmode in DispatchAliases).


; ---------- Helpers ----------

alias -l CT_Describe {
  ; $1 = case number. Returns "nick - speaking lang on platform (mode)"
  var %tokens = $hget(cases,$1)
  return $gettok(%tokens,1,36) - speaking $gettok(%tokens,4,36) on $gettok(%tokens,2,36) ( $+ $gettok(%tokens,3,36) $+ )
}

alias -l CT_Store {
  ; $1 = case number, $2 = nickname, $3 = platform, $4 = mode, $5 = language
  ; Called as $CT_Store(...) so values containing spaces (e.g. "unknown platform") stay intact
  hadd -m10 cases $1 $+($2,$chr(36),$3,$chr(36),$4,$chr(36),$5)
  set %caseTracker $true
}

alias -l CT_SignalRegex {
  ; Kept in an alias because the pattern contains commas, which would break an inline $regex().
  ; F keeps empty groups in $regml(), so the group numbers stay fixed when the optional parts are missing.
  ; Groups: 1 case, 2 platform, 3 LEG/HOR/ODY, 4 CMDR name, 5 language, 6 IRC nick
  return /(?:RAT|DRILL)SIGNAL Case #(\d+) (PC|Xbox|Playstation|unknown platform)(?: )?(LEG|HOR|ODY)?(?: \(Code Red\))? – CMDR (.+?)(?: \(.*\))? – System: ".*"(?: ⚠️)? \(.+\) – Language: .+ \(([a-z]{2})(?:-\w{2,3}(?:-[a-z])?)?\)(?: – Nick: ([\w\[\]\^-{|}]+))?.?(?:\((?:ODY|HOR|LEG|XB|PS)_SIGNAL\))?.?/SF
}

alias -l CT_LogFile {
  return $scriptdir $+ casetracker_debug.log
}

alias -l CT_Log {
  ; Appends a timestamped line to the debug log (only while /ctdebug is on). Local file only.
  if (%CTDebug != $true) return
  write $qt($CT_LogFile) $asctime(yyyy-mm-dd HH:nn:ss) $strip($1-)
}

alias -l CT_Parse {
  ; $1 = echo switches for new cases, $2- = the bot's message
  var %switches = $1
  tokenize 32 $2-
  CT_Log RECV $iif($chan,$chan,(test)) < $+ $iif($nick,$nick,cttest) $+ > $1-

  var %re = $CT_SignalRegex
  if ($regex(signal, $1-, %re)) {
    var %caseNumber = $regml(signal,1)
    var %nickname = $regml(signal,6)
    if (%nickname == $null) var %nickname = $regml(signal,4)

    var %mode = Legacy
    if ($regml(signal,3) == ODY) var %mode = Odyssey
    elseif ($regml(signal,3) == HOR) var %mode = Horizons

    CT_Log -> MATCH signal: case= $+ %caseNumber platform= $+ $regml(signal,2) modeTag= $+ $regml(signal,3) cmdr= $+ $regml(signal,4) lang= $+ $regml(signal,5) nick= $+ $regml(signal,6)
    if ($hget(cases,%caseNumber) != $null) CT_Log -> NOTE case %caseNumber already existed ( $+ $CT_Describe(%caseNumber) $+ ), overwriting
    noop $CT_Store(%caseNumber,%nickname,$regml(signal,2),%mode,$regml(signal,5))
    CT_Log -> STORED case %caseNumber => $CT_Describe(%caseNumber)
    echo %switches new client %caseNumber => $CT_Describe(%caseNumber)
    return
  }

  var %re = /The client nickname for case #(\d+) \(.*\) has been changed to (.*)\./S
  if ($regex(nickCMD, $1-, %re)) {
    CT_Log -> MATCH nickCMD
    changeTokenValue $regml(nickCMD,1) nickname $regml(nickCMD,2)
    return
  }

  var %re = /Caution: Client of case #(\d+) \(.*\) has changed IRC nick to (.*)/S
  if ($regex(nickChange, $1-, %re)) {
    CT_Log -> MATCH nickChange
    changeTokenValue $regml(nickChange,1) nickname $regml(nickChange,2)
    return
  }

  var %re = /Caution: Case #(\d+) client \(.*\) has rejoined with a different name! \((.*)\)/S
  if ($regex(nickChangeJoin, $1-, %re)) {
    CT_Log -> MATCH nickChangeJoin
    changeTokenValue $regml(nickChangeJoin,1) nickname $regml(nickChangeJoin,2)
    return
  }

  var %re = /The language for case #(\d+) \(.*\) has now been changed to (\w{2}).*/S
  if ($regex(langChange, $1-, %re)) {
    CT_Log -> MATCH langChange
    changeTokenValue $regml(langChange,1) language $regml(langChange,2)
    return
  }

  var %re = /Client of case #(\d+) \((.*)\) was using a banned VPN or proxy and couldn't join so the case has been trashed\./S
  if ($regex(VPNdeletion, $1-, %re)) {
    var %caseNumber = $regml(VPNdeletion,1)
    var %client = $regml(VPNdeletion,2)
    CT_Log -> MATCH VPNdeletion: case %caseNumber $iif($hget(cases,%caseNumber) != $null,deleted,was not tracked)
    if ($hget(cases,%caseNumber) != $null) hdel cases %caseNumber
    echo -ag WARNING: Case %caseNumber ( $+ %client $+ ) was deleted.
    return
  }

  var %re = /The platform for case #(\d+) \(.*\) has been set to: (PC|Xbox|Playstation)\./S
  if ($regex(platformChange, $1-, %re)) {
    var %caseNumber = $regml(platformChange,1)
    var %platform = $regml(platformChange,2)
    var %mode = $getMode(%caseNumber)
    CT_Log -> MATCH platformChange

    changeTokenValue %caseNumber platform %platform
    ; Consoles only run Legacy
    if ((%platform != PC) && (%mode != Legacy)) changeTokenValue %caseNumber mode Legacy
    return
  }

  var %re = /Case #(\d+) \(.*\) is marked as using the (Legacy|Horizons|Odyssey) version/SF
  if ($regex(modeChange, $1-, %re)) {
    CT_Log -> MATCH modeChange
    changeTokenValue $regml(modeChange,1) mode $regml(modeChange,2)
    return
  }

  var %re = /Successfully closed case #(\d+).*/S
  if ($regex(close, $1-, %re)) {
    var %caseNumber = $regml(close,1)
    CT_Log -> MATCH close: case %caseNumber $iif($hget(cases,%caseNumber) != $null,removed,was not tracked)
    if ($hget(cases,%caseNumber) != $null) {
      hdel cases %caseNumber
      echo -tsg case %caseNumber closed
    }
    return
  }

  var %re = /Successfully added case #(\d+) \(.*\) to the deletion list\./S
  if ($regex(md, $1-, %re)) {
    var %caseNumber = $regml(md,1)
    CT_Log -> MATCH md: case %caseNumber $iif($hget(cases,%caseNumber) != $null,removed,was not tracked)
    if ($hget(cases,%caseNumber) != $null) {
      hdel cases %caseNumber
      echo -tsg case %caseNumber MDed
    }
    return
  }

  ; Nothing matched. If this line mentions a case or a signal, the bot's wording may have changed.
  if ((SIGNAL isin $1-) || ($chr(35) isin $1-)) CT_Log -> NO MATCH (check this line - wording may have changed)
  else CT_Log -> no match
}


; ---------- Commands ----------

; /addcase case# clientName Platform leg/hor/ody Lang-Code
alias addcase {
  if ($5 == $null) {
    echo -ag Usage: /addcase <case#> <client> <PC|xb|ps> <leg|hor|ody> <lang>
    return
  }

  ; change platform to what mecha uses
  var %platform = $3
  if ($3 == xb) var %platform = Xbox
  elseif ($3 == ps) var %platform = Playstation

  var %mode = $4
  if ($4 == ody) var %mode = Odyssey
  elseif ($4 == hor) var %mode = Horizons
  elseif ($4 == leg) var %mode = Legacy

  noop $CT_Store($1,$2,%platform,%mode,$5)
  echo -ag new client $1 => $CT_Describe($1)
}

; /delcase case#
alias delcase {
  if ($hget(cases,$$1) != $null) {
    hdel cases $1
    echo -ag deleted case $1
  }
  else {
    echo -ag case $1 does not exist
  }
}

; /getcase case#
alias getcase {
  if ($hget(cases,$$1) != $null) {
    echo -ag $1 => $CT_Describe($1)
  }
  else {
    echo -ag case $chr(35) $+ $1 not found
  }
}

; delete all cases
alias clearcases {
  if ($hget(cases)) hfree cases
  echo -ag all cases deleted
}

; list all cases, sorted by case number
alias listcases {
  var %count = $hget(cases,0).item
  if (%count == $null || %count == 0) {
    echo -ag no cases tracked
    return
  }

  var %i = 1
  var %keys
  while (%i <= %count) {
    var %keys = $addtok(%keys,$hget(cases,%i).item,32)
    inc %i
  }
  var %keys = $sorttok(%keys,32,n)

  var %i = 1
  while (%i <= %count) {
    var %case = $gettok(%keys,%i,32)
    echo -ag %case => $CT_Describe(%case)
    inc %i
  }
}


; /cttest [case#] - feeds a sample RATSIGNAL through the parser (local only, nothing is sent)
alias cttest {
  var %case = $iif($1 isnum,$1,999)
  CT_Parse -ag RATSIGNAL Case $chr(35) $+ %case PC ODY – CMDR Test Client – System: "SOL" (G2 star 0 LY from Sol) – Language: English (United States) (en-US) – Nick: Test_Client (ODY_SIGNAL)
  if ($hget(cases,%case) == $null) echo -ag Casetracker test FAILED: signal was not recognised
  elseif ($CT_Describe(%case) != Test_Client - speaking en on PC (Odyssey)) echo -ag Casetracker test FAILED: fields parsed wrong (check regex F flag support)
  else echo -ag Casetracker test OK - remove with /delcase %case
}


; ---------- Identifiers for DispatchAliases ----------

alias getClientNames {
  ; Looks at the first 3 words: known case numbers become the client's nickname,
  ; unknown case numbers are dropped, other words are kept as they are.
  ; If no case number was found, all arguments are returned unchanged.
  var %clientNames
  var %found = 0
  var %i = 1
  while (%i <= 3) {
    var %word = $gettok($1-,%i,32)
    if (%word isnum) {
      if ($hget(cases,%word) != $null) {
        var %found = 1
        var %clientNames = %clientNames $gettok($hget(cases,%word),1,36)
      }
    }
    elseif (%word != $null) {
      var %clientNames = %clientNames %word
    }
    inc %i
  }

  if (%found == 0) return $1-
  return %clientNames
}

alias getMode {
  if ($hget(cases,$1) != $null) return $gettok($hget(cases,$1),3,36)
}

alias getLanguage {
  if ($hget(cases,$1) != $null) return $gettok($hget(cases,$1),4,36)
}

; $1 = caseNumber, $2 = nickname/platform/mode/language (may be abbreviated), $3- = newValue
alias changeTokenValue {
  var %caseNumber = $1
  var %newValue = $3-
  var %tokenPos = 0

  if ($2 isin nickname) var %tokenPos = 1
  elseif ($2 isin platform) var %tokenPos = 2
  elseif ($2 isin mode) var %tokenPos = 3
  elseif ($2 isin language) var %tokenPos = 4

  if ((%tokenPos == 0) || (%newValue == $null)) {
    echo -tsg tokenPos not found in changeTokenValue
    CT_Log -> ERROR changeTokenValue: bad field or empty value ( $+ $1- $+ )
    return 0
  }

  var %tokens = $hget(cases,%caseNumber)
  if (%tokens == $null) {
    CT_Log -> IGNORED: case %caseNumber is not tracked, $2 not changed to %newValue
    return 0
  }

  var %oldValue = $gettok(%tokens,%tokenPos,36)
  hadd -m10 cases %caseNumber $puttok(%tokens,%newValue,%tokenPos,36)
  echo -tsg $2 changed for case %caseNumber : %oldValue => %newValue
  CT_Log -> CHANGED case %caseNumber $2 $+ : %oldValue => %newValue - now: $CT_Describe(%caseNumber)
}


; ---------- Debug ----------

; /ctdebug         toggle debug logging on/off
; /ctdebug clear   delete the log file
; The log (casetracker_debug.log next to this script) records every bot line in the tracked
; channels, which rule matched it, and how the case looks afterwards. Nothing is sent to IRC.
alias ctdebug {
  if ($1 == clear) {
    if ($isfile($CT_LogFile)) .remove $qt($CT_LogFile)
    echo -ag Casetracker debug log cleared
    return
  }

  if (%CTDebug == $true) {
    CT_Log === debug disabled ===
    set %CTDebug $false
    echo -ag Casetracker debug Disabled
    return
  }

  set %CTDebug $true
  var %count = $hget(cases,0).item
  if (%count == $null) var %count = 0
  CT_Log === debug enabled - spmode= $+ $iif(%spmode == $null,unset,%spmode) - %count case(s) tracked ===
  var %i = 1
  while (%i <= %count) {
    CT_Log -> existing case $hget(cases,%i).item => $CT_Describe($hget(cases,%i).item)
    inc %i
  }
  echo -ag Casetracker debug Enabled - logging to $CT_LogFile
}


; ---------- Events ----------

on *:TEXT:*:#fuelrats,#ratchat:{
  if ($nick != MechaSqueak[BOT]) return
  if (%spmode == 2) {
    CT_Log IGNORED (drill mode active) $chan < $+ $nick $+ > $1-
    return
  }
  CT_Parse -tsg $1-
}

on *:TEXT:*:#beyond,#horizons,#odyssey,#drillrats,#drillrats2,#drillrats3:{
  if ($nick != DrillSqueak[BOT]) return
  if (%spmode != 2) {
    CT_Log IGNORED (dispatch mode active) $chan < $+ $nick $+ > $1-
    return
  }
  CT_Parse -ag $1-
}

on *:EXIT:{
  set %translationsLoaded $false
  set %caseTracker $false
}
