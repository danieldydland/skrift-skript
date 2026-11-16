#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\skrift.ahk
; =============================================================================
; ny-innsjekk-lim-inn.ahk  -  Ctrl+Shift+F8: ny innsjekk i Skrift, lenke og PIN
; til utklippstavlen, så du limer dem inn i meldingen til pasienten med Ctrl+V.
; Versjon: 1.0.0  Journalsystem: alle  Testet: 2026-11-06 (syntaks, ikke mot WebMed)
; Ikke en del av Skrift.md som medisinsk utstyr.
; =============================================================================
; Rettighet som trengs på tokenet: innsjekk. Referansen er din egen merkelapp,
; for eksempel «09:00 ON» (klokkeslett og initialer), aldri hele navnet.
; Kategorien «time» gir Skrifts standardtekst for en time; «skjema» krever at
; du legger inn skjema-id-er i tools (se utviklersiden). Ingenting limes inn av
; seg selv: teksten ligger på utklippstavlen til du trykker Ctrl+V.

TrayTip "Ctrl+Shift+F8 lager en ny innsjekk i Skrift.", "Skrift-eksempel", 1

^+F8::NyInnsjekk()

NyInnsjekk() {
    ib := InputBox("Referanse for innsjekken (for eksempel «09:00 ON», initialer, ikke navn):", "Ny innsjekk i Skrift", "w420 h130")
    if ib.Result != "OK" || Trim(ib.Value) = ""
        return
    ref := SubStr(Trim(ib.Value), 1, 200)
    kropp := '{"reference": ' JsonStreng(ref) ', "kategori": "time"}'
    svar := SkriftKall("POST", "/checkins", kropp)
    if svar.status != 201 {
        MsgBox SkriftFeil(svar), "Ny innsjekk", "Icon!"
        return
    }
    tekst := JsonFelt(svar.tekst, "copyText")
    if tekst = "" {
        MsgBox "Innsjekken er laget, men teksten til pasienten manglet i svaret.", "Ny innsjekk", "Icon!"
        return
    }
    A_Clipboard := tekst
    MsgBox "Innsjekken «" ref "» er laget.`n`nMeldingen til pasienten (lenke og PIN-kode) ligger på utklippstavlen. Åpne meldingen til pasienten i journalsystemet og lim inn med Ctrl+V, én gang.", "Ny innsjekk", "Iconi"
}
