; =============================================================================
; Oppsett.ahk  –  veiviseren ved første kjøring (v0.10, Daniel 02.11: «Må være
; en slags wizard ved førstegangskjøring uten config»). Kjøres når skriptet
; starter uten et gyldig token, og fra menyen (Mer → Oppsett). Tre steg:
;   1. tokenet: forklarer hvor det lages i Skrift, tar det imot i et skjult felt,
;      skriver tokenfilen utenfor skriptmappen og prøver GET /me,
;   2. bryterne: normal bruk (sending på) eller tørrkjøring først,
;   3. kalibreringen, hvis skjermen ikke er kalibrert.
; Tokenet vises aldri igjen, logges aldri og står aldri i config.ini.
; =============================================================================

global TOKEN_MONSTER := "^skr_[A-Za-z0-9_-]{16,}$"

TokenFormatOk(tok) => !!RegExMatch(Trim(tok), TOKEN_MONSTER)

; Standardplassen for tokenfilen: utenfor skriptmappen, ikke synkronisert
TokenfilStandard() {
    base := EnvGet("LOCALAPPDATA")
    if base = ""
        base := A_AppData
    return base "\Skrift\skrift-token.ini"
}

; Er tokenet på plass og gyldig på formen? (ingen nettverkskall)
TokenKlar() {
    try {
        LesToken()
        return true
    }
    return false
}

; Skriver tokenfilen (to linjer, UTF-8 uten BOM) og peker config.ini på den.
SkrivTokenfil(sti, tok) {
    SplitPath sti, , &mappe
    if mappe != ""
        DirCreate mappe
    f := FileOpen(sti, "w", "UTF-8-RAW")
    f.Write("[skrift]`r`ntoken=" Trim(tok) "`r`n")
    f.Close()
}

; v0.11.1: råd når nettet, ikke tokenet, er problemet (sertifikatfeil og tidsavbrudd
; på nett med proxy, som NHN-nett; 0x80072F0D er «sertifiseringsinstansen er ugyldig»)
NettHint(melding) {
    if InStr(melding, "0x80072F0D") || InStr(melding, "0x80072EE7") || InStr(melding, "0x80072EFD") || InStr(melding, "0x80072EE2") || InStr(melding, "Sertifiseringsinstansen") || InStr(melding, "certificate authority")
        return "`n`nDette ser ut som nettet, ikke tokenet: skriptet nådde ikke Skrift, eller noe mellom PC-en og Skrift svarte med et annet sertifikat (sperre eller proxy). Skriptet bruker Windows' proxyinnstillinger (PAC eller manuell). Hjelper det ikke, sett [skrift] proxy=vert:port i config.ini (proxyen nettet ditt bruker), og prøv igjen."
    return ""
}

; Tokenet prøvd mot Skrift. Svar: {ok, tekst} med navn og rettigheter, eller feilen.
ProvToken() {
    try {
        tok := LesToken()
        svar := KallSkrift("GET", "/me", "", tok)
        tok := ""
    } catch as e {
        return {ok: false, tekst: e.Message NettHint(e.Message)}
    }
    if svar.status != 200
        return {ok: false, tekst: StatusTekst(svar, "GET /me")}
    navn := "", rolle := "", liste := "", utl := "", rett := Map()
    try {
        me := JsonLes(svar.tekst)
        navn := me["bruker"]["navn"], rolle := me["bruker"]["rolle"]
        for x in me["token"]["rettigheter"] {
            liste .= (liste = "" ? "" : ", ") x
            rett[StrLower(x)] := true
        }
        utl := SubStr(me["token"]["utloper"], 1, 10)
    }
    mangler := ManglendeRettigheter(rett)
    Logg("oppsett: tokenet virker (rettigheter: " liste (utl != "" ? ", utløper " utl : "") ")")
    return {ok: true, tekst: "Tokenet virker. Skrift kjenner deg som " navn " (" rolle ").`nRettigheter: " liste "." (utl != "" ? " Utløper " utl "." : "")
        . (mangler != "" ? "`n`nTokenet mangler " mangler ". Menyvalg som trenger det, vil stoppe med 403; lag i så fall et nytt token med alle fire rettighetene." : "")}
}

; De fire rettighetene skriptet bruker, som ikke står i tokenet. rett: Map navn -> true.
; (v0.10.1: sjekken lette etter «,postkasse,» i en liste med komma og mellomrom, og
; meldte derfor at alle fire manglet selv om tokenet hadde dem.)
ManglendeRettigheter(rett) {
    mangler := ""
    for r in ["innsjekk", "postkasse", "sms", "kommando"]
        if !rett.Has(r)
            mangler .= (mangler = "" ? "" : ", ") r
    return mangler
}

; Innskriving av tokenet i et skjult felt. Svar: tokenet, eller "" ved avbrudd.
SporToken() {
    d := DialogNy("Tokenet fra Skrift", "sporsmal", 560)
    DialogTekst(d, "Lim inn tokenet (begynner med skr_). Det vises ikke på skjermen, lagres i en egen fil utenfor skriptmappen, og sendes bare til Skrift.")
    e := d.g.AddEdit("x22 y" d.y " w" (d.w - 44) " h32 Password")
    d.y += 32 + 6
    d.g.SetFont("s9 c6B6B6B")
    DialogTekst(d, "Ctrl+V limer inn. Tokenet vises bare én gang i Skrift; mistet du det, lag et nytt der.")
    d.g.SetFont("s11 c1F1F1F")
    svar := ""
    kn := DialogKnapper(d, Map("ok", "Lagre tokenet", "avbryt", "Avbryt"))
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

; Steg 1: tokenet. Svar: true når et gyldig token er lagret og prøvd.
OppsettToken() {
    loop {
        valg := SkriftBoks("Oppsett 1 av 3: tokenet",
            "Skriptet trenger et personlig token fra Skrift for å lage innsjekker og legge journalbakgrunn i innboksen.`n`n"
            . "Slik lager du det:`n"
            . "1. Åpne Skrift i nettleseren og gå til Innstillinger → Integrasjoner.`n"
            . "2. Trykk «Nytt token», gi det et navn (for eksempel «WebMed-PC»), og kryss av for alle fire rettighetene: innsjekk, postkasse, sms og kommando.`n"
            . "3. Kopier tokenet. Det vises bare én gang.`n`n"
            . "Trykk så «Lim inn tokenet» her.",
            Map("lim", "Lim inn tokenet", "apne", "Åpne Skrift", "avbryt", "Senere"), "sporsmal", 620)
        if valg = "apne" {
            try Run "https://app.skrift.md/app"
            continue
        }
        if valg != "lim"
            return false
        tok := SporToken()
        if tok = ""
            continue
        if !TokenFormatOk(tok) {
            SkriftBoks("Tokenet", "Det ser ikke ut som et token fra Skrift (de begynner med skr_ og har bare bokstaver, tall, bindestrek og understrek). Prøv igjen.", "", "varsel")
            continue
        }
        sti := K.tokenfil != "" ? K.tokenfil : TokenfilStandard()
        try {
            SkrivTokenfil(sti, tok)
            IniWrite sti, KONFIG, "skrift", "tokenfil"
        } catch as e {
            SkriftBoks("Tokenet", "Fikk ikke skrevet tokenfilen " sti ": " e.Message, "", "stopp")
            tok := ""
            continue
        }
        tok := ""
        LesSending()
        p := ProvToken()
        if p.ok {
            SkriftBoks("Tokenet", p.tekst "`n`nTokenfilen: " sti, "", "ok", 600)
            return true
        }
        v := SkriftBoks("Tokenet", "Skrift godtok ikke tokenet: " p.tekst "`n`nTokenfilen er skrevet (" sti "), men kallet feilet. Er tokenet nytt og kopiert helt?", Map("igjen", "Prøv igjen", "avbryt", "Senere"), "varsel", 600)
        if v != "igjen"
            return false
    }
}

; Steg 2: bryterne. Svar: true når et valg er gjort.
OppsettBrytere() {
    valg := SkriftBoks("Oppsett 2 av 3: sending til Skrift",
        "Skal skriptet sende til Skrift med en gang, eller først vise deg hva det ville sendt?`n`n"
        . "Normal bruk: dagslisten, innsjekker, legemiddelgjennomgang, ring og videorom går til Skrift når du velger dem i menyen.`n"
        . "Tørrkjøring: ingenting sendes; dagslisten skrives til en fil, kommandoene vises i et vindu. Du slår på sendingen senere i config.ini ([skrift] send, send_lmg og send_kommando).",
        Map("normal", "Normal bruk", "torr", "Tørrkjøring først", "avbryt", "Senere"), "sporsmal", 620)
    if valg = "normal" || valg = "torr" {
        v := valg = "normal" ? "1" : "0"
        IniWrite v, KONFIG, "skrift", "send"
        IniWrite v, KONFIG, "skrift", "send_lmg"
        IniWrite v, KONFIG, "skrift", "send_kommando"
        LesSending()
        Logg("oppsett: bryterne satt til " (valg = "normal" ? "sending" : "tørrkjøring"))
        return true
    }
    return false
}

; Steg 3: kalibreringen, når skjermen ikke er kalibrert. Svar: true når skjermen
; er kalibrert. v0.11.2 (SUP-2026-11-08-A): kalibreringen kjøres ferdig her, før
; «Ferdig»-boksen. Før startet den på en timer mens veiviseren gikk videre:
; «Ferdig» lå over WebMed mens brukeren skulle peke, og stoppet kalibreringen,
; ble grunnen straks overskrevet av «Skrift er klar».
OppsettKalibrering() {
    if K.kalVindu != ""
        return true
    valg := SkriftBoks("Oppsett 3 av 3: kalibrering",
        "Skriptet må måle hvor ting står i WebMed på denne skjermen (fem punkter du peker på). Det tar et par minutter og gjøres én gang per skjerm og skalering.`n`n"
        . "Før du trykker «Kalibrer nå»: WebMed skal være åpent og innlogget, med en fiktiv testpasient framme i journalen.",
        Map("na", "Kalibrer nå", "senere", "Senere (" K.tastMenyTekst " → 7)"), "sporsmal", 620)
    if valg = "na"
        return Kalibrer()
    return false
}

; v0.11.0 (Daniel 08.11: «configmeny der man kan velge hva som skal være med i
; innsjekk/dagsliste»): hva dagslisten henter fra journalen, som avkrysninger.
; Skrives til [innhold] i config.ini og gjelder fra neste kjøring. Menyen:
; Mer → Innhold i dagslisten. Legemiddelgjennomgangen henter alltid listen.
OppsettInnhold(*) {
    global K
    d := DialogNy("Innhold i dagslisten", "sporsmal", 640)
    DialogTekst(d, "Velg hva skriptet henter fra journalen for hver time i dagslisten. Timekommentaren fra Avtaler er alltid med. Jo mindre som hentes, jo raskere går det (siste konsultasjon er det som tar lengst tid). Legemiddelgjennomgangen fra menyen henter alltid legemiddellisten, uansett valget her.")
    valg := [["tidligere_sykdommer", "Tidligere sykdommer", K.innTidl]
        , ["familie_sosialt", "Familie/Sosialt", K.innFam]
        , ["legemiddelliste", "Legemiddellisten (settes inn i notatet med Ctrl+Alt+L og angres)", K.innLib]
        , ["siste_konsultasjon", "Siste konsultasjon fra Løpende journal (klikk i listen, krever kalibreringen)", K.jPa]]
    bokser := Map()
    for v in valg {
        c := d.g.AddCheckbox("x22 y" d.y " w" (d.w - 44) (v[3] ? " Checked" : ""), v[2])
        c.GetPos(, , , &h)
        d.y += h + 8
        bokser[v[1]] := c
    }
    d.y += 4
    kn := DialogKnapper(d, Map("ok", "Lagre", "avbryt", "Avbryt"))
    st := {svar: "avbryt", verdier: Map()}
    kn["ok"].OnEvent("Click", LagreInnhold)
    LagreInnhold(*) {
        for nokkel, c in bokser
            st.verdier[nokkel] := c.Value ? "1" : "0"
        st.svar := "ok"
        d.g.Destroy()
    }
    kn["avbryt"].OnEvent("Click", (*) => d.g.Destroy())
    d.g.OnEvent("Close", (*) => d.g.Destroy())
    d.g.OnEvent("Escape", (*) => d.g.Destroy())
    h := d.g.Hwnd
    d.g.Show("w" d.w " h" d.y)
    WinWaitClose h
    if st.svar != "ok"
        return false
    for nokkel, verdi in st.verdier
        IniWrite verdi, KONFIG, "innhold", nokkel
    K := LesKonfig()
    Logg("oppsett: innholdet i dagslisten satt til " InnholdTekst())
    Hint "Skrift: dagslisten henter " InnholdTekst() ".", "info"
    SetTimer HintSkjul, -6000
    return true
}

; Hele veiviseren. forste = true ved oppstart (viser velkomsten).
Veiviser(forste := true, *) {
    global K
    if forste {
        v := SkriftBoks("Velkommen til Skrift-skriptet for WebMed",
            "Dette er første gang skriptet kjører på denne PC-en, så vi setter det opp i tre steg: tokenet fra Skrift, sending på eller av, og kalibreringen av skjermen.`n`n"
            . "Skriptet leser i WebMed slik du selv gjør, med tastatur, mus og utklippstavlen, og lagrer aldri noe i journalen. Det er Eirskrifts eget verktøy, ikke en del av Skrift.md som medisinsk utstyr.",
            Map("start", "Start oppsettet", "senere", "Senere"), "info", 620)
        if v != "start" {
            Hint "Skrift " SKRIPT_VERSJON ": oppsettet er ikke gjort. " K.tastMenyTekst " → Mer → Oppsett når du vil gjøre det.", "varsel"
            SetTimer HintSkjul, -12000
            return
        }
    }
    if !OppsettToken()
        return
    if !OppsettBrytere()
        return
    OppsettKalibrering()
    OppsettFerdig()
    K := LesKonfig()
    LesSending()
    A_IconTip := "Skrift " SKRIPT_VERSJON " – " K.tastMenyTekst " åpner menyen (" Modus() ")"
    Hint "Skrift " SKRIPT_VERSJON " er klar. " K.tastMenyTekst " åpner menyen der du står (tallet velger). " ModusKort() "." OppsettIkkeKalibrert("`n")
    SetTimer HintSkjul, -15000
}

; v0.11.2: setningen om at skjermen ikke er kalibrert ennå ("" når den er det)
OppsettIkkeKalibrert(foran := "", bak := "") {
    if K.kalVindu != ""
        return ""
    return foran "Skjermen er ikke kalibrert ennå, så dagslisten og legemiddelgjennomgangen stopper til det er gjort: åpne en fiktiv testpasient i WebMed og velg " K.tastMenyTekst " og 7 (Kalibrer skjermpunktene)." bak
}

; Siste steg (v0.10.2, Daniel 02.11): hva skriptet kan, og tasten som åpner menyen.
; F11 er ledig i WebMed; F1 til F10 og F12 er WebMeds egne (F6 er Pasientoversikt).
OppsettFerdig() {
    loop {
        t := OppsettIkkeKalibrert("", "`n`n") "Slik bruker du skriptet:`n`n"
            . "• " K.tastMenyTekst " åpner menyen der du står. Tallet velger, piltastene og Enter virker også.`n"
            . "• I Avtaler: 1 legemiddelgjennomgang og 2 innsjekk for en time i boka, 6 dagslisten til Skrift (alle timene for dagen).`n"
            . "• I journalen med en pasient framme: 1 legemiddelgjennomgang og 2 innsjekk for den pasienten, 3 videorom (lenken til utklippstavlen og meldingen), 4 ring pasienten via Skrift, 5 lim inn meldingen med lenke og PIN-kode.`n"
            . "• I meldingen til pasienten: 5 lim inn meldingen, 3 videolenken.`n"
            . "• Linjer som ikke passer der du står, er grå med grunnen. Ctrl+Alt+X avbryter en kjøring. Hjelp og oppsett under Mer i menyen.`n"
            . "• Hva dagslisten henter fra journalen (tidligere sykdommer, familie/sosialt, legemiddellisten, siste konsultasjon) velger du under Mer, Innhold i dagslisten.`n`n"
            . "Menytasten er " K.tastMenyTekst ". F11 er ledig i WebMed; F1 til F10 og F12 bruker WebMed selv (F6 er Pasientoversikt), så en annen tast tar over den funksjonen i WebMed mens skriptet kjører."
        v := SkriftBoks("Ferdig: slik bruker du skriptet", t, Map("ok", "Ferdig", "tast", "Velg en annen menytast"), "ok", 640)
        if v != "tast"
            return
        ny := SkriftSpor("Menytasten", "Skriv tasten som skal åpne menyen (AutoHotkey-format):", "For eksempel F6, F9, ^F11 (Ctrl+F11) eller +F11 (Shift+F11). Tom = behold " K.tastMenyTekst ".")
        if ny = ""
            continue
        if !SettMenyTast(ny)
            SkriftBoks("Menytasten", "«" ny "» kunne ikke brukes som hurtigtast. Prøv en annen (for eksempel F6 eller ^F11).", "", "varsel")
    }
}

; Bytter tasten som åpner menyen, nå og i config.ini. Svar: true når den virket.
SettMenyTast(ny) {
    global K
    ny := Trim(ny)
    if ny = "" || ny = K.tastMeny
        return ny != ""
    try Hotkey ny, MenyTast, "On"
    catch
        return false
    try Hotkey K.tastMeny, MenyTast, "Off"
    IniWrite ny, KONFIG, "kjoring", "meny"
    K.tastMeny := ny
    K.tastMenyTekst := TastTekst(ny)
    Logg("oppsett: menytasten er nå " K.tastMenyTekst)
    try TrayMenyOppsett()
    return true
}
