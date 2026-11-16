#Requires AutoHotkey v2.0
; avslutt-skript.ahk – avslutter de andre skriptene fra denne utforskingen
; (dagsliste-torrkjoring.ahk og skjermbilde.ahk), så hurtigtastene frigjøres.
DetectHiddenWindows true
SetTitleMatchMode 2
n := 0
for navn in ["dagsliste-torrkjoring.ahk", "skjermbilde.ahk"]
    while WinExist(navn " ahk_class AutoHotkey") {
        WinClose
        Sleep 200
        n++
        if n > 10
            break
    }
ToolTip "Avsluttet " n " skript"
Sleep 1500
