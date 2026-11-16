#Requires AutoHotkey v2.0
#SingleInstance Force
; kal-sjekk.ahk (utforskingsverktøy, kun lesing, 30.10): leser pikselfarger i
; Løpende journal der kalibreringen skanner, og skriver løpelengder (farge x antall)
; til ..\logg\kal-sjekk-ÅÅÅÅMMDD-TTMMSS.txt. Ingen tastetrykk eller klikk, ingen tekst.
Sleep 6000
FileAppend "start`r`n", A_ScriptDir "\..\logg\kal-sjekk-start.txt", "UTF-8"
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"
ut := "kal-sjekk " FormatTime(, "yyyy-MM-dd HH:mm:ss") " skjerm " A_ScreenWidth "x" A_ScreenHeight "`r`n"
hwnd := WinExist("WebMed ahk_exe TNW.Desktop.WPF.exe")
if hwnd {
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    ut .= "WebMed " wx "," wy " " ww "x" wh " minmax " WinGetMinMax(hwnd) "`r`n"
}
MouseGetPos &mx, &my, &mw
ut .= "mus " mx "," my " vindu under musen: " (mw = hwnd ? "WebMed" : mw ? WinGetProcessName(mw) " '" WinGetClass(mw) "'" : "ingen") "`r`n"
; Vannrett profil gjennom overskriften (y = 412) fra x 2300 til 3440
ut .= "`r`n-- vannrett y=412, x 2300..3439 --`r`n" Profil((x) => PixelGetColor(x, 412), 2300, 3439)
; Loddrette profiler i skannekolonnen og noen x til, fra y 376 til 1365
for x in [2343, 2351, 2360, 2370, 2400, 2500] {
    ut .= "`r`n-- loddrett x=" x ", y 376..1365 --`r`n" Profil((y) => PixelGetColor(x, y), 376, 1365)
}
; Hvilket vindu ligger over punktene (WindowFromPoint)
for p in [[2351, 412], [2850, 412], [3060, 412], [2676, 360], [2628, 1314]] {
    h := DllCall("WindowFromPoint", "int64", (p[2] << 32) | p[1], "ptr")
    r := DllCall("GetAncestor", "ptr", h, "uint", 2, "ptr")
    ut .= "`r`npunkt " p[1] "," p[2] ": " (r = hwnd ? "WebMed" : r ? WinGetProcessName(r) " '" SubStr(WinGetClass(r), 1, 40) "'" : "ingen")
}
FileAppend ut "`r`n", A_ScriptDir "\..\logg\kal-sjekk-" FormatTime(, "yyyyMMdd-HHmmss") ".txt", "UTF-8"
ToolTip "kal-sjekk skrevet"
Sleep 2000
ExitApp

Profil(f, a, b) {
    s := "", sist := "", n := 0
    loop b - a + 1 {
        c := Format("{:06X}", f(a + A_Index - 1))
        if c = sist
            n++
        else {
            if sist != ""
                s .= sist "x" n " "
            sist := c, n := 1
        }
    }
    return s sist "x" n "`r`n"
}
