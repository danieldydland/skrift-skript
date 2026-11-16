#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ..\skript\Lib\UIA.ahk
; ---------------------------------------------------------------------------
; uia-punkt.ahk  (utforskingsverktøy, kun lesing)
; 1) Rå visning (RawView) av WebMed-hovedvinduet, maks 8 nivåer.
; 2) ElementFromPoint på faste skjermpunkter (fysiske piksler) + forfedre.
; 3) MSAA (Acc) på de samme punktene.
; Skriver ..\logg\uia-punkt-ÅÅÅÅMMDD-TTMMSS.txt. Sender ingen input til WebMed.
; ---------------------------------------------------------------------------
SetTitleMatchMode 2
CoordMode "Mouse", "Screen"
hwnd := WinExist("WebMed ahk_exe TNW.Desktop.WPF.exe")
if !hwnd {
    ToolTip "uia-punkt: fant ikke WebMed"
    Sleep 3000
    ExitApp
}
punkter := [["Tidligere sykdommer", 439, 867], ["Legemidler i bruk", 241, 434], ["Notatfelt", 1733, 658]
    , ["Lopende journal", 2633, 480], ["Pasientnavn", 88, 165], ["Familie/sosialt", 132, 1141], ["Toppmeny", 330, 60]]
ut := "uia-punkt " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
; 1) Rå visning
crRaw := UIA.CreateCacheRequest(["Type","Name","AutomationId","ClassName","IsOffscreen","BoundingRectangle","FrameworkId"], , 5, , UIA.RawViewCondition)
try {
    root := UIA.ElementFromHandle(hwnd, crRaw)
    ut .= "`r`n== Rå visning ==`r`n"
    ut := Rek(root, 0, ut)
} catch as e
    ut .= "Rå visning FEIL: " e.Message "`r`n"
; 2) Punkter
for p in punkter {
    ut .= "`r`n== Punkt " p[1] " (" p[2] "," p[3] ") ==`r`n"
    try {
        el := UIA.ElementFromPoint(p[2], p[3])
        n := 0
        while el && n < 12 {
            ut .= "  " n ": " Beskriv(el) "`r`n"
            try el := UIA.ControlViewWalker.GetParentElement(el)
            catch
                break
            n++
        }
    } catch as e
        ut .= "  FEIL: " e.Message "`r`n"
    ; 3) MSAA
    try {
        acc := AccFromPoint(p[2], p[3], &child)
        nm := "", rl := "", vl := ""
        try nm := acc.accName[child]
        try rl := acc.accRole[child]
        try vl := acc.accValue[child]
        ut .= "  MSAA: rolle=" rl " navn=`"" Rens(nm) "`" verdi=`"" Rens(vl) "`"`r`n"
    } catch as e
        ut .= "  MSAA FEIL: " e.Message "`r`n"
}
fil := A_ScriptDir "\..\logg\uia-punkt-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
FileAppend ut, fil, "UTF-8-RAW"
ToolTip "uia-punkt: ferdig"
Sleep 2000
ExitApp

Rek(el, d, ut) {
    if d > 8
        return ut
    ut .= Format("{:3}", d) " " Beskriv(el, true) "`r`n"
    try barn := el.CachedChildren
    catch
        return ut
    for b in barn
        ut := Rek(b, d + 1, ut)
    return ut
}

Beskriv(el, cached := false) {
    g(n) {
        try return cached ? el.GetCachedPropertyValue(UIA.Property.%n%) : el.GetPropertyValue(UIA.Property.%n%)
        catch
            return ""
    }
    tn := ""
    try tn := UIA.Type[g("Type")]
    r := ""
    try {
        br := cached ? el.CachedBoundingRectangle : el.BoundingRectangle
        r := "[" br.l "," br.t "," br.r "," br.b "]"
    }
    off := g("IsOffscreen")
    s := tn " | id=" g("AutomationId") " | kl=" g("ClassName") " | fw=" g("FrameworkId") " | " r
    if !off {
        nm := Rens(g("Name"))
        if nm != ""
            s .= " | N=`"" nm "`""
        if !cached {
            vl := ""
            try vl := Rens(el.GetPropertyValue(UIA.Property.Value))
            if vl != ""
                s .= " | V=`"" vl "`""
        }
    } else
        s .= " | (offscreen)"
    return s
}

AccFromPoint(x, y, &child) {
    static h := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")
    pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
    varChild := Buffer(8 + 2 * A_PtrSize, 0)
    if DllCall("oleacc\AccessibleObjectFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr*", &pAcc := 0, "Ptr", varChild) = 0 {
        child := NumGet(varChild, 8, "UInt")
        return ComValue(9, pAcc, 1)
    }
    throw Error("AccessibleObjectFromPoint feilet")
}

Rens(t) {
    t := String(t)
    t := RegExReplace(t, "\d{11}", "[fnr fjernet]")
    t := StrReplace(StrReplace(StrReplace(t, "`r`n", "\n"), "`n", "\n"), "`r", "\n")
    if StrLen(t) > 400
        t := SubStr(t, 1, 400) "…"
    return t
}
