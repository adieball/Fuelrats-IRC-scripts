; ============================================================
; Auto-SCTime(TM) - supercruise travel-time estimates (standard mIRC scripting)
; Credits go to Delryn for the initial work, I just adapted the old mirc code for SeraphIRC
; ============================================================
; Commands:
;   /ToggleSCTime        Enable/disable auto-annotation (default: enabled)
;   /ToggleSCTimeDebug   Enable/disable debug output to the status window (default: disabled)
;   /ToggleInline        Inline vs. next-line output for incoming messages (default: next-line)
;   /sctime <distance>   Calculate locally without sending anything (works even when disabled)
; Settings are stored as global variables and persist across restarts.


; ---------- Toggles ----------

alias ToggleSCTime {
  ; Unset counts as enabled, so the first call disables
  if (%SCTimeEnabled == $false) {
    set %SCTimeEnabled $true
    echo -ag Auto-SCTime™ Enabled
  }
  else {
    set %SCTimeEnabled $false
    echo -ag Auto-SCTime™ Disabled
  }
}

alias ToggleSCTimeDebug {
  ; Unset counts as disabled, so the first call enables
  if (%SCTimeDebug == $true) {
    set %SCTimeDebug $false
    echo -ag Auto-SCTime™ Debug Disabled
  }
  else {
    set %SCTimeDebug $true
    echo -ag Auto-SCTime™ Debug Enabled
  }
}

alias ToggleInline {
  ; Unset counts as disabled (next-line output), so the first call switches to inline
  if (%SCTimeInline == $true) {
    set %SCTimeInline $false
    echo -ag Auto-SCTime™ Inline Formatting Disabled
  }
  else {
    set %SCTimeInline $true
    echo -ag Auto-SCTime™ Inline Formatting Enabled
  }
}


; ---------- Configuration ----------

alias SetColors {
  ; Basic colour numbers are the mIRC colours listed in Tools > Options > Colors.
  ; Other colour numbers can come from $color(), e.g. $color(whois).
  set %deepSpaceColor 06
  set %gravWellColor 08
  set %mandyGoodColor 03
  set %mandyBadColor 04
  set %caspGoodColor 09
  set %caspBadColor 10

  ; Recommended settings
  ;set %deepSpaceColor $color(whois)
  ;set %gravWellColor $color(whois)
  ;set %mandyGoodColor $color(whois)
  ;set %mandyBadColor 04
  ;set %caspGoodColor $color(whois)
  ;set %caspBadColor 04
}


; ---------- Helpers ----------

alias -l SCTimeRegex {
  ; Number followed by a unit. The trailing \b prevents false matches such as "3 lyrics".
  ; To only match on callouts, return this instead:
  ;   /#.*\s((\d+|,|\.)+)\s?(kls|mls|ls|ly)\b/iS
  return /((\d+|,|\.)+)\s?(kls|mls|ls|ly)\b/iS
}

alias -l SCTimeDebugMsg {
  if (%SCTimeDebug == $true) echo -s [Auto-SCTime] $1-
}

alias -l SCTimeC {
  ; Colour code padded to two digits, so a following digit (e.g. "15m") is not read as part of the colour
  return $chr(3) $+ $base($1,10,10,2)
}

alias -l SCTimeMatch {
  ; The matched distance as typed, e.g. "120kls" (number plus unit)
  return $regml(lightDistance,1) $+ $regml(lightDistance,$regml(lightDistance,0))
}

alias ConvertToLs {
  ; Converts the last regex match (named lightDistance) into light seconds.
  ; Returns -1 for distances too large to supercruise, -2 for unknown units.
  var %distance = $round($remove($regml(lightDistance,1),$chr(44)),2)
  var %unit = $regml(lightDistance,$regml(lightDistance,0))

  if (%unit == mls) return $calc(%distance * 1000000)
  if (%unit == kls) return $calc(%distance * 1000)
  if (%unit == ly) {
    if (%distance > 0.5) return -1
    return $calc(%distance * 31557600)
  }
  if (%unit == ls) return %distance
  return -2
}

alias CalcTotalSeconds {
  ; $1 = light seconds, $2 = $true to calculate with destination gravity well
  var %ls = $1
  if ($2 == $true) var %ls = $int($calc( %ls / 2 ))

  if (%ls < 100000) {
    var %t = $int($calc( ( %ls ^ 0.3292 ) * 8.9034 ))
  }
  elseif (%ls < 1907087) {
    var %val1 = $calc( -8 * 10 ^ -23 * %ls ^ 4 )
    var %val2 = $calc( 4 * 10 ^ -16 * %ls ^ 3 - 8 * 10 ^ -10 * %ls ^ 2 )
    var %val3 = $calc( 0.0014 * %ls + 264.79 )
    var %t = $int($calc( %val1 + %val2 + %val3 ))
  }
  else {
    var %t = $int($calc( ( %ls - 5265389.609 ) / 2001 + 3412 ))
  }

  if ($2 == $true) var %t = $int($calc( %t * 2 ))
  return %t
}

alias CalcMandalaySeconds {
  if ($1 < 50000) return 25
  return $int($calc( ( 0.000237255 * $1 ) + 13.9247 ))
}

alias CalcCaspianSeconds {
  if ($1 < 33000) return 25
  return $int($calc( ( 0.000351263 * $1 ) + 12.7655 ))
}

alias FormatTimeString {
  var %totalSeconds = $1
  var %hours = $int($calc( %totalSeconds / 3600 ))
  var %remainderSec = $calc( %totalSeconds % 3600 )
  var %minutes = $int($calc( %remainderSec / 60 ))
  var %seconds = $calc( %totalSeconds % 60 )

  if (%hours > 0) return %hours $+ h $+ %minutes $+ m
  if (%minutes > 0) return %minutes $+ m $+ %seconds $+ s
  return %seconds $+ s
}

alias SCTimeBuild {
  ; $1 = light seconds. Returns the coloured "Norm-x|y|SCO-a|b" string, or nothing if invalid.
  var %ls = $1
  var %norm = $CalcTotalSeconds(%ls,$false)
  var %grav = $CalcTotalSeconds(%ls,$true)
  if ((%norm <= 0) || (%grav <= 0)) return

  var %mandy = $CalcMandalaySeconds(%ls)
  if (%mandy == 25) var %mandyText = <25s
  else var %mandyText = $FormatTimeString(%mandy)

  var %casp = $CalcCaspianSeconds(%ls)
  if (%casp == 25) var %caspText = <25s
  else var %caspText = $FormatTimeString(%casp)

  SetColors
  if (%ls > 1600000) {
    var %mandyColor = %mandyBadColor
    var %caspColor = %caspBadColor
  }
  elseif (%ls > 700000) {
    var %mandyColor = %mandyGoodColor
    var %caspColor = %caspBadColor
  }
  else {
    var %mandyColor = %mandyGoodColor
    var %caspColor = %caspGoodColor
  }

  var %sep = $SCTimeC($color(normal)) $+ $chr(124)
  return $SCTimeC($color(notice)) $+ Norm- $+ $SCTimeC(%deepSpaceColor) $+ $FormatTimeString(%norm) $+ %sep $+ $SCTimeC(%gravWellColor) $+ $FormatTimeString(%grav) $+ %sep $+ $SCTimeC($color(notice)) $+ SCO- $+ $SCTimeC(%mandyColor) $+ %mandyText $+ %sep $+ $SCTimeC(%caspColor) $+ %caspText $+ $chr(15)
}


; ---------- Incoming channel messages ----------

on ^*:TEXT:*:#:{
  if (%SCTimeEnabled == $false) return
  if ($nick == MechaSqueak[BOT]) return

  var %regex = $SCTimeRegex
  if (!$regex(lightDistance, $1-, %regex)) return
  if ($remove($regml(lightDistance,1),$chr(44)) !isnum) return

  var %ls = $ConvertToLs
  if (%ls <= 0) return

  var %times = $SCTimeBuild(%ls)
  if (%times == $null) return

  SCTimeDebugMsg $nick : $SCTimeMatch -> %ls ls

  var %segment = $SCTimeMatch $+ $chr(29) $+ $SCTimeC($color(whois)) $chr(40) $+ %times $+ $SCTimeC($color(whois)) $+ $chr(41) $+ $chr(15)

  ; Nick with its channel prefix (@, +, ...). Not coloured: mIRC colour numbers ignore the
  ; theme, so dark ones are unreadable on a dark background.
  ; Fall back to the plain nick if the nicklist lookup fails (seen in SeraphIRC 6.0.7)
  var %pnick = $nick(#,$nick).pnick
  if ($nick !isin %pnick) var %pnick = $nick
  SCTimeDebugMsg nick: $nick pnick: $nick(#,$nick).pnick
  var %nickDisplay = < $+ %pnick $+ >

  if (%SCTimeInline == $true) {
    var %subbedText
    noop $regsub($1-,%regex,%segment,%subbedText)
    echo -tlbfm # %nickDisplay %subbedText
  }
  else {
    ; Indent the second line so it lines up under the message text.
    ; Space + Ctrl-O pairs stop mIRC from collapsing the spaces.
    var %offsetCount = $calc( $len($timestamp) + $len(%pnick) + 3 )
    var %offset = $chr(124)
    var %j = 0
    while (%j < %offsetCount) {
      var %offset = %offset $+ $chr(32) $+ $chr(15)
      inc %j
    }
    var %offset = $remove(%offset,$chr(124))

    echo -tlbfm # %nickDisplay $1-
    echo -g # %offset $+ %segment
  }

  halt
}


; ---------- Own input ----------

on *:INPUT:#:{
  if ($1 == /sctime) {
    ; Manual calculation: always runs, never sends to the channel
    var %manual = $true
    var %text = $2-
  }
  else {
    ; Leave commands (/me, /msg, ...) and Ctrl+Enter input alone
    if ($ctrlenter) return
    if ($left($1,1) == /) return
    if (%SCTimeEnabled == $false) return
    var %manual = $false
    var %text = $1-
  }

  var %regex = $SCTimeRegex
  var %ls = 0
  if (($regex(lightDistance, %text, %regex)) && ($remove($regml(lightDistance,1),$chr(44)) isnum)) {
    var %ls = $ConvertToLs
  }

  var %times
  if (%ls > 0) var %times = $SCTimeBuild(%ls)

  if (%times == $null) {
    if (%manual) {
      echo -ag Auto-SCTime™: no valid distance found. Usage: /sctime <distance>, e.g. /sctime 250kls
      halt
    }
    return
  }

  SCTimeDebugMsg input : $SCTimeMatch -> %ls ls

  if (!%manual) say %text
  echo -ag ( $+ $SCTimeMatch $+ $chr(29) %times $+ $chr(15) $+ )

  halt
}
