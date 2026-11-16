; =============================================================================
; Dialog.ahk  –  felles utseende for skriptets vinduer (v0.7, Daniel 29.10:
; «designet på boksene som dukker opp bør være OK»). Alle bokser, spørsmål
; og innskrivingsfelt går gjennom disse funksjonene, så de ser like ut:
; hvit flate, et toppbånd i Skrifts farge (teal 009090; rødt ved stopp, oransje
; ved varsel), Segoe UI, teksten med luft, knappene nederst til høyre, Esc
; lukker. Ingen ikoner fra Windows. Vinduene ligger alltid øverst.
; Dialogene viser bare det brukeren skal se; de logger ingenting selv.
; =============================================================================

global DLG_BREDDE := 480
global DLG_FARGER := Map("info", "009090", "sporsmal", "009090", "varsel", "B35C00", "stopp", "B00000", "ok", "2E7D32")

; Nytt vindu med toppbånd. Svar: {g, w, y} der y er neste ledige linje under båndet.
; v0.10.3 (rapportfunn 1): radene en tekst tar i et felt med fast skrift når
; lange linjer brytes: hver linje tar Ceil(lengde / tegnPerRad) rader, minst
; én. Tom tekst = 1 rad. Brukes av VisPin, så hele meldingen vises uten rulling.
TekstRader(tekst, tegnPerRad := 75) {
    n := 0
    for linje in StrSplit(StrReplace(tekst, "`r"), "`n")
        n += Max(1, Ceil(StrLen(linje) / Max(1, tegnPerRad)))
    return Max(1, n)
}

DialogNy(tittel, art := "info", bredde := 0) {
    w := bredde ? bredde : DLG_BREDDE
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox +OwnDialogs", "Skrift: " tittel)
    g.BackColor := "FFFFFF"
    g.MarginX := 0, g.MarginY := 0
    farge := DLG_FARGER.Has(art) ? DLG_FARGER[art] : DLG_FARGER["info"]
    g.SetFont("s12 bold cFFFFFF", "Segoe UI")
    g.AddText("x0 y0 w" w " h54 Background" farge " +0x200", "   " tittel)
    g.SetFont("s11 norm c1F1F1F", "Segoe UI")
    return {g: g, w: w, y: 72, art: art}
}

; Brødtekst under båndet. Svar: kontrollen.
DialogTekst(d, tekst, valg := "") {
    c := d.g.AddText("x22 y" d.y " w" (d.w - 44) " " valg, tekst)
    c.GetPos(, , , &h)
    d.y += h + 10
    return c
}

; Knapper nederst til høyre: navn -> tekst. Den første er standard (Enter).
; v0.7.1 (G9 30.10): en Map i AutoHotkey itereres i sortert rekkefølge, så
; Map("ok", "OK", "avbryt", "Avbryt") ga «Avbryt» først og på Enter. Rekkefølgen
; settes derfor her: ja, ok, lukk og send først, så nei og avbryt, så resten.
; Bredden følger teksten (G5: «Ja, be Skrift ringe» fikk ikke plass på 118 px).
; Svar: Map navn -> knapp. Vinduet får høyde etter siste linje.
DialogKnapper(d, knapper) {
    navn := DialogRekkefolge(knapper)
    mellom := 10, y := d.y + 10
    bredder := [], sum := 0
    for n in navn {
        kb := Max(118, Round(StrLen(knapper[n]) * 8.5) + 30)
        bredder.Push(kb), sum += kb
    }
    x := d.w - 22 - sum - (navn.Length - 1) * mellom
    ut := Map()
    for i, n in navn {
        b := d.g.AddButton("x" x " y" y " w" bredder[i] " h34 " (i = 1 ? "Default" : ""), knapper[n])
        ut[n] := b
        x += bredder[i] + mellom
    }
    d.y := y + 34 + 18
    return ut
}

; Rekkefølgen på knappene (navnene) i en Map: den anbefalte først.
DialogRekkefolge(knapper) {
    ut := []
    for n in ["ja", "ok", "lukk", "send", "nei", "avbryt"]
        if knapper.Has(n)
            ut.Push(n)
    for n in knapper
        if !DialogHar(ut, n)
            ut.Push(n)
    return ut
}

DialogHar(liste, verdi) {
    for v in liste
        if v = verdi
            return true
    return false
}

; Modal boks med knapper. Svar: navnet på knappen (eller "lukk" ved Esc og kryss).
; knapper: Map i rekkefølge, for eksempel Map("ja", "Ja", "nei", "Nei").
SkriftBoks(tittel, tekst, knapper := "", art := "info", bredde := 0) {
    if knapper = ""
        knapper := Map("ok", "OK")
    d := DialogNy(tittel, art, bredde)
    DialogTekst(d, tekst)
    svar := "lukk"
    kn := DialogKnapper(d, knapper)
    for navn, b in kn
        b.OnEvent("Click", DialogVelg.Bind(navn))
    DialogVelg(navn, *) {
        svar := navn
        d.g.Destroy()
    }
    d.g.OnEvent("Close", (*) => d.g.Destroy())
    d.g.OnEvent("Escape", (*) => d.g.Destroy())
    ; Vinduets id leses før Show: lukkes vinduet mens Show pågår, finnes ingen Hwnd etterpå
    h := d.g.Hwnd
    d.g.Show("w" d.w " h" d.y)
    WinWaitClose h
    return svar
}

; Ja eller nei. Svar: true bare ved «Ja».
SkriftJa(tittel, tekst, ja := "Ja", nei := "Nei", art := "sporsmal") {
    return SkriftBoks(tittel, tekst, Map("ja", ja, "nei", nei), art) = "ja"
}

; Ett innskrivingsfelt. Svar: teksten (trimmet), eller "" ved avbrudd.
SkriftSpor(tittel, forklaring, hint := "", standard := "") {
    d := DialogNy(tittel, "sporsmal")
    DialogTekst(d, forklaring)
    e := d.g.AddEdit("x22 y" d.y " w" (d.w - 44) " h32", standard)
    d.y += 32 + 6
    if hint != "" {
        d.g.SetFont("s9 c6B6B6B")
        DialogTekst(d, hint)
        d.g.SetFont("s11 c1F1F1F")
    }
    svar := ""
    kn := DialogKnapper(d, Map("ok", "OK", "avbryt", "Avbryt"))
    kn["ok"].OnEvent("Click", (*) => (svar := Trim(e.Value), d.g.Destroy()))
    kn["avbryt"].OnEvent("Click", (*) => d.g.Destroy())
    d.g.OnEvent("Close", (*) => d.g.Destroy())
    d.g.OnEvent("Escape", (*) => d.g.Destroy())
    h := d.g.Hwnd
    d.g.Show("w" d.w " h" d.y)
    try e.Focus()
    WinWaitClose h
    return svar
}

; Velg én av flere linjer. Svar: nummeret (1 og oppover), eller 0 ved avbrudd.
; v0.9.0: forvalg (linjenummer) og rader (synlige linjer, høyst 12). Skriver
; brukeren bokstaver/sifre, hopper listen dit (Windows' egen søking i lister).
SkriftVelg(tittel, forklaring, linjer, forvalg := 1, rader := 8) {
    d := DialogNy(tittel, "sporsmal")
    DialogTekst(d, forklaring)
    lb := d.g.AddListBox("x22 y" d.y " w" (d.w - 44) " r" Min(rader, Max(2, linjer.Length)) " Choose" Max(1, Min(linjer.Length, forvalg)), linjer)
    ; Forvalget midt i det synlige (LB_SETTOPINDEX), ikke nederst
    if forvalg > 1
        try SendMessage(0x0197, Max(0, forvalg - 1 - Min(rader, linjer.Length) // 2), 0, lb)
    lb.GetPos(, , , &h)
    d.y += h + 6
    valg := 0
    kn := DialogKnapper(d, Map("ok", "Velg", "avbryt", "Avbryt"))
    kn["ok"].OnEvent("Click", (*) => (valg := lb.Value, d.g.Destroy()))
    lb.OnEvent("DoubleClick", (*) => (valg := lb.Value, d.g.Destroy()))
    kn["avbryt"].OnEvent("Click", (*) => d.g.Destroy())
    d.g.OnEvent("Close", (*) => d.g.Destroy())
    d.g.OnEvent("Escape", (*) => d.g.Destroy())
    ; Vinduets id leses før Show: lukkes vinduet mens Show pågår, finnes ingen Hwnd etterpå
    h := d.g.Hwnd
    d.g.Show("w" d.w " h" d.y)
    WinWaitClose h
    return valg
}

; Hvilken art en melding fra de eldre kallene har (ikon-koden fra MsgBox).
DialogArt(ikon) => InStr(ikon, "Iconx") ? "stopp" : InStr(ikon, "Icon!") ? "varsel" : "info"
