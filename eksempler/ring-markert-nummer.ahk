#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\skrift.ahk
; =============================================================================
; ring-markert-nummer.ahk  -  Ctrl+Shift+F11: ring opp nummeret du har markert,
; via den åpne Skrift-fanen (oppringingen skjer først når du klikker Ring der).
; Versjon: 1.0.0  Journalsystem: alle  Testet: 2026-11-06 (syntaks, ikke mot WebMed)
; Ikke en del av Skrift.md som medisinsk utstyr.
; =============================================================================
; Rettighet som trengs på tokenet: kommando. Marker et norsk nummer (8 sifre,
; med eller uten +47) i et hvilket som helst program. Skriptet kopierer det,
; viser det og spør før noe sendes. Utklippstavlen settes tilbake etterpå.

TrayTip "Ctrl+Shift+F11 ringer det markerte nummeret via Skrift.", "Skrift-eksempel", 1

^+F11::RingMarkert()

RingMarkert() {
    lagret := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    tekst := ClipWait(1) ? A_Clipboard : ""
    A_Clipboard := lagret
    nr := Nummer(tekst)
    if nr = "" {
        MsgBox "Marker et norsk telefonnummer (8 sifre, med eller uten +47) først.", "Ring via Skrift", "Icon!"
        return
    }
    if MsgBox("Ringe " nr " via Skrift?`n`nOppringingen skjer først når du klikker Ring i Skrift-fanen.", "Ring via Skrift", "YesNo Iconi") != "Yes"
        return
    svar := SkriftKall("POST", "/commands", '{"type": "ring", "til": ' JsonStreng(nr) '}')
    if svar.status != 202 {
        MsgBox SkriftFeil(svar), "Ring via Skrift", "Icon!"
        return
    }
    TrayTip "Klikk Ring i Skrift-fanen innen 60 sekunder.", "Skrift: " nr, 1
}

; Ett norsk nummer fra den markerte teksten: 8 sifre, eventuelt med +47 eller 0047 foran.
; Tom når teksten ikke har nøyaktig ett slikt nummer.
Nummer(tekst) {
    s := RegExReplace(tekst, "[\s\-()]", "")
    s := RegExReplace(s, "^(\+47|0047)", "")
    if RegExMatch(s, "^(\d{8})$", &m)
        return m[1]
    return ""
}
