#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ..\skript\Lib\UIA.ahk
; ---------------------------------------------------------------------------
; uia-kartlegg.ahk  (utforskingsverktøy, kun lesing)
; Skriver WebMeds UIA-tre (kontrollvisning) til ..\logg\uia-ÅÅÅÅMMDD-TTMMSS.txt.
; Navn og verdi tas bare med for elementer som er synlige på skjermen
; (IsOffscreen = false), og 11 sammenhengende sifre erstattes med [fnr fjernet].
; Sender ingen tastetrykk eller klikk til WebMed.
; ---------------------------------------------------------------------------
SetTitleMatchMode 2
DetectHiddenWindows false
liste := WinGetList("ahk_exe TNW.Desktop.WPF.exe")
if !liste.Length {
    ToolTip "uia-kartlegg: fant ikke WebMed-vinduet"
    Sleep 3000
    ExitApp
}
props := ["Type","LocalizedType","Name","Value","AutomationId","ClassName","IsOffscreen","BoundingRectangle"
    ,"IsKeyboardFocusable","HasKeyboardFocus","AcceleratorKey","AccessKey","HelpText"
    ,"IsGridPatternAvailable","IsTablePatternAvailable","IsValuePatternAvailable","IsTextPatternAvailable"
    ,"IsInvokePatternAvailable","IsSelectionItemPatternAvailable","IsSelectionPatternAvailable"
    ,"IsExpandCollapsePatternAvailable","IsScrollItemPatternAvailable","IsGridItemPatternAvailable"
    ,"IsTableItemPatternAvailable","IsTogglePatternAvailable","IsLegacyIAccessiblePatternAvailable"]
t0 := A_TickCount
cr := UIA.CreateCacheRequest(props, , 5)
global antall := 0
ut := "WebMed UIA-kartlegging " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
ut .= "Format: dybde | Type | AutomationId | ClassName | mønstre | [l,t,r,b] | Navn | Verdi`r`n"
ut .= "Mønstre: G=Grid T=Table GI=GridItem TI=TableItem V=Value X=Text I=Invoke SI=SelectionItem S=Selection E=ExpandCollapse SC=ScrollItem TG=Toggle L=LegacyIAccessible`r`n"
for hwnd in liste {
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    ut .= "`r`n===== Vindu " A_Index ": `"" Rens(WinGetTitle(hwnd)) "`" klasse=" WinGetClass(hwnd) " pos=" wx "," wy " " ww "x" wh " =====`r`n"
    if ww < 200 || wh < 100 {
        ut .= "(lite vindu, hoppet over)`r`n"
        continue
    }
    try {
        root := UIA.ElementFromHandle(hwnd, cr)
        ut .= Linje(root, 0)
        ut := Traverser(root, 1, ut)
    } catch as e {
        ut .= "FEIL: " e.Message "`r`n"
    }
}
ut .= "`r`nElementer: " antall "   Tid: " (A_TickCount - t0) " ms`r`n"
fil := A_ScriptDir "\..\logg\uia-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
FileAppend ut, fil, "UTF-8-RAW"
ToolTip "uia-kartlegg: " antall " elementer skrevet"
Sleep 2500
ExitApp

Traverser(el, dybde, ut) {
    if dybde > 60
        return ut
    try barn := el.CachedChildren
    catch
        return ut
    for b in barn {
        ut .= Linje(b, dybde)
        ut := Traverser(b, dybde + 1, ut)
    }
    return ut
}

Linje(el, dybde) {
    global antall
    antall++
    P(n) {
        try return el.GetCachedPropertyValue(UIA.Property.%n%)
        catch
            return ""
    }
    typ := P("Type"), tn := ""
    try tn := UIA.Type[typ]
    m := ""
    for kort, navn in Map("G","Grid","T","Table","GI","GridItem","TI","TableItem","V","Value","X","Text","I","Invoke","SI","SelectionItem","S","Selection","E","ExpandCollapse","SC","ScrollItem","TG","Toggle","L","LegacyIAccessible")
        if P("Is" navn "PatternAvailable")
            m .= kort " "
    r := ""
    try {
        br := el.CachedBoundingRectangle
        r := "[" br.l "," br.t "," br.r "," br.b "]"
    }
    off := P("IsOffscreen")
    navn := "", verdi := ""
    if !off {
        navn := Rens(P("Name")), verdi := Rens(P("Value"))
    }
    s := Format("{:3}", dybde) " " StrRepeat("  ", Min(dybde, 30)) tn " | " P("AutomationId") " | " P("ClassName") " | " Trim(m) " | " r
    s .= off ? " | (offscreen)" : ""
    if navn != ""
        s .= " | N=`"" navn "`""
    if verdi != ""
        s .= " | V=`"" verdi "`""
    ak := P("AcceleratorKey"), ac := P("AccessKey")
    if ak != "" || ac != ""
        s .= " | taster=" ak " " ac
    return s "`r`n"
}

Rens(t) {
    t := String(t)
    t := RegExReplace(t, "\d{11}", "[fnr fjernet]")
    t := StrReplace(StrReplace(StrReplace(t, "`r`n", "\n"), "`n", "\n"), "`r", "\n")
    if StrLen(t) > 300
        t := SubStr(t, 1, 300) "…"
    return t
}

StrRepeat(s, n) {
    out := ""
    loop n
        out .= s
    return out
}
