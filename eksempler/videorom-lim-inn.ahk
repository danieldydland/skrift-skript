#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\skrift.ahk
; =============================================================================
; videorom-lim-inn.ahk  -  Ctrl+Shift+F12: lager et videorom i Skrift og legger
; pasientlenken på utklippstavlen, så du limer den inn i meldingen med Ctrl+V.
; Versjon: 1.0.0  Journalsystem: alle  Testet: 2026-11-06 (syntaks, ikke mot WebMed)
; Ikke en del av Skrift.md som medisinsk utstyr.
; =============================================================================
; Rettighet som trengs på tokenet: kommando. Rommet står i Skrift under Video;
; der slipper du pasienten inn. Lenken gjelder i fire timer.

TrayTip "Ctrl+Shift+F12 lager et videorom i Skrift.", "Skrift-eksempel", 1

^+F12::Videorom()

Videorom() {
    if MsgBox("Lage et videorom i Skrift og legge pasientlenken på utklippstavlen?", "Videorom", "YesNo Iconi") != "Yes"
        return
    svar := SkriftKall("POST", "/commands", '{"type": "videorom"}')
    if svar.status != 201 {
        MsgBox SkriftFeil(svar), "Videorom", "Icon!"
        return
    }
    lenke := JsonFelt(svar.tekst, "lenke")
    if lenke = "" {
        MsgBox "Rommet er laget, men lenken manglet i svaret. Se under Video i Skrift.", "Videorom", "Icon!"
        return
    }
    A_Clipboard := lenke
    MsgBox "Videolenken ligger på utklippstavlen (Ctrl+V limer den inn). Rommet står i Skrift under Video; der slipper du pasienten inn. Lenken gjelder i fire timer.", "Videorom", "Iconi"
}
