; ============================================================
; Dispatch Aliases - multi-language dispatch macros for the Fuel Rats (standard mIRC scripting)
; Original by LittleFool, reworked by SrF1xx and Blauregen
; Adapted from the AdiIRC version (da_aliases.ini, da_remote.ini, dispatch mode setup.ini) for SeraphIRC
; REQUIRES Casetracker (SeraphIRC/Casetracker/casetracker.mrc) to be loaded.
; ============================================================
; Usage:  /<macro>[-<lang>] <case#> [more]
;   /hello 4              welcome text in English to the client of case 4
;   /hello-de 4           same in German
;   /hello-a 4            language taken from the case
;   /hello SomeNick       a nick instead of a case number is used as is
;   /wing 4               picks wing (Legacy) or team (Horizons/Odyssey) from the case's mode
;                         and also sends the Mecha command (wing, team, beacon, sc, open)
;   /crgo 4 RatA RatB     &rats& in the text = everything after the case number
;   /eta 4 5              &eta& in the text = second word
;   /close[-lang] <case#> <rat> [client]   close text + !close (client only needed if the case isn't tracked)
;   /crinst[-lang] <case#> code red instructions, followed by a timed sequence; /abort stops it
;   /csay <case#> <text>  says <text> prefixed with the client's nick
;
; Settings:
;   /drillmode            toggle dispatch mode (#fuelrats) / drill & training mode
;   /dadry                toggle dry-run: everything is only echoed locally, NOTHING is sent
;
; Messages always go to the channel/query window that was active when the command was typed.


; ---------- Mode ----------

alias drillmode {
  if (%spmode == 2) {
    set %spmode 1
    echo -ag dispatch mode active
  }
  else {
    set %spmode 2
    echo -ag drill & training mode active
  }
}

alias dadry {
  if (%DA_DryRun == $true) {
    set %DA_DryRun $false
    echo -ag Dispatch Aliases dry-run Disabled - messages are sent again
  }
  else {
    set %DA_DryRun $true
    echo -ag Dispatch Aliases dry-run Enabled - nothing is sent, messages are only shown locally
  }
}

on *:START:{
  if (%spmode == $null) set %spmode 1
  echo -tsg current mode: $iif(%spmode == 2,drill & training,dispatch) $iif(%DA_DryRun == $true,- DRY-RUN active (/dadry))
  if (!$isalias(getClientNames)) echo -tsg == Warning - Dispatch Aliases need Casetracker, which is not loaded ==
}

on *:EXIT:{
  set %translationsLoaded $false
  set %caseTracker $false
}


; ---------- Helpers ----------

alias -l DA_Send {
  ; $1 = target window, $2- = text. In dry-run mode the text is only shown locally.
  if ($2 == $null) return
  if (%DA_DryRun == $true) {
    echo -ag [DRY-RUN -> $1 $+ ] $2-
    return
  }
  msg $1 $2-
}

alias -l DA_Target {
  ; Returns the active channel/query window, or nothing (with a warning)
  if (($active ischan) || ($query($active))) return $active
  echo -ag == Warning - not in a channel or query window, nothing sent ==
}

alias -l DA_Ready {
  ; Checks that Casetracker is loaded
  if ($isalias(getClientNames)) return $true
  echo -ag == Warning - Casetracker is not loaded, Dispatch Aliases can't work without it ==
  return $false
}

alias -l DA_CaseKnown {
  ; $1 = case number. $true if Casetracker tracks this case.
  if (($1 isnum) && ($getMode($1) != $null)) return $true
  return $false
}

alias -l DA_Resolve {
  ; $1- = case number(s)/nicks. Returns the client names, or nothing (with a warning) if a case number is unknown.
  if (($1 isnum) && (!$DA_CaseKnown($1))) {
    echo -ag == Warning - Case $1 not found ==
    return
  }
  return $getClientNames($1-)
}

alias -l DA_EnsureTranslations {
  if (!$hget(da_hello)) load_translations
}

alias -l DA_Text {
  ; $1 = macro, $2 = language. Falls back to English.
  DA_EnsureTranslations
  var %line = $hget(da_ $+ $1,$2)
  if (%line == $null) var %line = $hget(da_ $+ $1,en)
  return %line
}


; ---------- Core ----------

; $1 = macro, $2 = language (or "a" = language of the case), $3- = case number(s)/nicks and extra words
alias say_alias {
  if (!$DA_Ready) return
  var %alias = $1
  var %language = $2
  var %params = $3-

  var %target = $DA_Target
  if (%target == $null) return
  var %clientNames = $DA_Resolve(%params)
  if (%clientNames == $null) return
  var %clientName = $gettok(%clientNames,1,32)

  ; Pick the Legacy or Horizons/Odyssey version of the macro from the case's mode
  var %mode = $getMode($3)
  if ((%mode == Odyssey) || (%mode == Horizons)) {
    if (%alias == wing) var %alias = team
    elseif (%alias == crgo) var %alias = crgoody
    elseif (%alias == crvideo) var %alias = crvideoody
  }
  elseif (%mode == Legacy) {
    if (%alias == team) var %alias = wing
    elseif (%alias == crgoody) var %alias = crgo
    elseif (%alias == crvideoody) var %alias = crvideo
    elseif (%alias == crinst) var %alias = crinstleg
  }

  if (%language == a) var %language = $getLanguage($3)
  if (%language == $null) var %language = en

  var %line = $DA_Text(%alias,%language)
  if (%line == $null) {
    echo -ag == Warning - no text found for %alias ==
    return
  }
  var %line = $replace(%line,&clientNames&,%clientNames)
  var %line = $replace(%line,&clientName&,%clientName)
  var %line = $replace(%line,&rats&,$4-)
  var %line = $replace(%line,&eta&,$4)
  DA_Send %target %line

  ; Send the Mecha command if the macro requires it
  if ($istok(wing team beacon sc open,%alias,32)) {
    if (%language == en) DA_Send %target $+(!,%alias) %params
    else DA_Send %target $+(!,%alias,-,%language) %params
  }

  if ((%alias == crinst) || (%alias == crinstleg)) noop $DA_StartCrinst(%target,%alias,%language,%params,%clientNames)
}

; $1 = language, $2 = case#, $3 = rat, $4 = client (only used if the case isn't tracked)
alias close_main {
  if (!$DA_Ready) return
  var %language = $1
  var %target = $DA_Target
  if (%target == $null) return

  var %client = $4
  if ($DA_CaseKnown($2)) var %client = $getClientNames($2)
  if (%client == $null) {
    echo -ag == Warning - Case $2 not found (if it isn't tracked, use: /close <case#> <rat> <client>) ==
    return
  }
  if (%client == $3) {
    echo -ag == Warning - Can't close case to client ==
    return
  }

  if (%language == a) var %language = $getLanguage($2)
  if (%language == $null) var %language = en

  DA_Send %target $replace($DA_Text(close,%language),&clientName&,%client)
  if (%spmode == 2) DA_Send %target !close $2 $3
  else DA_Send #ratchat !close $2 $3
}

alias csay {
  if (!$DA_Ready) return
  var %target = $DA_Target
  if (%target == $null) return
  var %client = $DA_Resolve($$1)
  if (%client == $null) return
  DA_Send %target %client $$2-
}


; ---------- Code red instruction sequence ----------

alias -l DA_StartCrinst {
  ; $1 = target, $2 = crinst|crinstleg, $3 = language, $4 = case params, $5 = client names
  ; The texts are prepared now and stored; the timer only calls DA_CrinstStep with a step number.
  var %suffix
  if ($3 != en) var %suffix = - $+ $3
  var %wing = $+(!wing,%suffix) $4
  var %beacon = $+(!beacon,%suffix) $4
  var %video = $replace($DA_Text($iif($2 == crinst,crvideoody,crvideo),$3),&clientNames&,$5)
  var %end = $replace($DA_Text(crinstend,$3),&clientName&,$5)

  .timerDA_crinst* off
  if ($hget(da_seq)) hfree da_seq
  hadd -m da_seq target $1
  if ($2 == crinst) {
    hadd da_seq 1 %wing
    hadd da_seq 2 %beacon
  }
  else {
    hadd da_seq 1 %beacon
    hadd da_seq 2 %wing
  }
  hadd da_seq 3 %video
  hadd da_seq 4 %end
  .timerDA_crinst1 1 5 DA_CrinstStep 1
}

alias DA_CrinstStep {
  ; Called by the timers. $1 = step (1-4). Delays: 5s, 7s, 7s, 5s
  var %target = $hget(da_seq,target)
  var %text = $hget(da_seq,$1)
  if ((%target == $null) || (%text == $null)) return
  DA_Send %target %text
  if ($1 == 1) .timerDA_crinst2 1 7 DA_CrinstStep 2
  elseif ($1 == 2) .timerDA_crinst3 1 7 DA_CrinstStep 3
  elseif ($1 == 3) .timerDA_crinst4 1 5 DA_CrinstStep 4
  else hfree da_seq
}

alias abort {
  .timerDA_crinst* off
  if ($hget(da_seq)) hfree da_seq
  echo -ag crinst-sequence aborted
}


; ---------- Commands ----------
; /<macro> = English, /<macro>-a = language of the case, /<macro>-<lang> = that language

alias hello say_alias hello en $$1-
alias hello-a say_alias hello a $$1-
alias hello-de say_alias hello de $$1-
alias hello-ru say_alias hello ru $$1-
alias hello-es say_alias hello es $$1-
alias hello-fr say_alias hello fr $$1-
alias hello-pt say_alias hello pt $$1-
alias hello-it say_alias hello it $$1-
alias hello-zh say_alias hello zh $$1-
alias hello-pl say_alias hello pl $$1-
alias hello-cs say_alias hello cs $$1-
alias hello-tr say_alias hello tr $$1-
alias hello-hu say_alias hello hu $$1-
alias hello-nl say_alias hello nl $$1-

alias eng-a say_alias eng a $$1-
alias eng-de say_alias eng de $$1-
alias eng-es say_alias eng es $$1-
alias eng-ru say_alias eng ru $$1-
alias eng-fr say_alias eng fr $$1-
alias eng-nb say_alias eng nb $$1-
alias eng-tr say_alias eng tr $$1-
alias eng-cs say_alias eng cs $$1-
alias eng-pl say_alias eng pl $$1-
alias eng-hu say_alias eng hu $$1-
alias eng-nl say_alias eng nl $$1-
alias eng-pt say_alias eng pt $$1-
alias eng-it say_alias eng it $$1-

alias offq say_alias offq en $$1-
alias offq-a say_alias offq a $$1-
alias offq-de say_alias offq de $$1-
alias offq-ru say_alias offq ru $$1-
alias offq-es say_alias offq es $$1-
alias offq-fr say_alias offq fr $$1-
alias offq-pt say_alias offq pt $$1-
alias offq-zh say_alias offq zh $$1-
alias offq-it say_alias offq it $$1-
alias offq-pl say_alias offq pl $$1-
alias offq-cs say_alias offq cs $$1-
alias offq-tr say_alias offq tr $$1-
alias offq-hu say_alias offq hu $$1-
alias offq-nl say_alias offq nl $$1-

alias sr say_alias sr en $$1-
alias sr-a say_alias sr a $$1-
alias sr-de say_alias sr de $$1-
alias sr-ru say_alias sr ru $$1-
alias sr-es say_alias sr es $$1-
alias sr-fr say_alias sr fr $$1-
alias sr-pt say_alias sr pt $$1-
alias sr-zh say_alias sr zh $$1-
alias sr-it say_alias sr it $$1-
alias sr-pl say_alias sr pl $$1-
alias sr-cs say_alias sr cs $$1-
alias sr-tr say_alias sr tr $$1-
alias sr-hu say_alias sr hu $$1-
alias sr-nl say_alias sr nl $$1-

alias o2 say_alias o2 en $$1-
alias o2-a say_alias o2 a $$1-
alias o2-de say_alias o2 de $$1-
alias o2-ru say_alias o2 ru $$1-
alias o2-es say_alias o2 es $$1-
alias o2-fr say_alias o2 fr $$1-
alias o2-pt say_alias o2 pt $$1-
alias o2-zh say_alias o2 zh $$1-
alias o2-it say_alias o2 it $$1-
alias o2-pl say_alias o2 pl $$1-
alias o2-cs say_alias o2 cs $$1-
alias o2-tr say_alias o2 tr $$1-
alias o2-hu say_alias o2 hu $$1-
alias o2-nl say_alias o2 nl $$1-

alias navsys say_alias navsys en $$1-
alias navsys-a say_alias navsys a $$1-
alias navsys-de say_alias navsys de $$1-
alias navsys-ru say_alias navsys ru $$1-
alias navsys-es say_alias navsys es $$1-
alias navsys-fr say_alias navsys fr $$1-
alias navsys-pt say_alias navsys pt $$1-
alias navsys-zh say_alias navsys zh $$1-
alias navsys-it say_alias navsys it $$1-
alias navsys-pl say_alias navsys pl $$1-
alias navsys-cs say_alias navsys cs $$1-
alias navsys-tr say_alias navsys tr $$1-
alias navsys-hu say_alias navsys hu $$1-
alias navsys-nl say_alias navsys nl $$1-

alias open say_alias open en $$1-
alias open-a say_alias open a $$1-
alias open-de say_alias open de $$1-
alias open-ru say_alias open ru $$1-
alias open-es say_alias open es $$1-
alias open-fr say_alias open fr $$1-
alias open-pt say_alias open pt $$1-
alias open-zh say_alias open zh $$1-
alias open-it say_alias open it $$1-
alias open-pl say_alias open pl $$1-
alias open-cs say_alias open cs $$1-
alias open-tr say_alias open tr $$1-
alias open-hu say_alias open hu $$1-
alias open-nl say_alias open nl $$1-

alias wing say_alias wing en $$1-
alias wing-a say_alias wing a $$1-
alias wing-de say_alias wing de $$1-
alias wing-ru say_alias wing ru $$1-
alias wing-es say_alias wing es $$1-
alias wing-fr say_alias wing fr $$1-
alias wing-pt say_alias wing pt $$1-
alias wing-it say_alias wing it $$1-
alias wing-zh say_alias wing zh $$1-
alias wing-pl say_alias wing pl $$1-
alias wing-cs say_alias wing cs $$1-
alias wing-tr say_alias wing tr $$1-
alias wing-hu say_alias wing hu $$1-
alias wing-nl say_alias wing nl $$1-

alias team say_alias team en $$1-
alias team-a say_alias team a $$1-
alias team-de say_alias team de $$1-
alias team-ru say_alias team ru $$1-
alias team-es say_alias team es $$1-
alias team-fr say_alias team fr $$1-
alias team-pt say_alias team pt $$1-
alias team-it say_alias team it $$1-
alias team-zh say_alias team zh $$1-
alias team-pl say_alias team pl $$1-
alias team-cs say_alias team cs $$1-
alias team-tr say_alias team tr $$1-
alias team-hu say_alias team hu $$1-
alias team-nl say_alias team nl $$1-

alias beacon say_alias beacon en $$1-
alias beacon-a say_alias beacon a $$1-
alias beacon-de say_alias beacon de $$1-
alias beacon-ru say_alias beacon ru $$1-
alias beacon-es say_alias beacon es $$1-
alias beacon-fr say_alias beacon fr $$1-
alias beacon-pt say_alias beacon pt $$1-
alias beacon-it say_alias beacon it $$1-
alias beacon-zh say_alias beacon zh $$1-
alias beacon-pl say_alias beacon pl $$1-
alias beacon-cs say_alias beacon cs $$1-
alias beacon-tr say_alias beacon tr $$1-
alias beacon-hu say_alias beacon hu $$1-
alias beacon-nl say_alias beacon nl $$1-

alias ls say_alias ls en $$1-
alias ls-a say_alias ls a $$1-
alias ls-de say_alias ls de $$1-
alias ls-ru say_alias ls ru $$1-
alias ls-es say_alias ls es $$1-
alias ls-fr say_alias ls fr $$1-
alias ls-pt say_alias ls pt $$1-
alias ls-zh say_alias ls zh $$1-
alias ls-it say_alias ls it $$1-
alias ls-pl say_alias ls pl $$1-
alias ls-cs say_alias ls cs $$1-
alias ls-tr say_alias ls tr $$1-
alias ls-hu say_alias ls hu $$1-
alias ls-nl say_alias ls nl $$1-

alias crm say_alias crm en $$1-
alias crm-a say_alias crm a $$1-
alias crm-de say_alias crm de $$1-
alias crm-ru say_alias crm ru $$1-
alias crm-es say_alias crm es $$1-
alias crm-fr say_alias crm fr $$1-
alias crm-pt say_alias crm pt $$1-
alias crm-zh say_alias crm zh $$1-
alias crm-it say_alias crm it $$1-
alias crm-pl say_alias crm pl $$1-
alias crm-cs say_alias crm cs $$1-
alias crm-tr say_alias crm tr $$1-
alias crm-hu say_alias crm hu $$1-
alias crm-nl say_alias crm nl $$1-

alias mmconf say_alias mmconf en $$1-
alias mmconf-a say_alias mmconf a $$1-
alias mmconf-de say_alias mmconf de $$1-
alias mmconf-ru say_alias mmconf ru $$1-
alias mmconf-es say_alias mmconf es $$1-
alias mmconf-fr say_alias mmconf fr $$1-
alias mmconf-pt say_alias mmconf pt $$1-
alias mmconf-zh say_alias mmconf zh $$1-
alias mmconf-it say_alias mmconf it $$1-
alias mmconf-pl say_alias mmconf pl $$1-
alias mmconf-cs say_alias mmconf cs $$1-
alias mmconf-tr say_alias mmconf tr $$1-
alias mmconf-hu say_alias mmconf hu $$1-
alias mmconf-nl say_alias mmconf nl $$1-

alias mmsys say_alias mmsys en $$1-
alias mmsys-a say_alias mmsys a $$1-
alias mmsys-de say_alias mmsys de $$1-
alias mmsys-ru say_alias mmsys ru $$1-
alias mmsys-es say_alias mmsys es $$1-
alias mmsys-fr say_alias mmsys fr $$1-
alias mmsys-pt say_alias mmsys pt $$1-
alias mmsys-zh say_alias mmsys zh $$1-
alias mmsys-it say_alias mmsys it $$1-
alias mmsys-pl say_alias mmsys pl $$1-
alias mmsys-cs say_alias mmsys cs $$1-
alias mmsys-tr say_alias mmsys tr $$1-
alias mmsys-hu say_alias mmsys hu $$1-
alias mmsys-nl say_alias mmsys nl $$1-

alias cro2 say_alias cro2 en $$1-
alias cro2-a say_alias cro2 a $$1-
alias cro2-de say_alias cro2 de $$1-
alias cro2-ru say_alias cro2 ru $$1-
alias cro2-es say_alias cro2 es $$1-
alias cro2-fr say_alias cro2 fr $$1-
alias cro2-pt say_alias cro2 pt $$1-
alias cro2-zh say_alias cro2 zh $$1-
alias cro2-it say_alias cro2 it $$1-
alias cro2-pl say_alias cro2 pl $$1-
alias cro2-cs say_alias cro2 cs $$1-
alias cro2-tr say_alias cro2 tr $$1-
alias cro2-hu say_alias cro2 hu $$1-
alias cro2-nl say_alias cro2 nl $$1-

alias crpos say_alias crpos en $$1-
alias crpos-a say_alias crpos a $$1-
alias crpos-de say_alias crpos de $$1-
alias crpos-ru say_alias crpos ru $$1-
alias crpos-es say_alias crpos es $$1-
alias crpos-fr say_alias crpos fr $$1-
alias crpos-pt say_alias crpos pt $$1-
alias crpos-zh say_alias crpos zh $$1-
alias crpos-it say_alias crpos it $$1-
alias crpos-pl say_alias crpos pl $$1-
alias crpos-cs say_alias crpos cs $$1-
alias crpos-tr say_alias crpos tr $$1-
alias crpos-hu say_alias crpos hu $$1-
alias crpos-nl say_alias crpos nl $$1-

alias crgo say_alias crgo en $$1 $$2-
alias crgo-a say_alias crgo a $$1 $$2-
alias crgo-de say_alias crgo de $$1 $$2-
alias crgo-ru say_alias crgo ru $$1 $$2-
alias crgo-es say_alias crgo es $$1 $$2-
alias crgo-fr say_alias crgo fr $$1 $$2-
alias crgo-pt say_alias crgo pt $$1 $$2-
alias crgo-zh say_alias crgo zh $$1 $$2-
alias crgo-it say_alias crgo it $$1 $$2-
alias crgo-pl say_alias crgo pl $$1 $$2-
alias crgo-cs say_alias crgo cs $$1 $$2-
alias crgo-tr say_alias crgo tr $$1 $$2-
alias crgo-hu say_alias crgo hu $$1 $$2-
alias crgo-nl say_alias crgo nl $$1 $$2-

alias crgoody say_alias crgoody en $$1 $$2-
alias crgoody-a say_alias crgoody a $$1 $$2-
alias crgoody-de say_alias crgoody de $$1 $$2-
alias crgoody-ru say_alias crgoody ru $$1 $$2-
alias crgoody-es say_alias crgoody es $$1 $$2-
alias crgoody-fr say_alias crgoody fr $$1 $$2-
alias crgoody-pt say_alias crgoody pt $$1 $$2-
alias crgoody-zh say_alias crgoody zh $$1 $$2-
alias crgoody-it say_alias crgoody it $$1 $$2-
alias crgoody-pl say_alias crgoody pl $$1 $$2-
alias crgoody-cs say_alias crgoody cs $$1 $$2-
alias crgoody-tr say_alias crgoody tr $$1 $$2-
alias crgoody-hu say_alias crgoody hu $$1 $$2-
alias crgoody-nl say_alias crgoody nl $$1 $$2-

alias crinst say_alias crinst en $$1-
alias crinst-a say_alias crinst a $$1-
alias crinst-de say_alias crinst de $$1-
alias crinst-ru say_alias crinst ru $$1-
alias crinst-es say_alias crinst es $$1-
alias crinst-fr say_alias crinst fr $$1-
alias crinst-pt say_alias crinst pt $$1-
alias crinst-zh say_alias crinst zh $$1-
alias crinst-it say_alias crinst it $$1-
alias crinst-pl say_alias crinst pl $$1-
alias crinst-cs say_alias crinst cs $$1-
alias crinst-tr say_alias crinst tr $$1-
alias crinst-hu say_alias crinst hu $$1-
alias crinst-nl say_alias crinst nl $$1-

alias crinstleg say_alias crinstleg en $$1-
alias crinstleg-a say_alias crinstleg a $$1-
alias crinstleg-de say_alias crinstleg de $$1-
alias crinstleg-ru say_alias crinstleg ru $$1-
alias crinstleg-es say_alias crinstleg es $$1-
alias crinstleg-fr say_alias crinstleg fr $$1-
alias crinstleg-pt say_alias crinstleg pt $$1-
alias crinstleg-zh say_alias crinstleg zh $$1-
alias crinstleg-it say_alias crinstleg it $$1-
alias crinstleg-pl say_alias crinstleg pl $$1-
alias crinstleg-cs say_alias crinstleg cs $$1-
alias crinstleg-tr say_alias crinstleg tr $$1-
alias crinstleg-hu say_alias crinstleg hu $$1-
alias crinstleg-nl say_alias crinstleg nl $$1-

alias crvideoleg say_alias crvideo en $$1-
alias crvideoleg-a say_alias crvideo a $$1-
alias crvideoleg-de say_alias crvideo de $$1-
alias crvideoleg-ru say_alias crvideo ru $$1-
alias crvideoleg-es say_alias crvideo es $$1-
alias crvideoleg-fr say_alias crvideo fr $$1-
alias crvideoleg-pt say_alias crvideo pt $$1-
alias crvideoleg-zh say_alias crvideo zh $$1-
alias crvideoleg-it say_alias crvideo it $$1-
alias crvideoleg-pl say_alias crvideo pl $$1-
alias crvideoleg-cs say_alias crvideo cs $$1-
alias crvideoleg-tr say_alias crvideo tr $$1-
alias crvideoleg-hu say_alias crvideo hu $$1-
alias crvideoleg-nl say_alias crvideo nl $$1-

alias crvideo say_alias crvideoody en $$1-
alias crvideo-a say_alias crvideoody a $$1-
alias crvideo-de say_alias crvideoody de $$1-
alias crvideo-ru say_alias crvideoody ru $$1-
alias crvideo-es say_alias crvideoody es $$1-
alias crvideo-fr say_alias crvideoody fr $$1-
alias crvideo-pt say_alias crvideoody pt $$1-
alias crvideo-zh say_alias crvideoody zh $$1-
alias crvideo-it say_alias crvideoody it $$1-
alias crvideo-pl say_alias crvideoody pl $$1-
alias crvideo-cs say_alias crvideoody cs $$1-
alias crvideo-tr say_alias crvideoody tr $$1-
alias crvideo-hu say_alias crvideoody hu $$1-
alias crvideo-nl say_alias crvideoody nl $$1-

alias eta say_alias eta en $$1 $$2
alias eta-a say_alias eta a $$1 $$2
alias eta-de say_alias eta de $$1 $$2
alias eta-ru say_alias eta ru $$1 $$2
alias eta-es say_alias eta es $$1 $$2
alias eta-fr say_alias eta fr $$1 $$2
alias eta-pt say_alias eta pt $$1 $$2
alias eta-zh say_alias eta zh $$1 $$2
alias eta-it say_alias eta it $$1 $$2
alias eta-pl say_alias eta pl $$1 $$2
alias eta-cs say_alias eta cs $$1 $$2
alias eta-tr say_alias eta tr $$1 $$2
alias eta-hu say_alias eta hu $$1 $$2
alias eta-nl say_alias eta nl $$1 $$2

alias sc say_alias sc en $$1-
alias sc-a say_alias sc a $$1-
alias sc-de say_alias sc de $$1-
alias sc-ru say_alias sc ru $$1-
alias sc-es say_alias sc es $$1-
alias sc-fr say_alias sc fr $$1-
alias sc-pt say_alias sc pt $$1-
alias sc-it say_alias sc it $$1-
alias sc-zh say_alias sc zh $$1-
alias sc-pl say_alias sc pl $$1-
alias sc-cs say_alias sc cs $$1-
alias sc-tr say_alias sc tr $$1-
alias sc-hu say_alias sc hu $$1-
alias sc-nl say_alias sc nl $$1-

alias scenter say_alias scenter en $$1-
alias scenter-a say_alias scenter a $$1-
alias scenter-de say_alias scenter de $$1-
alias scenter-ru say_alias scenter ru $$1-
alias scenter-es say_alias scenter es $$1-
alias scenter-fr say_alias scenter fr $$1-
alias scenter-pt say_alias scenter pt $$1-
alias scenter-zh say_alias scenter zh $$1-
alias scenter-it say_alias scenter it $$1-
alias scenter-pl say_alias scenter pl $$1-
alias scenter-cs say_alias scenter cs $$1-
alias scenter-tr say_alias scenter tr $$1-
alias scenter-hu say_alias scenter hu $$1-
alias scenter-nl say_alias scenter nl $$1-

alias scdrop say_alias scdrop en $$1-
alias scdrop-a say_alias scdrop a $$1-
alias scdrop-de say_alias scdrop de $$1-
alias scdrop-ru say_alias scdrop ru $$1-
alias scdrop-es say_alias scdrop es $$1-
alias scdrop-fr say_alias scdrop fr $$1-
alias scdrop-pt say_alias scdrop pt $$1-
alias scdrop-zh say_alias scdrop zh $$1-
alias scdrop-it say_alias scdrop it $$1-
alias scdrop-pl say_alias scdrop pl $$1-
alias scdrop-cs say_alias scdrop cs $$1-
alias scdrop-tr say_alias scdrop tr $$1-
alias scdrop-hu say_alias scdrop hu $$1-
alias scdrop-nl say_alias scdrop nl $$1-

alias close close_main en $$1 $$2 $3
alias close-a close_main a $$1 $$2 $3
alias close-de close_main de $$1 $$2 $3
alias close-ru close_main ru $$1 $$2 $3
alias close-es close_main es $$1 $$2 $3
alias close-fr close_main fr $$1 $$2 $3
alias close-pt close_main pt $$1 $$2 $3
alias close-it close_main it $$1 $$2 $3
alias close-zh close_main zh $$1 $$2 $3
alias close-pl close_main pl $$1 $$2 $3
alias close-cs close_main cs $$1 $$2 $3
alias close-tr close_main tr $$1 $$2 $3
alias close-hu close_main hu $$1 $$2 $3
alias close-nl close_main nl $$1 $$2 $3

alias db say_alias db en $$1-
alias db-a say_alias db a $$1-
alias db-ru say_alias db ru $$1-
alias db-de say_alias db de $$1-
alias db-es say_alias db es $$1-
alias db-fr say_alias db fr $$1-
alias db-pt say_alias db pt $$1-
alias db-zh say_alias db zh $$1-
alias db-it say_alias db it $$1-
alias db-pl say_alias db pl $$1-
alias db-cs say_alias db cs $$1-
alias db-tr say_alias db tr $$1-
alias db-hu say_alias db hu $$1-
alias db-nl say_alias db nl $$1-

alias sorry say_alias sorry en $$1-
alias sorry-a say_alias sorry a $$1-
alias sorry-de say_alias sorry de $$1-
alias sorry-ru say_alias sorry ru $$1-
alias sorry-es say_alias sorry es $$1-
alias sorry-fr say_alias sorry fr $$1-
alias sorry-pt say_alias sorry pt $$1-
alias sorry-zh say_alias sorry zh $$1-
alias sorry-it say_alias sorry it $$1-
alias sorry-pl say_alias sorry pl $$1-
alias sorry-cs say_alias sorry cs $$1-
alias sorry-tr say_alias sorry tr $$1-
alias sorry-hu say_alias sorry hu $$1-
alias sorry-nl say_alias sorry nl $$1-

alias plan say_alias plan en $$1-
alias plan-a say_alias plan a $$1-
alias plan-de say_alias plan de $$1-
alias plan-ru say_alias plan ru $$1-
alias plan-es say_alias plan es $$1-
alias plan-fr say_alias plan fr $$1-
alias plan-pt say_alias plan pt $$1-
alias plan-zh say_alias plan zh $$1-
alias plan-it say_alias plan it $$1-
alias plan-pl say_alias plan pl $$1-
alias plan-cs say_alias plan cs $$1-
alias plan-tr say_alias plan tr $$1-
alias plan-hu say_alias plan hu $$1-
alias plan-nl say_alias plan nl $$1-

alias crinstend say_alias crinstend en $$1
alias crinstend-a say_alias crinstend a $$1
alias crinstend-de say_alias crinstend de $$1
alias crinstend-ru say_alias crinstend ru $$1
alias crinstend-es say_alias crinstend es $$1
alias crinstend-fr say_alias crinstend fr $$1
alias crinstend-pt say_alias crinstend pt $$1
alias crinstend-zh say_alias crinstend zh $$1
alias crinstend-it say_alias crinstend it $$1
alias crinstend-pl say_alias crinstend pl $$1
alias crinstend-cs say_alias crinstend cs $$1
alias crinstend-tr say_alias crinstend tr $$1
alias crinstend-hu say_alias crinstend hu $$1
alias crinstend-nl say_alias crinstend nl $$1


; ---------- Translations ----------
; Placeholders: &clientNames& (all names), &clientName& (first name), &rats&, &eta&

alias load_translations {
  echo -tsg loading translations

  hadd -m13 da_hello en Welcome to the Fuel Rats, &clientNames&. Please tell us once you've completed the above instructions. If you have any questions or concerns, please ask.
  hadd -m13 da_hello de Willkommen bei den Fuel Rats, &clientNames&. Bitte sage bescheid, wenn du die obigen Anweisungen ausgeführt hast. Wenn du Fragen oder Bedenken hast, frag uns bitte.
  hadd -m13 da_hello ru Добро пожаловать к "Топливным крысам", &clientNames&. Пожалуйста, сообщите нам об этом, как только выполните вышеуказанные инструкции. Если у вас есть вопросы или опасения, пожалуйста, спрашивайте.
  hadd -m13 da_hello es Bienvenido/a a las Fuel Rats, &clientNames&. Por favor, díganoslo una vez que haya completado las instrucciones anteriores. Si tiene alguna duda o pregunta, no dude en consultarnos.
  hadd -m13 da_hello fr Bienvenue chez les Fuel Rats, &clientNames&. Veuillez nous en informer une fois que vous avez suivi les instructions ci-dessus. Si vous avez des questions ou des préoccupations, n'hésitez pas à les poser.
  hadd -m13 da_hello pt Seja bem-vindo ao Fuel Rats, &clientNames&. Informe-nos assim que tiver completado as instruções acima. Se tiver alguma dúvida ou preocupação, pergunte-nos.
  hadd -m13 da_hello it Benvenuto/a presso i Fuel Rats, &clientNames&. Vi preghiamo di comunicarcelo una volta completate le istruzioni di cui sopra. Se avete domande o dubbi, chiedete pure.
  hadd -m13 da_hello zh 欢迎来到Fuel Rats， &clientNames&. 请在完成上述说明后告诉我们。如果您有任何问题或顾虑，请提出。
  hadd -m13 da_hello pl Witamy w serwisie ratunkowym Fuel Rats, &clientNames&. Daj nam znać gdy już wykonasz powyższe instrukcje. W razie jakichkolwiek pytań lub wątpliwości śmiało pytaj.
  hadd -m13 da_hello cs Vítej u Fuel Rats, &clientNames&. Po dokončení výše uvedených pokynů nám prosím dejte vědět. Máte-li jakékoli dotazy nebo připomínky, zeptejte se.
  hadd -m13 da_hello tr Fuel Rats'e hoşgeldin! &clientNames&. Yukarıdaki talimatları tamamladıktan sonra lütfen bize haber verin. Herhangi bir sorunuz veya endişeniz varsa, lütfen sorun.
  hadd -m13 da_hello hu Üdvözölünk az Üzemanyag Patkányoknál &clientNames&! Kérjük, értesítsen minket, amint a fenti utasításokat végrehajtotta. Ha bármilyen kérdése vagy aggálya van, kérjük, kérdezze meg.
  hadd -m13 da_hello nl Welkom bij de Fuel Rats, &clientNames&. Laat het ons weten als je de bovenstaande instructies hebt voltooid. Als je vragen of zorgen hebt, stel ze dan gerust.

  hadd -m13 da_eng de &clientNames&, sprichst du Englisch?
  hadd -m13 da_eng es ¿ &clientNames&, hablas inglés?
  hadd -m13 da_eng ru &clientNames&, вы говорите по-английски?
  hadd -m13 da_eng fr &clientNames&, parlez-vous anglais ?
  hadd -m13 da_eng nb &clientNames&, snakker du engelsk?
  hadd -m13 da_eng tr &clientNames&, İngilizce konuşabiliyor musun?
  hadd -m13 da_eng cs &clientNames&, mluvíš anglicky?
  hadd -m13 da_eng pl &clientNames&, czy możemy mówić po angielsku?
  hadd -m13 da_eng hu &clientNames&, Beszélsz angolul?
  hadd -m13 da_eng nl &clientNames&, spreek je engels?
  hadd -m13 da_eng pt &clientNames&, você fala inglês?
  hadd -m13 da_eng it &clientNames&, lei parla inglese?

  hadd -m13 da_offq en &clientNames& how are these modules going?
  hadd -m13 da_offq de &clientNames& wie läuft es mit den Modulen?
  hadd -m13 da_offq ru &clientNames& Вам удалось выключить возможные модули, кроме "Системы жизнеобеспечения"?
  hadd -m13 da_offq es &clientNames& ¿Cómo van los módulos?
  hadd -m13 da_offq fr &clientNames& Comment se déroulent les modules ?
  hadd -m13 da_offq pt &clientNames& Como estão a correr os módulos?
  hadd -m13 da_offq zh &clientNames& 模块进展如何？
  hadd -m13 da_offq it &clientNames& Come vanno i moduli?
  hadd -m13 da_offq pl &clientNames& Jak ci idzie z modułami?
  hadd -m13 da_offq cs &clientNames& Jak se daří modulům?
  hadd -m13 da_offq tr &clientNames& Modüller nasıl gidiyor?
  hadd -m13 da_offq hu &clientNames& Hogy haladnak a modulok?
  hadd -m13 da_offq nl &clientNames& Hoe gaat het met deze modules?

  hadd -m13 da_sr en &clientNames& please disable Silent Running Immediately!  Default key: Delete, or in the Right side Holo Panel > SHIP tab > Functions Screen - Middle Right
  hadd -m13 da_sr de &clientNames& bitte deaktiviere sofort Schleichfahrt! Standardtaste dafür ist 'Entf'. Oder im rechten Holopanel, Registerkarte Schiff, in den Funktionen (Mitte rechts)
  hadd -m13 da_sr ru &clientNames& Пожалуйста, немедленно отключите функцию "Бесшумный ход"! Кнопка по умолчанию: DELETE или в правой панели: вкладка КОРАБЛЬ, экран ФУНКЦИИ, справа внизу.
  hadd -m13 da_sr es &clientNames& por favor, desactiva Navegación Silenciosa immediatamente! Tecla por defecto: Suprimir, o en el panel Derecho > Nave > Centro derecha.
  hadd -m13 da_sr fr &clientNames& désactivez immédiatement le Mode Furtif ! Touche par défaut : Suppr/Delete, ou alors dans le panneau de droite > onglet VAISSEAU > écran FONCTIONS - Millieu-droite.
  hadd -m13 da_sr pt &clientNames& por favor desabilite Nav. Silenciosa! Tecla padrão: Delete, ou no painel do Hologramaa no lado direito > aba NAVE > Tela Funções - No meio à direita
  hadd -m13 da_sr zh &clientNames& 请立即关闭Silent Running！默认键Delete，或者在右手边控制板>Ship页面>Functions页面-中间靠右的设置。
  hadd -m13 da_sr it &clientNames& per cortesia disattiva Silent Running immediatamente! Tasto di default Canc/Delete on nel pannello a destra Ship > Schermata funzioni a destra al centro
  hadd -m13 da_sr pl &clientNames& natychmiast wyłącz tryb 'SILENT RUNNING'! Domyślnie klawisz Delete albo prawy panel > zakładka SHIP > FUNCTIONS - z prawej strony po środku.
  hadd -m13 da_sr cs &clientNames& prosím, okamžitě deaktivuj tichý chod! standardní klávesa pro deaktivaci: Delete, nebo v pravém panelu > SHIP záložka > podzáložka Functions > uprostřed vpravo
  hadd -m13 da_sr tr &clientNames& Lütfen hemen sessiz çalışmayı (Silent Running) kapat!  Varsayılan tuş: Delete, veya sağ gemi kontrol panelinde > SHIP sekmesi > Functions ekranı - Sağ Orta
  hadd -m13 da_sr hu &clientNames& Kérlek azonnal kapcsold ki a Silent Running-t! Alapbeállítás: Delete gomb, vagy a jobb oldali holo panelen > SHIP > Functions lap, jobb oldalt középen
  hadd -m13 da_sr nl &clientNames& Schakel Silent Running onmiddellijk uit!  Standaard toets: Delete, of in het rechter Holo Panel > tabblad SHIP > Functiescherm - Midden rechts

  hadd -m13 da_o2 en &clientNames& do you see a "oxygen depleted in ..." timer in the top right of your HUD?
  hadd -m13 da_o2 de &clientNames& siehst du einen blauen "Sauerstoff leer in..." countdown oben rechts auf deinem HUD?
  hadd -m13 da_o2 ru &clientNames& вы видите таймер «Кислор. осталось на:» в правом верхнем углу экрана?
  hadd -m13 da_o2 es &clientNames& ves un mensaje de "Oxígeno Agotado en: " en la parte superior derecha de tu pantalla?
  hadd -m13 da_o2 fr &clientNames& voyez-vous un minuteur "Oxygène épuisé dans :" en haut à droite de votre cockpit ?
  hadd -m13 da_o2 pt &clientNames& você vê um temporizador com a mensagem "oxigênio esgotado em: " na parte superior direita da sua tela?
  hadd -m13 da_o2 zh &clientNames& 您是否看到上右角有"Oxygen Depleted In ..."的计时?
  hadd -m13 da_o2 it &clientNames& vedi una timer "Oxygen Depleted in:" in alto a destra dello schermo?
  hadd -m13 da_o2 pl &clientNames& czy pojawiło ci się odliczanie czasu tlenu „OXYGEN DEPLETED IN ...” w prawym górnym rogu ekranu?
  hadd -m13 da_o2 cs &clientNames& vidíš časovač "oxygen depleted in ..." v pravém horním rohu tvé obrazovky?
  hadd -m13 da_o2 tr &clientNames& Gemi ekranının (HUD) Sağ üst köşesinde "Oxygen depleted in:" yazan bir sayaç görüyor musun?
  hadd -m13 da_o2 hu &clientNames& Látsz egy 'Oxygen depleted in...' leszámoló stoppert a szem elé vetített kijelző felső jobb sarkában?
  hadd -m13 da_o2 nl &clientnames& Zie je een “oxygen depleted in ...” timer rechtsboven in je HUD?

  hadd -m13 da_navsys en &clientNames& please look in the left panel in the navigation tab and give me the full system name under "System" in the top left corner.
  hadd -m13 da_navsys de &clientNames& bitte schaue ins linke Panel im Navigationsreiter und sage mir den kompletten Systemnamen unter "System" in der oberen linken Ecke.
  hadd -m13 da_navsys ru &clientNames& пожалуйста, посмотрите на левую панель на вкладке навигации и дайте мне полное имя системы в разделе «Система» в верхнем левом углу.
  hadd -m13 da_navsys es &clientNames& mira en el panel izquierdo, en la pestaña de Navegación, y dime el nombre completo de tu sistema.
  hadd -m13 da_navsys fr &clientNames& veuillez aller dans votre panneau de gauche, onglet Navigation, puis envoyez-moi le nom complet écrit sous "Système", dans le coin en haut à gauche.
  hadd -m13 da_navsys pt &clientNames& por favor, olhe no painel à esquerda, na aba navegação e me dê o nome completo do sistema em "Sistema" no canto superior esquerdo.
  hadd -m13 da_navsys zh &clientNames& 请打开左手边控制板，打开Navigation页面，然后告诉我在System下面所写的星系名称。
  hadd -m13 da_navsys it &clientNames& per cortesia, guarda nel pannello a sinistra dello schermo di navigazione e comunica il nome completo del sistema che trovi nell'angolo in basso a sinistra alla voce "System".
  hadd -m13 da_navsys pl &clientNames& spójrz proszę w lewy panel, w zakładkę „NAVIGATION”(domyślnie klawisz 1) i podaj nam pełną nazwę układu gwiezdnego pod słowem „SYSTEM” w lewym górnym rogu.
  hadd -m13 da_navsys cs &clientNames& prosím, podívej se do levého panelu, do záložky Navigation a řekni mi celé jméno systému pod "system" v horním levém rohu
  hadd -m13 da_navsys tr &clientNames& Lütfen sol panelin Navigation sekmesine bakarak, sol üst köşedeki "System" yazısının altında bununan tam sistem adını söyler misin?
  hadd -m13 da_navsys hu &clientNames& Kérlek menj a bal panelhez,majd a navigation almenühöz, és add meg a teljes nevet, ami megjelenik a 'System' alatt a felső jobb sarokban.
  hadd -m13 da_navsys nl &clientNames& Kijk in het linkerpaneel op het navigatietabblad en geef me de volledige systeemnaam onder “System” in de linkerbovenhoek.

  hadd -m13 da_open en &clientNames& please exit to the main menu and log back in to OPEN play.
  hadd -m13 da_open de &clientNames& bitte gehe ins Hauptmenü und logge dich in OFFENES spiel ein.
  hadd -m13 da_open ru &clientNames& для заправки нам нужно, чтобы вы были в ОТКРЫТОЙ игре. Пожалуйста, выйдите в главное меню, а затем зайдите в ОТКРЫТУЮ игру.
  hadd -m13 da_open es &clientNames& por favor, sal al Menú Principal, y entra en Juego Abierto.
  hadd -m13 da_open fr &clientNames& veuillez retourner au menu principal, vous connecter en JEU OUVERT.
  hadd -m13 da_open pt &clientNames& por favor, saia para o menu principal e entre novamente em JOGO ABERTO.
  hadd -m13 da_open zh &clientNames& 请登出游戏，然后重新登入Open Play。
  hadd -m13 da_open it &clientNames& per cortesia, esci al menu principale e torna nel gioco in OPEN play.
  hadd -m13 da_open pl &clientNames& proszę wyloguj się do MAIN MENU i zaloguj się ponownie w trybie OPEN PLAY.
  hadd -m13 da_open cs &clientNames& prosím, jdi do hlavního menu a znovu se připoj do OPEN play.
  hadd -m13 da_open tr &clientNames& Lütfen ana menü'ye dön, oyuna OPEN PLAY'i seçerek tekrar giriş yap ve motorlarını (Thrusters) tekrar deaktive et.
  hadd -m13 da_open hu &clientNames& Kérlek lépj ki a fő menühöz és jelentkezz vissza az OPEN play-be.
  hadd -m13 da_open nl &clientNames& Verlaat het hoofdmenu en log weer in om OPEN play.

  hadd -m13 da_wing en &clientNames& back in your cockpit, please invite your rat(s) to a wing.
  hadd -m13 da_wing de &clientNames& bitte lade deine Ratte(n) vom cockpit aus in ein Geschwader ein.
  hadd -m13 da_wing ru &clientNames& теперь добавьте ваших заправщиков в крыло.
  hadd -m13 da_wing es &clientNames& ahora invita a tus ratas a Escuadrón.
  hadd -m13 da_wing fr &clientNames& maintenant, veuillez inviter votre/vos rat(s) dans une escadrille.
  hadd -m13 da_wing pt &clientNames& agora, por favor, convide seu(s) rato(s) para o esquadrão.
  hadd -m13 da_wing it &clientNames& per cortesia invita il/i tuo/i Rats in un "Wing".
  hadd -m13 da_wing zh &clientNames& 请把您的老鼠邀请到您的Wing。
  hadd -m13 da_wing pl &clientNames& proszę, zaproś swojego RAT-ownika(ów) do skrzydła (WING).
  hadd -m13 da_wing cs &clientNames& prosím pozvi krysy do letky
  hadd -m13 da_wing tr &clientNames& Şimdi, fare(leri)ni uçuş formasyonuna(wing'e) davet et.
  hadd -m13 da_wing hu &clientNames& Most kérlek hívd meg a patkányaidat egy wing-hez.
  hadd -m13 da_wing nl &clientNames& nodig nu je rat(ten) uit voor een wing.

  hadd -m13 da_team en &clientNames& back in your cockpit, please invite your rat(s) to a team.
  hadd -m13 da_team de &clientNames& bitte lade deine Ratte(n) vom cockpit aus in ein Team ein.
  hadd -m13 da_team ru &clientNames& теперь, пожалуйста, пригласите ваших крыс(у) в команду.
  hadd -m13 da_team es &clientNames& ahora, por favor invita a tu rata(s) a un equipo.
  hadd -m13 da_team fr &clientNames& maintenant, veuillez inviter votre/vos rat(s) dans une équipe.
  hadd -m13 da_team pt &clientNames& convide agora o(s) seu(s) rato(s) para o GRUPO.
  hadd -m13 da_team it &clientNames& ora, per cortesia, invita il/i tuo Rat/s in un team
  hadd -m13 da_team zh &clientNames& 現在，請您把您的老鼠（們）邀請到一個Team。
  hadd -m13 da_team pl &clientNames& proszę, zaproś swojego Rat-ownika(ów) do skrzydła (TEAM).
  hadd -m13 da_team cs &clientNames& Teď prosím pozvi svou/své krysu/y do týmu.
  hadd -m13 da_team tr &clientNames& Şimdi, fare(leri)ni uçuş formasyonuna(team'e) davet et.
  hadd -m13 da_team hu &clientNames& Most kérlek hívd meg a patkányod, vagy patkányaidat, a csapathoz.
  hadd -m13 da_team nl &clientnames& nodig nu je rat(ten) uit voor een team.

  hadd -m13 da_beacon en &clientNames& lastly, enable your beacon so your rat(s) can find you in system.
  hadd -m13 da_beacon de &clientNames& als letztes aktiviere dein Signal, damit deine Ratten dich finden können.
  hadd -m13 da_beacon ru &clientNames& и, наконец, включите, пожалуйста, маяк крыла, чтобы ваши заправщики смогли найти вас в системе.
  hadd -m13 da_beacon es &clientNames& por último, necesito que actives tu Baliza para que tus ratas te puedan encontrar.
  hadd -m13 da_beacon fr &clientNames& enfin, j'aurais besoin que vous allumiez votre balise d'escadrille afin que nos rats puissent vous trouver dans le système.
  hadd -m13 da_beacon pt &clientNames& e por fim eu preciso que você ligue seu sinalizador para que nosso(s) rato(s) possa(m) encontrá-lo no sistema
  hadd -m13 da_beacon it &clientNames& per finire, attiva il tuo beacon così i Rats possano trovarti
  hadd -m13 da_beacon zh &clientNames& 为了帮助您的老鼠定位，请启动您的Beacon。
  hadd -m13 da_beacon pl &clientNames& a na koniec, proszę, włącz nadajnik WING BEACON, aby Rat-ownik(cy) mógł ciebie odnaleźć.
  hadd -m13 da_beacon cs &clientNames& jako poslední věc, kterou po tobě zatím budu potřebovat je zapnutí majáku na křídlech, takhle tě budeme moci najít
  hadd -m13 da_beacon tr &clientNames& Son olarak, fare(leri)nin seni sistemde bulabilmesi için sinyalini(beacon) aç.
  hadd -m13 da_beacon hu &clientNames& Végül, kapcsold be a kötelékjeladódat  (beacon) hogy a patkányok rád találhassanak.
  hadd -m13 da_beacon nl &clientNames& Schakel ten slotte je baken in zodat je rat(ten) je kunnen vinden in het systeem.

  hadd -m13 da_ls en &clientNames& please turn your Life Support on immediately: go to the right menu -> Modules tab, select Life Support and select Activate
  hadd -m13 da_ls de &clientNames& bitte schalte deine Lebenserhaltung sofort wieder an: im rechten Menü -> Reiter Module, wähle die Lebenserhaltung aus und wähle aktivieren
  hadd -m13 da_ls ru &clientNames& НЕМЕДЛЕННО включите вашу "Систему жизнеобеспечения": откройте правое меню, вкладка МОДУЛИ, выберите "Система жизнеобеспечения" и выберите "Активировать"!
  hadd -m13 da_ls es &clientNames& activa tu Soporte Vital immediatamente: menu derecho -> Modulos -> selecciona Soporte Vital, y Activar.
  hadd -m13 da_ls fr &clientNames& veuillez immédiatement rallumer vos Systèmes de Survie : allez dans le panneau de droite -> onglet Modules -> sélectionnez vos Systèmes de Survie, puis activez-les.
  hadd -m13 da_ls pt &clientNames& por favor ligue seu suporte de vida imediatamente: vá ao menu da direita -> aba módulos, selecione Suporte de Vida e selecione Inativo
  hadd -m13 da_ls zh &clientNames& 请立即启动您的Life Support:打开右手边控制板，打开Modules页面，选择Life Support，然后选择Activate。
  hadd -m13 da_ls it &clientNames& per cortesia attiva "Life Support" immediatamente: vai nel menu a destra -> Modules , seleziona "Life support" e poi "Activate"
  hadd -m13 da_ls pl &clientNames& natychmiast włącz LIFE SUPPORT! Prawy panel (domyślnie klawisz 4) -> zakładka MODULES, wybierz ‘LIFE SUPPORT’ po czym wybierz 'ACTIVE'.
  hadd -m13 da_ls cs &clientNames& prosím ihned si zapni Life support: jdi do pravého panelu -> záložka modules, vyber life support a dej activate
  hadd -m13 da_ls tr &clientNames& Hemen Life Support'u aktive et: Sağ menüye git -> Modules sekmesi, Life Support'u seç ve Activate'e bas.
  hadd -m13 da_ls hu &clientNames& Kérlek azonnal kapcsold be a Life support-odat: menj a jobb menühöz, majd a Modules almenühöz, válaszd a Life Support-ot, majd azt, hogy Activate
  hadd -m13 da_ls nl &clientNames& Schakel uw Life Support onmiddellijk in: ga naar het rechtermenu -> tabblad Modules, selecteer Life Support en selecteer Activate.

  hadd -m13 da_crm en &clientNames& from THIS point onwards, remain logged out in the Main Menu please! Do NOT login until I give you the "GO GO GO" command.
  hadd -m13 da_crm de &clientNames& bleib bitte ab jetzt im Hauptmenü! Logge dich NICHT ein bis ich dir das "GO GO GO" Kommando gebe.
  hadd -m13 da_crm ru &clientNames& с этого момента, пожалуйста, оставайтесь в главном меню. НЕ входите в игру, пока я не дам вам команду "GO GO GO"!
  hadd -m13 da_crm es &clientNames& desde este punto en adelante, quedate en el Menú Principal. NO entres en el juego hasta que no te diga "GO GO GO".
  hadd -m13 da_crm fr &clientNames& à partir de maintenant, veuillez rester dans le Menu Principal ! NE vous connectez SURTOUT PAS tant que je ne vous envoie pas un "GO GO GO".
  hadd -m13 da_crm pt &clientNames& DESTE ponto em diante, por favor, permaneça deslogado na tela do menu principal! NÃO entre até que eu dê à você o comando "GO GO GO".
  hadd -m13 da_crm zh &clientNames& 从现在开始，请留在游戏主页面！在我在说“GO GO GO”之前，不要登入游戏。
  hadd -m13 da_crm it &clientNames& da questo punto, rimani sulla schermata del menu principale! NON rientrare nel gioco finchè non ti dò il comando "GO GO GO"
  hadd -m13 da_crm pl &clientNames& od tej chwili POZOSTAŃ cały czas w MAIN MENU. Pod żadnym pozorem nie loguj się do gry, dopóki nie napiszę 'GO GO GO'.
  hadd -m13 da_crm cs &clientNames& od TÉTO chvíle, zůstaň prosím v hlavním menu! NEPŘIPOJUJ se dokud ti nedám povel "GO GO GO"
  hadd -m13 da_crm tr &clientNames& Şu andan itibaren, oyundan çıkmış olduğun ana menüden AYRILMA! Ben "GO GO GO" Komutunu verene kadar oyuna GIRME.
  hadd -m13 da_crm hu &clientNames& Ettől a ponttól kezdve, kérlek maradj kijelentkezve a főmenüben! Ne jelentkezz vissza amíg nem adom meg rá a jelet: 'GO GO GO'
  hadd -m13 da_crm nl &clientnames& Blijf vanaf dit punt uitgelogd in het hoofdmenu! Log NIET in totdat ik je het “GO GO GO” commando geef.

  hadd -m13 da_mmconf en &clientNames& please confirm that you've quit to main menu where you can see your ship in the hangar.
  hadd -m13 da_mmconf de &clientNames& bitte bestätige, dass du im Hauptmenü bist wo du dein Schiff im Hangar siehst.
  hadd -m13 da_mmconf ru &clientNames& пожалуйста, подтвердите, что вы вышли в "Главное меню" игры, где вы можете видеть ваш корабль в ангаре.
  hadd -m13 da_mmconf es &clientNames& por favor, confirmame que estas en el Menú Principal, donde ves tu nave en el hangar.
  hadd -m13 da_mmconf fr &clientNames& veuillez confirmer que vous êtes retourné au menu principal où vous pouvez voir votre vaisseau dans le hangar.
  hadd -m13 da_mmconf pt &clientNames& por favor, confirme que você saiu para o menu principal, onde é possível ver sua nave no hangar
  hadd -m13 da_mmconf zh &clientNames& 请确认您已退出到游戏主页面，并且能看到您的飞船停靠在空间站里面。
  hadd -m13 da_mmconf it &clientNames& per cortesia conferma che sei uscito al menu principale da cui puoi vedere la tua nave nell'hangar.
  hadd -m13 da_mmconf pl &clientNames& czy wylogowałeś się już do MAIN MENU, tam gdzie widać statek w hangarze?
  hadd -m13 da_mmconf cs &clientNames& prosím potvrď že jsi v hangáru kde vidíš svou loď.
  hadd -m13 da_mmconf tr &clientNames& Lütfen gemini hangarda görebildiğin ana menü'de olduğunu onayla.
  hadd -m13 da_mmconf hu &clientNames& Kérlek adj visszaigazolást, hogy kijelentkeztél a fő menüig, és látod a hajódat a hangárban
  hadd -m13 da_mmconf nl &clientNames& Controleer of je naar het hoofdmenu bent gegaan waar je je schip in de hangar kunt zien.

  hadd -m13 da_mmsys en &clientNames& staying in the main menu, can you confirm your full system name including any sector name? Look in the upper right below your CMDR name where it says / IDLE
  hadd -m13 da_mmsys de &clientNames& kannst du bitte deinen kompletten Systemnamen mit Sektornamen bestätigen? Schaue im Hauptmenü in die obere rechte Ecke unter deinen Kommandantennamen wo / Untätig steht.
  hadd -m13 da_mmsys ru &clientNames& оставаясь в "Главном меню", можете ли вы мне сказать полное название вашей системы, включая название сектора, если оно есть? Посмотрите в правый верхний угол экрана, под вашим именем, где написано / На холостом ходу
  hadd -m13 da_mmsys es &clientNames& quedándote en el Menú Principal, puedes confirmar el nombre completo del sistema, incluyendo el nombre del Sector? Esquina superior derecha, al lado de tu nombre / INACTIVO
  hadd -m13 da_mmsys fr &clientNames& en restant dans le menu principal, pouvez-vous confirmer le nom de votre système complet, en incluant le nom du scteur ? Vous le trouverez en haut à droite, sous votre nom de CMD, où est indiqué / INACTIF
  hadd -m13 da_mmsys pt &clientNames& Permanecendo no menu principal, você pode confirmar o nome completo do seu sistema, incluindo qualquer nome de setor. Veja no canto superior direito, abaixo do seu nome CMDT, onde diz / INATIVO
  hadd -m13 da_mmsys zh &clientNames& 请您留在主页面，然后告诉我您在上右角在/IDLE旁边看到的星系名字。
  hadd -m13 da_mmsys it &clientNames& Rimanendo nel menu principale, puoi confermare il nome completo del sistema incluso il nome del settore? Guarda in alto a destra sotto al tuo nome CMDR dove c'è scritto "IDLE"
  hadd -m13 da_mmsys pl &clientNames& pozostając w MAIN MENU podaj jeszcze raz pełną nazwę SYSTEMU wraz z sektorem. Można ją zobaczyć w prawym górnym rogu pod nazwą twojego CMDR obok słowa IDLE.
  hadd -m13 da_mmsys cs &clientNames& aniž by ses připojil, můžeš potvrdit celé jméno systému ve kterém jsi včetně jméno sektoru? mělo by to být v horní pravé části pod jméno tvého kapitána (CMDR) kde stojí / IDLE
  hadd -m13 da_mmsys tr &clientNames& Ana menü'den ayrılmayarak, tam sistem ismini sektör ismi dahil olarak onaylayabilir misin? Sağ üst köşede, CMDR isminin altında / IDLE yazan yere bak.
  hadd -m13 da_mmsys hu &clientNames& A fő menüben maradva, meg adnád kérlek ismét a teljes rendszer neved (sector névvel) együtt? Keresd a felső jobb sarokban a CMDR neved alatt, ahol az áll, hogy /IDLE
  hadd -m13 da_mmsys nl &clientNames& Als je in het hoofdmenu blijft, kun je dan je volledige systeemnaam bevestigen, inclusief een eventuele sectornaam? Kijk rechtsboven onder je CMDR naam waar staat / IDLE

  hadd -m13 da_cro2 en &clientNames& without logging in, do you remember how much O2 you had left?
  hadd -m13 da_cro2 de &clientNames& ohne dich einzuloggen, kannst du dich erinnern, wie viel Zeit noch auf dem Sauerstofftimer war?
  hadd -m13 da_cro2 ru &clientNames& не заходя в игру, чтобы проверить, могли бы вы сказать - сколько времени оставалось на вашем таймере кислорода?
  hadd -m13 da_cro2 es &clientNames& sin entrar a comprobarlo, te acuerdas de cuánto Oxígeno te quedaba?
  hadd -m13 da_cro2 fr &clientNames& sans vous reconnecter, vous souvenez-vous de combien de temps il vous restait sur le minuteur d'oxygène ?
  hadd -m13 da_cro2 pt &clientNames& sem entrar para checar, você se lembra de quanto tempo restante tinha de O2?
  hadd -m13 da_cro2 zh &clientNames& （请不要登入查看）您记得您还有多长时间的氧气吗？
  hadd -m13 da_cro2 it &clientNames& senza rientrare nel gioco, ricordi quanto ossigeno avevi rimasto?
  hadd -m13 da_cro2 pl &clientNames& Nie wchodząc do gry, czy pamiętasz mniej więcej na ile czasu zostało ci tlenu?
  hadd -m13 da_cro2 cs &clientNames& bez toho aniž by ses připojil, pamatuješ si kolik ti zbývalo kyslíku?
  hadd -m13 da_cro2 tr &clientNames& Oyuna girmeden, ne kadar oksijen kaldığını hatırlıyabiliyor musun?
  hadd -m13 da_cro2 hu &clientNames& Bejelentkezés nélkül, emlékszel arra, hogy mennyi Oxigéned maradt?
  hadd -m13 da_cro2 nl &clientNames& zonder in te loggen, weet je dan nog hoeveel zuurstof je over had?

  hadd -m13 da_crpos en &clientNames& without logging in, can you remember WHERE in the system you were? By the star, a planet or station or on the way to one?
  hadd -m13 da_crpos de &clientNames& ohne dich einzuloggen, kannst du dich erinnern WO im System du warst? In der Nähe von einem Stern oder auf dem Weg zu einer Station oder Planet?
  hadd -m13 da_crpos ru &clientNames& не заходя в игру, чтобы проверить, не могли бы вы сказать мне, где в системе вы находились, когда у вас кончилось топливо? Рядом со звездой, планетой, станцией или на пути к ней?
  hadd -m13 da_crpos es &clientNames& sin entrar a comprobarlo, te acuerdas de DÓNDE dentro del sistema estabas? Cerca de la estrella o algun planeta o estacion?
  hadd -m13 da_crpos fr &clientNames& sans vous reconnecter, vous souvenez-vous de votre position dans le système ? Vers une étoile, une planète, une station, ou en route vers l'une de ces choses ?
  hadd -m13 da_crpos pt &clientNames& sem entrar, você se lembra ONDE estava no sistema? Próximo à estrela, um planeta ou estação ou à caminho de algum deles?
  hadd -m13 da_crpos zh &clientNames& （请不要登入查看）您记得您在星系里的位置吗？在恒星，星球，或者空间站旁边或者途中？
  hadd -m13 da_crpos it &clientNames& senza rientrare nel gioco, ricordi DOVE eri nel sistema? Vicino alla stella, un pianeta, una stazione spaziale o viaggiando verso una?
  hadd -m13 da_crpos pl &clientNames& Nie wchodząc do gry, czy pamiętasz mniej więcej GDZIE znajdowałeś się w SYSTEMIE? W okolicach głównej gwiazdy, czy w drodze do konkretnej planety lub stacji (jeśli tak to do której)?
  hadd -m13 da_crpos cs &clientNames& bez toho aniž by ses připojil, pamatuješ si KDE jsi byl? vedle hvězdy, planety, stanici, nebo na cestě k ní?
  hadd -m13 da_crpos tr &clientNames& Oyuna girmeden, bulunduğun sistemin içerisinde NEREDE olduğunu hatırlıyor musun? Bir yıldızın, gezegenin veya bir istasyonun yanında, ya da bunlara doğru gidiyor muydun?
  hadd -m13 da_crpos hu &clientNames& Bejelentkezés nélkül, emlékszel arra, hogy a rendszeren belül hol voltál? A csillagnál, egy bolygó vagy állomásnál, vagy úton ezeknek egyike felé?
  hadd -m13 da_crpos nl &clientNames& Kun je je zonder in te loggen herinneren WAAR in het systeem je was? Bij de ster, een planeet of station of op weg ernaartoe?

  hadd -m13 da_crgo en GO GO GO! &clientName& 1. Login to OPEN - 2. light your beacon - 3. invite your rats &rats& to a wing - 4. report your o2 time in this chat and be ready to logout if I tell you to.
  hadd -m13 da_crgo de GO GO GO! &clientName& 1. logge dich in OFFENES Spiel ein - 2. aktiviere dein Geschwadersignal - 3. lade deine Ratten &rats& in ein Geschwader ein. - 4. schreibe hier wie viel Zeit noch auf dem Sauerstofftimer ist und mache dich bereit aus zu loggen, wenn ich es sage.
  hadd -m13 da_crgo ru GO GO GO! &clientName& 1 – Войдите в ОТКРЫТУЮ игру, 2 – установите Маяк на КРЫЛО, 3 – Пригласите в крыло ваших заправщиков &rats&, 4 – сообщите время на таймере здесь и будьте готовы выйти, если я скажу.
  hadd -m13 da_crgo es GO GO GO! &clientName& 1. Entra en JUEGO ABIERTO - 2. activa tu Baliza - 3. invita a tus ratas &rats& a Escuadrón - 4. informame de tu temporizador de Oxígeno en este chat y prepárate para salir al Menú si te lo digo.
  hadd -m13 da_crgo fr GO GO GO! &clientName& 1. Connectez-vous en JEU OUVERT - 2. Allumez votre balise d'escadrille - 3. Invitez vos rats &rats& dans une escadrille - 4. Rapportez votre temps d'oxygène dans ce tchat et préparez-vous à vous déconnecter si je vous le demande.
  hadd -m13 da_crgo pt GO GO GO! &clientName& 1. Entre em JOGO ABERTO - 2. Ligue seu sinalizador - 3. Convide seu(s) rato(s) &rats& para o esquadrão - 4. Informe o tempo restante de o2 neste chat e fique preparado para sair se eu assim disser.
  hadd -m13 da_crgo zh ＧＯ　ＧＯ　ＧＯ！ &clientName& １：登入Open　Play　－　２.启动您的Beacon　－　３.邀请您的老鼠 &rats& 到您的Wing - 4.在这里告诉我您剩下的氧气，并且如果我指示您再次登出的话，马上登出。
  hadd -m13 da_crgo it GO GO GO! &clientName& 1.Entra in OPEN - 2. attiva il Beacon - 3. Invita i/il Rats &rats& a un "Wing" - 4. Comunica il tempo rimasto nel tuo timer dell'ossigeno in questa chat e sii pronto a uscire dal gioco se te lo dico.
  hadd -m13 da_crgo pl GO GO GO! &clientName& 1. Zaloguj się do OPEN PLAY 2. Włącz BEACON. 3. Zaproś swojego RAT-ownika(ów) &rats& do skrzydła (WING) 4. Podaj tutaj na czacie na jak długo zostało ci tlenu i przygotuj się na szybkie wylogowanie jak tylko ci powiemy.
  hadd -m13 da_crgo cs GO GO GO! &clientName& 1. připoj se do OPEN play - 2. rozsviť svůj maják na křídle - 3. pozvi své krysy &rats& do křídla - 4. řekni mi kolik ti zbývá kyslíku a buď připraven na to se odpojit pokud ti to řeknu
  hadd -m13 da_crgo tr GO GO GO! &clientName& 1. OPEN PLAY'a giriş yap - 2. Sinyalini (Beacon) aç - 3. Farelerini &rats& formasyona(wing) davet et - 4. kalan oksijen sayacını bu kanala yaz ve eğer söylersem oyundan çıkmaya hazır ol.
  hadd -m13 da_crgo hu GO GO GO! &clientName& 1. Jelentkezz be az OPEN-be 2. Kapcsold be a beacon-t 3. Hívd meg a patkányaidat &rats& egy wing-hez 4. Jelentsd, menyi oxigéned maradt ebben a chatben és állj készen kijelentkezni amikor szólok.
  hadd -m13 da_crgo nl GO GO GO! &clientName& 1. Login op OPEN - 2. Steek je baken aan - 3. Nodig je ratten &rats& uit voor een wing - 4. Meld je o2-tijd in deze chat en wees klaar om uit te loggen als ik je dat zeg.

  hadd -m13 da_crgoody en GO GO GO! &clientName& 1. Login to OPEN - 2. invite your rat(s) &rats& to a Team - 3. make sure your beacon is set to Team - 4. report your o2 time in this chat and only logout when you're told to.
  hadd -m13 da_crgoody de GO GO GO! &clientName& 1. logge dich in OFFENES Spiel ein - 2. lade deine Ratte(n) &rats& in ein Team ein. - 3. prüfe, ob dein Teamsignal auf TEAM steht - 4. schreibe hier wie viel Zeit noch auf dem Sauerstofftimer ist und logge dich erst aus wenn ich es dir sage.
  hadd -m13 da_crgoody ru GO GO GO! &clientName& 1 – Войдите в ОТКРЫТУЮ игру, 2 – Пригласите ваших заправщиков &rats& в Команду, 3 – Убедитесь, что ваш маяк переключен на Команду - 4. сообщите время на таймере здесь и будьте готовы выйти, если я скажу.
  hadd -m13 da_crgoody es GO GO GO! &clientName& 1. Ingrese en Juego Abierto - 2. Invite a sus ratas &rats& a un Equipo - 3. Asegúrese de tener su baliza en Equipo - 4. Reporte el tiempo de oxygeno en este chat y esté listo para desconectarse si se lo digo.
  hadd -m13 da_crgoody fr GO GO GO! &clientName& 1. Connectez-vous en JEU OUVERT - 2. Invitez vos rats &rats& dans l'équipe - 3. Vérifiez que la balise est réglée sur Équipe. - 4. Rapportez votre temps d'oxygène dans ce tchat et préparez-vous à vous déconnecter si je vous le demande.
  hadd -m13 da_crgoody pt GO GO GO! &clientName& 1. Vai para ABERTO – 2. convide os ratos &rats& para o grupo - 3. Certifique-se de que o seu sinalizador está preparado para Equipa  4. informe o seu o2 tempo neste chat e esteja pronto para sair se eu lhe disser para.
  hadd -m13 da_crgoody zh GO GO GO！ &clientName& 1：登入Open Play - 2.邀請您的老鼠 &rats& 到您的Team - 3.確保您的Beacon設定成Team模式 - 4.在這裏告訴我您剩下的氧氣，如果我指示您再次登出，請馬上登出。
  hadd -m13 da_crgoody it GO GO GO! &clientName& 1. Entra in OPEN- 2. invita i tuoi rats &rats& in un team - 3. assicurati che il BEACON sia impostato su TEAM 4. riporta il timer O2 in questa chat e sii pronto a fare logout se ti viene detto.
  hadd -m13 da_crgoody pl GO GO GO！ &clientName& 1. Zaloguj się w trybie OPEN PLAY - 2. Zaproś wszystkich przydzielonych Rat-owników &rats& do drużyny 3. Upewnij się że nadajnik jest w trybie TEAM 4. Podaj tu czas na liczniku tlenu i bądź gotowy szybko się wylogować gdybym dał takie polecenie.
  hadd -m13 da_crgoody cs GO GO GO! &clientName& 1. Připoj se do OPEN PLAY - 2. pozvi své krysy &rats& do týmu - 3. ujisti se že tvůj maják je přepnutý na "team" - 4. napiš mi kolik ti zbývá času na odpočtu kyslíku, je možné že budu potřebovat aby jsi se odpojil ze hry, takže se dívej do tohoto chatu.
  hadd -m13 da_crgoody tr GO GO GO! &clientName& 1. OPEN PLAY'a giriş yap - 2. Farelerini &rats& formasyona(team) davet et - 3. BEACON'un TEAM olarak ayarlandığından emin olun - 4. Kalan oksijen sayacını bu kanala yaz ve eğer söylersem oyundan çıkmaya hazır ol.
  hadd -m13 da_crgoody hu GO GO GO! &clientName& 1. Jelentkezz be az OPEN-be 2. Hívd meg a patkányaidat &rats& egy team-hez 3. Ellenőrizze, hogy a jeladó TEAM-re van-e állítva. 4. Jelentsd, menyi oxigéned maradt ebben a chatben és állj készen kijelentkezni amikor szólok.
  hadd -m13 da_crgoody nl GO GO GO! &clienName& 1. Login op OPEN - 2. nodig je rat(s) &rats&- uit voor een team - 3. steek je baken aan - 4. meld je o2-tijd in deze chat en wees klaar om uit te loggen als ik dat zeg.

  hadd -m13 da_crinst en &clientNames& Once you get told (NOT NOW!), please log into OPEN PLAY, INVITE all your assigned Rats to a Team and finally make sure your BEACON is set to TEAM!
  hadd -m13 da_crinst de &clientNames& Sobald es dir gesagt wird, (NICHT JETZT!) logge dich bitte in OFFENES SPIEL (OPEN PLAY) ein, lade alle deine zugewiesenen Rats zu deinem Team ein und prüfe, ob dein SIGNAL auf TEAM steht!
  hadd -m13 da_crinst ru &clientNames& По нашему сигналу (НЕ СЕЙЧАС!) нам нужно, чтобы вы вошли в ОТКРЫТУЮ игру, пригласили всех назначенных спасателей в КОМАНДУ и убедились что МАЯК переключен на КОМАНДУ.
  hadd -m13 da_crinst es &clientNames& Una vez se lo digan (NO AHORA!), por favor ingrese en JUEGO ABIERTO, INVITE a todas las ratas asignadas a un Equipo y finalmente asegure que la BALIZA este en EQUIPO!
  hadd -m13 da_crinst fr &clientNames& Quand je vous le dirais (PAS MAINTENANT !), connectez-vous en mode JEU OUVERT, INVITEZ tous les rats qui vous sont assignés à une equipe et enfin vérifiez que la BALISE est réglée sur ÉQUIPE !
  hadd -m13 da_crinst pt &clientNames& assim que lhe for dito (NÃO AGORA!), por favor entre em ABERTO, CONVITE todos os Ratos que lhe foram atribuídos a uma Equipa e finalmente certifica-te de que o teu SINALIZADOR está pronto para o GRUPO!
  hadd -m13 da_crinst zh &clientNames& 請在我指示您的時候（不是現在！）登入OPEN游戲模式，邀請您的所有老鼠進入您的TEAM，最後確保您的BEACON設定成TEAM模式！
  hadd -m13 da_crinst it &clientNames& quando ti viene detto(NON ORA!), per cortesia entra in OPEN PLAY, INVITA tutti i Rats a te assegnati in un Team e infine assicurati che il tuo BEACON sia impostato su TEAM!
  hadd -m13 da_crinst pl &clientNames& Kiedy cię o to poproszę (NIE TERAZ!), zaloguj się w trybie OPEN PLAY, zaproś wszystkich przydzielonych Rat-owników do drużyny i upewnij się że nadajnik (BEACON) jest w trybie TEAM!
  hadd -m13 da_crinst cs &clientNames& Až ti řeknu (NE TEĎ!), prosím připoj se do OPEN PLAY, POZVI všechny krysy které ti byly přiřazeny do týmu a nakonec se ujisti, že je tvůj maják (BEACON) přepnutý na TEAM!
  hadd -m13 da_crinst tr &clientNames& Size söylendiğinde (ŞİMDİ DEĞİL!), lütfen OPEN PLAY'e tıklayıp oyuna giriş yapın, size atanmış Fare'yi formasyona(TEAM) davet edin edip BEACON'un TEAM olarak ayarlandığından emin olun
  hadd -m13 da_crinst hu &clientNames& Amikor szólunk (nem most azonnal!) kérlek jelentkezz be az OPEN PLAY-be, INVITE-old az összes rád osztott patkányt egy TEAM-hez és végül ellenőrizze, hogy a TEAM jeladó aktiválva van-e!
  hadd -m13 da_crinst nl &clientNames& Zodra je het te horen krijgt (NIET NU!), log dan in op OPEN SPELEN, NODIG al je toegewezen ratten uit in een team en zorg ervoor dat je BEACON op TEAM staat!

  hadd -m13 da_crinstleg en &clientNames& Once you get told (NOT NOW!), please log into OPEN PLAY, enable your WING BEACON and finally INVITE all your assigned Rats to a Wing!
  hadd -m13 da_crinstleg de &clientNames& Sobald es dir gesagt wird, (NICHT JETZT!) logge dich bitte in OFFENES SPIEL (OPEN PLAY) ein, setzte dein SIGNAL auf GESCHWADER und lade alle deine zugewiesenen Rats zu deinem Geschwader ein!
  hadd -m13 da_crinstleg ru &clientNames& По нашему сигналу (НЕ СЕЙЧАС!) нам нужно чтобы вы вошли в ОТКРЫТУЮ игру, включили МАЯК КРЫЛА и только после этого пригласили всех назначенных спасателей в КРЫЛО.
  hadd -m13 da_crinstleg es &clientNames& Cuando te lo digamos (AHORA NO!), por favor entra en JUEGO ABIERTO, activa tu BALIZA DE ESCUADRÓN y finalmente INVITA a tus ratas al escuadrón!
  hadd -m13 da_crinstleg fr &clientNames& Quand nous vous le dirons (PAS MAINTENANT ! ), connectez-vous en mode JEU OUVERT, activez votre BALISE D'ESCADRILLE et ensuite INVITEZ tous les rats qui vous sont assignés à une escadrille.
  hadd -m13 da_crinstleg pt &clientNames& Quando lhe dissermos (MAS NÃO AGORA!), por favor entre no jogo aberto, ative seu SINALIZADOR e, então, CONVIDE todos os Ratos do seu caso para um ESQUADRÃO!
  hadd -m13 da_crinstleg zh &clientNames& 請在我指示您的時候（不是現在！）登入OPEN游戲模式，啓動您的BEACON，最後邀請您的所有老鼠進入您的WING！
  hadd -m13 da_crinstleg it &clientNames& Quando ti viene detto (NON ORA), accedi in modalità GIOCO APERTO, attiva il tuo WING BEACON (faro per il gruppo di volo) e invita tutti i ratti a te assegnati alla tua WING (gruppo di volo)!
  hadd -m13 da_crinstleg pl &clientNames& Kiedy zostaniesz poproszony (NIE TERAZ!), zaloguj się w trybie OTWARTEJ GRY, włącz swój NADAJNIK SKRZYDŁOWY i ZAPROŚ wszystkich przydzielonych Rat-owników do skrzydła!
  hadd -m13 da_crinstleg cs &clientNames& až ti řeknu (NE TEĎ!), prosím připoj se do Open Play, zapni WING BEACON a nakonec pozvi tobě přidělené krysy do letky!
  hadd -m13 da_crinstleg tr &clientNames& Size söylendiği zaman (ŞİMDİ DEĞİL!), lütfen OPEN PLAY’e tıklayıp oyuna giriş yapın, WING BEACON'ı aktive edip size atanmış olan tüm Fareleri formasyona davet edin.
  hadd -m13 da_crinstleg hu &clientNames& Amikor majd szólunk (NEM most azonnal!), jelentkezz be OPEN PLAY-be, kapcsold be a WING BEACON-t, majd hívd az összes rád osztott patkányt egy WING-be.
  hadd -m13 da_crinstleg nl &clientNames& Zodra je het signaal krijgt moet je het volgende doen (NOG NIET UITVOEREN), log alsjeblieft in in OPEN PLAY, activeer je WING BEACON, en als laatste verstuur een INVITE WING aan alle geassigneerde ratten!

  hadd -m13 da_crvideo en &clientNames& here is a short video on how to do it: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo de &clientNames& hier ist ein kurzes Video dazu: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo ru &clientNames& вот ссылка на небольшое видео о том, как это сделать: https://fuelrats.cloud/s/DgZmtnJqai77Qwk
  hadd -m13 da_crvideo es &clientNames& aqui hay un vídeo corto de como hacerlo: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo fr &clientNames& voici une courte vidéo sur la manière de procéder : https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo pt &clientNames& aqui está um vídeo curto sobre como proceder: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo zh &clientNames& 以下视频会示范如何操作:https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo it &clientNames& quì c'è un breve video che spiega come farlo: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo pl &clientNames& tu możesz zobaczyć krótki filmik jak to sprawnie zrobić: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo cs &clientNames& tady máš krátké video jak to udělat: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo tr &clientNames& Nasıl yapabileceğine dair kısa bir video: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo hu &clientNames& Itt található egy rövid videó  ami megmutatja, hogyan kell csinálni: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X
  hadd -m13 da_crvideo nl &clientNames& Hier is een korte video over hoe het moet: https://fuelrats.cloud/s/YYzSy2K2QKPfr4X

  hadd -m13 da_crvideoody en &clientNames& here is a short video on how to do it: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody de &clientNames& hier ist ein kurzes Video dazu: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody ru &clientNames& вот ссылка на небольшое видео о том, как это сделать: https://t.fuelr.at/odycrru
  hadd -m13 da_crvideoody es &clientNames& aqui hay un vídeo corto de como hacerlo: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody fr &clientNames& voici une courte vidéo sur la manière de procéder : https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody pt &clientNames& aqui está um vídeo curto sobre como proceder: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody zh &clientNames& 以下视频会示范如何操作:https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody it &clientNames& quì c'è un breve video che spiega come farlo: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody pl &clientNames& tu możesz zobaczyć krótki filmik jak to sprawnie zrobić: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody cs &clientNames& tady máš krátké video jak to udělat: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody tr &clientNames& Nasıl yapabileceğine dair kısa bir video: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody hu &clientNames& Itt található egy rövid videó  ami megmutatja, hogyan kell csinálni: https://t.fuelr.at/odycr
  hadd -m13 da_crvideoody nl &clientNames& Hier is een korte video over hoe het moet: https://t.fuelr.at/odycr

  hadd -m13 da_eta en &clientName& your rat will be with you in about &eta& minutes, if you see a blue oxygen timer pop up at any time tell me immediately.
  hadd -m13 da_eta de &clientName& deine Ratten sind in etwa &eta& Minuten da, falls ein blauer Sauerstofftimer auftaucht sage mir sofort Bescheid.
  hadd -m13 da_eta ru &clientName& ваши заправщики будут у вас примерно через &eta& минут(ы), если у вас появится таймер отчёта кислорода сразу же сообщите мне.
  hadd -m13 da_eta es &clientName& tus ratas llegaran en aproximadamente &eta& minuto(s), si ves un temporizador de Oxígeno, avisame immediatamente.
  hadd -m13 da_eta fr &clientName& vos rats seront avec vous dans environ &eta& minute(s), si vous voyez un minuteur d'oxygène bleu apparaitre dites-le-moi immédiatement.
  hadd -m13 da_eta pt &clientName& seu(s) rato(s) estará(ão) com você em aproximadamente &eta& minuto(s), se aparecer o temporizador azul de oxigênio esgotado em qualquer momento, diga-me imediatamente.
  hadd -m13 da_eta zh &clientName& 您的老鼠预计会在 &eta& 分钟后到达。如果您在这时间段看到上右角出现一个蓝色氧气计时，请立即通知我们。
  hadd -m13 da_eta it &clientName& i Rats saranno con te in circa &eta& minuti, se vedi un timer blu dell'ossigeno comparire dimmelo immediatamente.
  hadd -m13 da_eta pl &clientName& Rat-ownik(cy) doleci do ciebie za ok &eta& minut(y), gdyby w którymkolwiek momencie pojawił się NIEBIESKI LICZNIK TLENU to proszę mnie od razu o tym POINFORMOWAĆ.
  hadd -m13 da_eta cs &clientName& tvé krysy u tebe budou za cca &eta& minut, pokud uvidíš že se objevil modrý časovač s kyslíkem tak nás ihned kontaktuj.
  hadd -m13 da_eta tr &clientName& Farelerin &eta& dakika sonra seninle olacaklar, eğer mavi bir oksijen sayacı çıkarsa bana hemen haber ver.
  hadd -m13 da_eta hu &clientName& A patkányaid veled lesznek kb &eta& perc múlva, ha közben megjelenik egy kék oxigén stopper kérlek rögtön szólj.
  hadd -m13 da_eta nl &clientnames& Je ratten zullen bij je zijn in ongeveer &eta& minuten, als je op enig moment een blauwe zuurstoftimer ziet verschijnen, laat het me dan meteen weten.

  hadd -m13 da_sc en &clientNames& looks like you're too close to a stellar body, please do the following:
  hadd -m13 da_sc de &clientNames& scheint als wärst du zu nah an einem Himmelskörper, bitte mache das folgende:
  hadd -m13 da_sc ru &clientNames& похоже, вы слишком близко к звёздному телу. Пожалуйста, выполните следующее:
  hadd -m13 da_sc es &clientNames& parece que estas muy cerca de un cuerpo estelar, por favor, haz esto:
  hadd -m13 da_sc fr &clientNames& il semblerait que vous soyez trop proche d'un corps céleste, veuillez suivre ces instructions :
  hadd -m13 da_sc pt &clientNames& parece que você está muito próximo de um corpo estelar, por favor faça o seguinte:
  hadd -m13 da_sc it &clientNames& sembra che tu sia troppo vicino ad un oggetto celeste, per cortesia segui queste istruzioni:
  hadd -m13 da_sc zh &clientNames& 您离恒星太近了，请：
  hadd -m13 da_sc pl &clientNames& Wygląda na to że zbyt blisko podleciałeś do ciała niebieskiego, proszę, wykonaj następujące czynności:
  hadd -m13 da_sc cs &clientNames& vypadá to, že jsi moc blízko u hvězdného tělesa, prosím udělej následující:
  hadd -m13 da_sc tr &clientNames& Bir gök cismine çok yakınsın, lütfen aşağıdakileri uygula:
  hadd -m13 da_sc hu &clientNames& Úgy tűnik, hogy túl közel vagy egy égi testhez. Kérlek tedd a következőt:
  hadd -m13 da_sc nl &clientNames& Het lijkt erop dat je te dicht bij een stellair lichaam bent, doe dan het volgende:

  hadd -m13 da_scenter en &clientNames& to enter supercruise open your left menu, navigation tab and select the main star in your current system (will be the first entry in the list), then press the jump button (defaut "J").
  hadd -m13 da_scenter de &clientNames& um in den Supercruise zu gehen öffne das linke Menü, gehe zum Reiter "Navigation" und wähle dort den Hauptstern aus (der oberste Eintrag in der Liste), dann drücke den Sprung Knopf (standard "J").
  hadd -m13 da_scenter ru &clientNames& чтобы войти в гиперкруиз - откройте левое меню, вкладка "Навигация" и выберите основную звезду в вашей текущей системе (первая в списке), затем нажмите кнопку прыжка.
  hadd -m13 da_scenter es &clientNames& para entrar en supercrucero, abre el menú izquierdo, Navegación, selecciona la estrella principal (primera de la lista), y luego pulsa el botón de salto.
  hadd -m13 da_scenter fr &clientNames& pour aller en super-navigation ouvrez votre panneau de gauche, onglet Navigation, sélectionnez l'étoile principale de votre système (tout en haut de la liste), puis appuyez sur votre bouton de saut.
  hadd -m13 da_scenter pt &clientNames& para entrar em supervelocidade, abra o menu da esquerda, aba Navegação e selecione a estrela principal em seu sistema atual (será a primeira da lista), então pressione o botão de salto.
  hadd -m13 da_scenter zh &clientNames& 请打开您的左手边控制板，打开Navigation页面，选择您的星系的主恒星（列表里面第一个选项），然后按您的Jump按键。
  hadd -m13 da_scenter it &clientNames& per entrare in supercruise, apri il pannello a sinistra, scheda "navigation" e seleziona la stella principale del tuo sistema(sarà la prima della lista), poi seleziona il tasto "jump".
  hadd -m13 da_scenter pl &clientNames& aby wejść w tryb SUPERCRUISE wybierz lewy panel (domyślny klawisz 1), zakładka „NAVIGATION”, zaznacz główną gwiazdę układu/systemu (pierwsza pozycja na liście), i wybierz „LOCK AND SUPERCRUISE” (bądź klawisz „J”)
  hadd -m13 da_scenter cs &clientNames& pro vstoupení do supercriuse, otevři levý panel, záložka Navigation a vyber hlavní hvězdu ve tvém aktuálním systému (bude první v pořadí), poté zmáčkni tlačítko pro skok (J)
  hadd -m13 da_scenter tr &clientNames& Supercruise'a girmek için sol paneli aç, navigation sekmesine geç ve bulunduğun sistemin ana yıldızını seç (listedeki ilk girdi olacaktır), sonra "jump" tuşuna bas.
  hadd -m13 da_scenter hu &clientNames& Belépni Supercruise-be nyisd ki a bal oldali menüdet, majd a navigation almenüben válaszd ki a rendszered fő csillagát (azt a csillagot, ami elsőként jelenik meg ezen a listán), majd nyomd meg a JUMP gombot
  hadd -m13 da_scenter nl &clientnames& Om naar supercruise te gaan, open je het linkermenu, het navigatietabblad en selecteer je de hoofdster in je huidige systeem (dit is de eerste ster in de lijst), druk dan op de springknop (standaard “J”).

  hadd -m13 da_scdrop en &clientNames& to drop from supercruise slow down to 30km/s, press "T", then press the jump button (default "J").
  hadd -m13 da_scdrop de &clientNames& um den Supercruse zu verlassen bremse auf 30km/s, drücke "T", dann drücke die Sprungtaste (standardmäßig "J").
  hadd -m13 da_scdrop ru &clientNames& чтобы выйти из гиперкруиза сбросьте скорость до 30 км/с, откройте левое меню, вкладка Навигация и выберите основную звезду в вашей текущей системе (первая в списке), затем нажмите кнопку прыжка.
  hadd -m13 da_scdrop es &clientNames& para bajar de supercrucero reduzca la velocidad a 30km/s, pulse "T", luego pulse el botón de salto (por defecto "J").
  hadd -m13 da_scdrop fr &clientNames& pour sortir de la supercroisière, ralentissez à 30km/s, appuyez sur "T", puis appuyez sur le bouton de saut (par défaut "J").
  hadd -m13 da_scdrop pt &clientNames& para sair da supercruise, abrandar para 30km/s, premir "T", depois premir o botão de salto (por defeito "J").
  hadd -m13 da_scdrop zh &clientNames& 请降低速度到30km/s，打开您的左手边控制板，打开Navigation页面，选择您星系的主恒星（列表里面第一个选项），然后按您的Jump按键。
  hadd -m13 da_scdrop it &clientNames& per scendere dalla supercrociera rallentare a 30 km/s, premere "T", quindi premere il pulsante di salto (default "J").
  hadd -m13 da_scdrop pl &clientNames& aby wyjść z supercruise, zwolnij do 30km/s, naciśnij "T", a następnie naciśnij przycisk skoku (domyślnie "J").
  hadd -m13 da_scdrop cs &clientNames& pro pokles ze supercruise zpomalte na 30km/s, stiskněte "T" a poté stiskněte tlačítko skoku (výchozí "J").
  hadd -m13 da_scdrop tr &clientNames& süper hızdan 30 km/s hıza düşmek için "T" ye basın, ardından atlama düğmesine basın (varsayılan "J").
  hadd -m13 da_scdrop hu &clientNames& a szupersebességből való kilépéshez lassítson le 30km/s-ra, nyomja meg a "T" gombot, majd nyomja meg az ugrás gombot (alapértelmezett "J").
  hadd -m13 da_scdrop nl &clientNames& Om te dalen vanuit supercruise vertraag je naar 30km/s, druk je op “T” en vervolgens op de springknop (standaard “J”).

  hadd -m13 da_db en &clientNames& for fuel tips and advice please join the channel → #debrief ← either by clicking on the channel name here, or by typing "/join #debrief" in this channel. A tab will appear on the left of the chat, please click on it.
  hadd -m13 da_db ru &clientNames& для советов и информации по топливу на русском языке, пожалуйста, наберите в этом чате /join #debrief. Слева от чата откроется новая вкладка, переключитесь на неё.
  hadd -m13 da_db de &clientNames& für Tipps und Hinweise in Deutsch betritt bitte den Kanal → #debrief ← entweder, in dem Du darauf klickst, oder in dem Du /join #debrief eingibst. Ein neuer Tab mit dem Raum wird dann an der Seite erscheinen.
  hadd -m13 da_db es &clientNames& para hablar con tus ratas en Castellano, unete a #debrief escribiendo /join #debrief en este canal.
  hadd -m13 da_db fr &clientNames& Pour des astuces et conseils en Français veuillez rejoindre le canal → #debrief ←  soit en cliquant dessus juste ici, soit en tapant /join #debrief dans ce canal, un onglet va apparaitre à gauche du tchat, veuillez cliquer dessus.
  hadd -m13 da_db pt &clientNames& para conselhos e informações em Portuguese, por favor, entre no canal → #debrief ← tanto clicando nele ou digitando /join #debrief neste canal, uma aba abrirá na esquerda do chat. Alterne para ela.
  hadd -m13 da_db zh &clientNames& 如果您想要您的老鼠用中文去分享一些燃料管理技巧，请在这儿里输入 /join #debrief，或者双点击#debrief。
  hadd -m13 da_db it &clientNames& Per consigli e informazioni in Italiano, per cortesia entra nel canale → #debrief ← cliccando sul nome del canale o scrivendo /join #debrief, una scheda si aprirà sulla sinistra della chat, sulla quale puoi passare.
  hadd -m13 da_db pl &clientNames& aby otrzymać porady i informacje na temat paliwa w języku polskim napisz tutaj „/join #debrief”. Po lewej stronie otworzy się nowa zakładka i w niej będzie można dalej czatować.
  hadd -m13 da_db cs &clientNames& pro další informace ohledně paliva a jeho úspory, prosím napiš "/join #debrief". nalevo se zobrazí nová místnost, klikni na ni.
  hadd -m13 da_db tr &clientNames& Türkçe tavsiye ve bilgi almak için bu kanala katıl → #debrief ← tıklayarak katılabilirsin ya da bu kanalda "/join #debrief" yazabilirsin. Sayfanın sol tarafında bir sekme açılacaktır. Oraya geçiş yap.
  hadd -m13 da_db hu &clientNames& Ha szükséged van tanácsra, illetve információra ezen a nyelven: magyar. kérlek lépj be a → #debrief ← csatornába: rá kattinthatsz itt, vagy ha ide begépeled hogy /join #debrief, egy másik ablakban magától megnyílik, és át tudsz oda kapcsolni.
  hadd -m13 da_db nl &clientNames& Voor tips en hints in het Duits ga je naar het kanaal → #debrief ← door erop te klikken of door /join #debrief te typen. Een nieuw tabblad met de kamer verschijnt dan bovenaan.

  hadd -m13 da_sorry en &clientNames& sorry we couldn't get to you in time today, your rats will be there for you after you respawn to help you with some tips and tricks, so please stick with them for a bit.
  hadd -m13 da_sorry de &clientNames& tut uns leid, dass wir dir nicht helfen konnten. Deine Ratten können dir trotzdem ein paar Tipps geben.
  hadd -m13 da_sorry ru &clientNames& мне очень жаль, что у нас не вышло вам помочь... :( Пожалуйста, оставайтесь в крыле для советов, как избежать этого в дальнейшем.
  hadd -m13 da_sorry es &clientNames& siento que no te hayamos podido salvar, tus ratas estarán contigo cuando reaparezcas y te darán unos consejos sobre el combustible.
  hadd -m13 da_sorry fr &clientNames& je suis désolé que nous n'ayons pas pu vous atteindre à temps ce coup-ci, vos rats seront là après votre réapparition pour vous donner quelques conseils et astuces, alors veuillez rester avec eux un moment.
  hadd -m13 da_sorry pt &clientNames& desculpe, não conseguimos chegar até você a tempo hoje, seu(s) rato(s) estará(ão) lá após você reviver para ajudá-lo com algumas dicas então, por favor, fique com ele(s) por um momento.
  hadd -m13 da_sorry zh &clientNames& 很抱歉我们今天没能够帮助到您。您的老鼠有一些关于燃料管理的一些技巧可以分享，请听取一下。
  hadd -m13 da_sorry it &clientNames& ci dispiace di non averti raggiunto per tempo oggi, i tuoi rats saranno li con te quando respawni per aiutarti con consigli e alcuni trucchi, per cortesia rimani con loro qualche minuto.
  hadd -m13 da_sorry pl &clientNames& bardzo nam przykro że tym razem nie udało się nam dotrzeć do ciebie na czas. Twój Rat-ownik(cy) będzie nadal z tobą w skrzydle po tym jak się odrodzisz, i chętnie posłuży radą – proszę, pozostań z nim jeszcze przez chwilkę.
  hadd -m13 da_sorry cs &clientNames& velmi se omlouváme že ti dnes nemohli pomoci. tvoje krysy s tebou zůstanou i po respawnu aby ti řekly pár tipů a triků, takže s nimi chvíli prosím zůstaň
  hadd -m13 da_sorry tr &clientNames& Sana bugün zamanında ulaşamadığımız için üzgünüz, yeniden doğduğunda farelerin ufak bilgiler vermek için seninle olacaklar, lütfen biraz onlarla kal.
  hadd -m13 da_sorry hu &clientNames& Sajnáljuk, hogy ma nem tudtunk időben elérni hozzád! A patkányaid ott lesznek miután újjáéledsz, és segítenek egy pár tippel, tehát kérlek maradj velük egy kis ideig.
  hadd -m13 da_sorry nl &clientNames& Het spijt ons dat we vandaag niet op tijd bij je konden zijn. Je ratten zullen je na je respawnen helpen met wat tips en trucs, dus blijf alsjeblieft nog even bij ze.

  hadd -m13 da_close en &clientName& you should be receiving fuel now. Please remain with your rat for some quick and helpful tips on fuel management.
  hadd -m13 da_close de &clientName& du solltest jetzt Treibstoff bekommen. Bitte bleibe noch bei deiner Ratte für ein paar nützliche Tipps.
  hadd -m13 da_close ru &clientName& спасибо за ваше обращение к "Fuel Rats". Мы рады, что смогли вам помочь. Вы можете включить ваши бортовые системы. Пожалуйста, оставайтесь в крыле для полезных советов по топливу.
  hadd -m13 da_close es &clientName& gracias por llamar a las Fuel Rats. Por favor, quédate con tus ratas y te darán unos consejos sobre el combustible.
  hadd -m13 da_close fr &clientName& merci d'avoir appelé les Fuel Rats. Veuillez rester avec votre/vos rat(s) pour quelques astuces sur la gestion du carburant.
  hadd -m13 da_close pt &clientName& obrigado por chamar o Fuel Rats hoje. Por favor, continue com seu(s) rato(s) para algumas dicas úteis sobre gerenciamento de combustível.
  hadd -m13 da_close it &clientName& dovresti ricevere carburante ora. Per cortesia rimani con il tuo Rat per qualche rapido consiglio su come gestire il carburante.
  hadd -m13 da_close zh &clientName& 您现在应该已受到燃料。请听一下您的老鼠分享一些燃料管理技巧。
  hadd -m13 da_close pl &clientName& powinieneś już otrzymywać paliwo. Zostań przez chwilę ze swoim Rat-ownikiem, udzieli ci on kilka krótkich, przydatnych wskazówek na temat paliwa w tej grze.
  hadd -m13 da_close cs &clientName& měl by jsi nyní přijímat palivo. prosím zůstaň se svými krysami pro pár rychlých a užitečných tipů ohledně paliva
  hadd -m13 da_close tr &clientName& Şu anda yakıt alıyor olmalısın. Lütfen sana yakıt yönetimi hakkında hızlıca faydalı bilgiler verebilmeleri için farelerinle kal.
  hadd -m13 da_close hu &clientName& Ha minden sikerült, elvben most kapsz üzemanyagot. Kérlek maradj a patkányoddal, adna egy pár gyors és hasznos üzemanyag gazdálkodási tanácsot.
  hadd -m13 da_close nl &clientName& Je zou nu brandstof moeten krijgen. Blijf bij je rat voor wat snelle en nuttige tips over brandstofmanagement.

  hadd -m13 da_plan en &clientName& I'll go through the rescue plan with you in a moment. This is for reading only! Only log in when I give you the "GO GO GO" signal! Are you ok with this?
  hadd -m13 da_plan de &clientName& Ich werde gleich den Rettungsplan mit dir durchgehen. Das ist nur zum lesen! Logge dich erst ein wenn ich dir das "GO GO GO" Signal gebe. Bist du damit einverstanden?
  hadd -m13 da_plan ru &clientName& Сейчас я расскажу вам о плане вашего спасения. ЭТО ТОЛЬКО ДЛЯ ЧТЕНИЯ! Входите в систему только тогда, когда я дам вам сигнал «GO GO GO»! Вам это понятно?
  hadd -m13 da_plan es &clientName& Voy a ir a través del plan de rescate con usted en un momento. ¡Esto es sólo para leer! Sólo entra cuando te dé la señal de "GO GO GO". ¿Estás de acuerdo con esto?
  hadd -m13 da_plan fr &clientName& Je vais passer en revue le plan de sauvetage avec vous dans un instant. C'est uniquement pour la lecture ! Ne vous connectez que lorsque je vous donne le signal "GO GO GO" ! Vous êtes d'accord ?
  hadd -m13 da_plan pt &clientName& Já vou falar-vos do plano de salvamento. Isto é só para ler! Só entrem quando eu vos der o sinal "GO GO GO"! Estás de acordo com isto?
  hadd -m13 da_plan zh &clientName& 稍后，我将和你一起讨论救援计划。这里仅供阅读！只有当我向你发出 "GO GO GO "的信号时，你才能登录！你能接受吗？
  hadd -m13 da_plan it &clientName& Tra poco vi illustrerò il piano di salvataggio. Questo è solo per la lettura! Accedete solo quando vi darò il segnale "GO GO GO"! Sei d'accordo?
  hadd -m13 da_plan pl &clientName& Za chwilę omówię z tobą plan akcji ratunkowej. Teraz tylko to przeczytaj ale nie wykonuj! Zaloguj się dopiero wtedy, gdy dam ci sygnał "GO GO GO"! Czy wszystko jest jasne?
  hadd -m13 da_plan cs &clientName& Za chvíli s vámi projdu záchranný plán. Tohle je jen pro čtení! Přihlaste se, až když vám dám pokyn "GO GO GO"! Souhlasíte s tím?
  hadd -m13 da_plan tr &clientName& Kurtarma planını birazdan sizinle birlikte gözden geçireceğim. Bu sadece okumak için! Sadece ben size "GO GO GO" sinyali verdiğimde giriş yapın! Senin için sorun olur mu?
  hadd -m13 da_plan hu &clientName& Egy pillanat múlva átveszem veled a mentési tervet. Ez csak olvasásra való! Csak akkor jelentkezz be, ha megadom a "GO GO GO GO" jelzést! Rendben vagy ezzel?
  hadd -m13 da_plan nl &clientName& Ik zal zo meteen het reddingsplan met je doornemen. Dit is alleen om te lezen! Log alleen in als ik je het “GO GO GO” signaal geef! Vind je dit goed?

  hadd -m13 da_crinstend en &clientName& please read everything carefully and tell me if you think you can do that very quickly.
  hadd -m13 da_crinstend de &clientName& bitte lies alles sorgfältig durch und sag mir, ob du denkst, dass du das sehr schnell machen kannst.
  hadd -m13 da_crinstend ru &clientName& пожалуйста, внимательно прочитайте всё и скажите мне, если вы уверены, что вы можете это сделать очень быстро.
  hadd -m13 da_crinstend es &clientName& por favor lee todo con cuidado y dime si crees que puedes hacerlo muy rápido.
  hadd -m13 da_crinstend fr &clientName& merci de lire tout attentivement et de me dire si vous pensez pouvoir le faire très rapidement.
  hadd -m13 da_crinstend pt &clientName& por favor leia tudo com cuidado e me diga se você acha que pode fazer isso muito rapidamente.
  hadd -m13 da_crinstend zh &clientName& 请仔细阅读所有内容，并告诉我您是否认为您可以非常快速地完成。
  hadd -m13 da_crinstend it &clientName& per favore leggi tutto attentamente e dimmi se pensi di poterlo
  hadd -m13 da_crinstend pl &clientName& proszę przeczytaj wszystko uważnie i powiedz mi czy uważasz, że możesz to zrobić bardzo szybko.
  hadd -m13 da_crinstend cs &clientName& prosím přečti si vše pečlivě a řekni mi, jestli si myslíš, že to můžeš udělat velmi rychle.
  hadd -m13 da_crinstend tr &clientName& lütfen her şeyi dikkatlice okuyun ve bana bunu çok hızlı bir şekilde yapabileceğinizi düşünüp düşünmediğinizi söyleyin.
  hadd -m13 da_crinstend hu &clientName& kérlek olvasd el mindent figyelmesen és mondd el, ha úgy gondolod, hogy nagyon gyorsan meg tudod csinálni.
  hadd -m13 da_crinstend nl &clientName& Lees alles goed door en vertel me of je denkt dat je dat heel snel kunt.

  set %translationsLoaded $true
  echo -tsg translations loaded
}
