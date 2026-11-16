#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ..\skript\Lib\PatientText.ahk
; =============================================================================
; patienttext-sjekk.ahk  –  Skrift.md / Eirskrift AS
; Sjekker om dagsliste.ahk (v0.2) kan lese PatientText fra en kopi på denne
; maskinen. Kjør det før første kjøring av v0.2, og etter WebMed-oppdateringer.
;
; Bruk (bare fiktiv pasient):
;   1. Åpne en fiktiv pasient i WebMed.
;   2. Alt+S, Ctrl+A, Ctrl+C (Tidligere sykdommer). Dobbeltklikk dette skriptet.
;   3. Det samme med Alt+F (Familie/Sosialt).
;   4. Hovednotatet: Ctrl+Alt+L, klikk i notatet, Ctrl+A, Ctrl+C, kjør skriptet,
;      og angre med Ctrl+Z i notatet.
;   5. Et tomt felt (for eksempel Alt+F hos en pasient uten familie/sosialt),
;      Ctrl+A, Ctrl+C, kjør skriptet: viser hva WebMed gjør med en tom kopi.
;   Punkt 2–4 skal vise «OK» og samme begynnelse på pasient-GUID-en.
;
; Viser aldri journaltekst eller hele pasient-ID-en, bare formatnavn, lengder,
; tegnkoding, nøkkelnavn og de første 8 tegnene i GUID-en. Endrer ikke
; utklippstavlen, skriver ingen filer og bruker ikke nettverket.
; =============================================================================

kopiert := A_Clipboard
cb := ClipboardAll()
navn := "", harTekst := true
try {
    f := UtklippFormater(cb)
    harTekst := f.Has(13)
    for fmt, d in f
        navn .= (navn = "" ? "" : ", ") FormatNavn(fmt)
} catch as e
    navn := "(kunne ikke lese listen: " e.Message ")"

r := LesPatientText(kopiert)
s := "Utklippstavlen: " navn "`n"
s .= "Kopiert tekst (UnicodeText): " StrLen(kopiert) " tegn`n`n"
if !r.funnet {
    s .= "PatientText: FINNES IKKE`n`n"
    if !harTekst
        s .= "Ingen tekst på utklippstavlen. Ctrl+C i et tomt felt endrer den ikke (målt 22.10); "
            . "det som ligger der er fra før. dagsliste.ahk ser at utklippstavlen ikke endres, "
            . "regner feltet som tomt og skriver en advarsel, som v0.1.1."
    else if Trim(kopiert, " `t`r`n") = ""
        s .= "Tom kopi uten PatientText: greit, dagsliste.ahk v0.2 regner feltet som tomt."
    else {
        s .= "IKKE OK: dagsliste.ahk v0.2 stopper når et felt med tekst mangler PatientText.`n"
        s .= "Var det Ctrl+C i WebMed-journalen rett før? Kopier på nytt og kjør igjen."
    }
} else {
    s .= "PatientText: funnet, " r.bytes " byte" (r.koding != "" ? ", " r.koding : "") "`n"
    if r.nokler != ""
        s .= "Nøkler: " r.nokler "`n"
    if r.tekstLengde >= 0
        s .= "Text: " r.tekstLengde " tegn`n"
    if r.feil = "" {
        s .= "Text er lik den kopierte teksten: ja`n"
        s .= "PatientId: gyldig GUID, begynner med " SubStr(r.id, 1, 8) "…`n`n"
        s .= "OK: dagsliste.ahk v0.2 kan bruke denne kopien."
    } else if Trim(kopiert, " `t`r`n") = "" {
        s .= "`nTom kopi med ubrukelig PatientText (" r.feil "): greit, dagsliste.ahk v0.2 regner feltet som tomt."
    } else {
        s .= "`nIKKE OK: " r.feil
        if InStr(r.feil, "ukjent")
            s .= "`nFørste byte: " ForsteBytes(cb, 48)
        s .= "`n`nSend gjerne dette vinduet (Ctrl+C kopierer teksten) til den som vedlikeholder skriptet."
    }
}
s .= "`n`nUtklippstavlen er ikke endret og inneholder fortsatt det du kopierte. Tøm den når du er ferdig."
MsgBox s, "PatientText-sjekk"
ExitApp

FormatNavn(fmt) {
    static std := Map(1, "Text", 2, "Bitmap", 7, "OEMText", 8, "DIB", 13, "UnicodeText", 15, "FileDrop", 16, "Locale", 17, "DIBV5")
    if std.Has(fmt)
        return std[fmt]
    buf := Buffer(512, 0)
    if n := DllCall("GetClipboardFormatName", "UInt", fmt, "Ptr", buf, "Int", 255)
        return StrGet(buf, n)
    return "#" fmt
}

; De første bytene i PatientText som heksadesimal (bare når formatet er ukjent).
; Stopper ved første «{», der JSON-en (og journalteksten) begynner, og etter
; høyst antall byte. .NET-merket og NRBF-toppteksten er 40 byte.
ForsteBytes(cb, antall) {
    try {
        f := UtklippFormater(cb)
        cf := PatientTextFormat()
        if !f.Has(cf)
            return "-"
        s := ""
        loop Min(antall, f[cf].size) {
            b := NumGet(f[cf].ptr, A_Index - 1, "UChar")
            s .= Format("{:02X} ", b)
            if b = 0x7B
                return s "…"
        }
        return RTrim(s)
    }
    return "-"
}
