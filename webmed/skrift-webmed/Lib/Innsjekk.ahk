; =============================================================================
; Lib\Innsjekk.ahk  –  dagsliste.ahk v0.6.0 (del B av v0.6, 27.10.2026)
;
; B1: innsjekk til legemiddelgjennomgang for én time i Avtaler. Timen åpnes
;     som i dagslisten (ApneTime: «Velg kontakt», «Ingen pasientkontakt»,
;     forhåndskontroll), legemiddellisten hentes med Ctrl+Alt+L, kopieres og
;     angres (LesLegemiddelliste), pasient-GUID-en kontrolleres i to kopier, og
;     timen lukkes (LukkTime). Så POST /checkins med kategori lmg, listen og
;     fødselsåret. [skrift] send_lmg=0: kroppen skrives til logg\ og ingenting
;     sendes.
; B2: meldingen til pasienten (copyText) limes inn én gang der markøren står,
;     bare i meldingsvinduet ([melding] vindu) eller i Notisblokk under test.
;
; Bruker funksjonene i dagsliste.ahk. PIN-koden, lenken, meldingen og
; pasient-GUID-en står bare i minnet, aldri i logg eller fil. Navnet vises bare
; på skjermen (kontrollspørsmålet).
; =============================================================================

global INNSJEKK := 0   ; {ref, tidspunkt, melding, pid, navn, fdato, laget, brukt} (bare i minnet)

; ---------------------------------------------------------------- felles ----

; Meldingen vises i en egen tråd, så en åpen boks ikke stenger tasten
; (funnet i del A: én tråd per hurtigtast). 0x40000 = alltid øverst.
Melding(tekst, ikon := "Iconi") {
    art := DialogArt(ikon)
    SetTimer(() => SkriftBoks(art = "stopp" ? "Stoppet" : art = "varsel" ? "Se her" : "Melding", tekst, "", art), -1)
}

SlippTaster() {
    KeyWait "Ctrl", "T2"
    KeyWait "Shift", "T2"
    KeyWait "Alt", "T2"
}

; «19.50», «19:50» eller «1950» -> «19:50». "" ved avbrudd eller ugyldig.
NormKlokkeslett(s) {
    if !RegExMatch(Trim(s), "^(\d{1,2})[.:]?(\d{2})$", &m) || Integer(m[1]) > 23 || Integer(m[2]) > 59
        return ""
    return Format("{:02d}:{:02d}", Integer(m[1]), Integer(m[2]))
}

; Datoen Avtaler viser (LISTEDATO), med samme regel som dagslisten: i dag,
; senere eller testdato. Svar: dokumentet i Avtaler. Kaster med beskjed ellers.
AvtalerMedDato(hwnd) {
    global LISTEDATO
    doc := hwnd ? FinnPlanner(hwnd) : 0
    if !doc
        throw Error("Gå til Avtaler i WebMed (F3) på datoen timen gjelder, og trykk tasten der.")
    url := ""
    try url := doc.Value
    LISTEDATO := LesListedato(url, FormatTime(, "yyyy-MM-dd"), K.testdato)
    if !InStr(url, "view=day") || !InStr(url, "viewType=list")
        throw Error("Avtaler må stå i dagsvisning som liste.")
    return doc
}

; Timen med klokkeslettet hhmm («19:50») på datoen i Avtaler. Flere timer på
; samme tid: brukeren velger blant initialer og fødselsdato. Svar: raden
; (LesRad), eller 0 når brukeren avbryter.
FinnTimeIAvtaler(doc, hhmm) {
    adv := []
    funn := []
    for t in LesDagsliste(doc, adv)
        if NormKlokkeslett(t.fra) = hhmm
            funn.Push(t)
    if !funn.Length
        throw Error("Fant ingen pasienttime " hhmm " i Avtaler " DatoNavn(LISTEDATO) ".")
    if funn.Length = 1
        return funn[1]
    linjer := []
    for t in funn
        linjer.Push(Referanse(t) "   " t.fdato)
    i := SkriftVelg("Velg time", "Flere timer kl. " hhmm ". Hvilken gjelder det?", linjer)
    return i ? funn[i] : 0
}

; v0.7.2 (Cowork 31.10, forslag 13): timene i Avtaler som en liste («HH:MM XX   ddmmåå»)
; i stedet for å skrive klokkeslettet. Brukeren velger med dobbeltklikk, Enter eller «Velg».
; v0.9.0 (Daniel 31.10): står det ingen pasienttimer, stopper det med beskjed – et
; klokkeslett som ikke finnes i boka, kan uansett ikke gi en time. Svar: raden, eller 0.
VelgTimeIAvtaler(doc, tittel) {
    adv := []
    timer := []
    try timer := LesDagsliste(doc, adv)
    if !timer.Length
        throw Error("Ingen pasienttimer i Avtaler " DatoNavn(LISTEDATO) ". Velg en dag med timer, eller åpne pasienten og trykk tasten i journalen.")
    linjer := []
    for t in timer
        linjer.Push(Referanse(t) "   " t.fdato)
    i := SkriftVelg(tittel, "Velg timen i Avtaler " DatoNavn(LISTEDATO) ":", linjer)
    return i ? timer[i] : 0
}

; Svaret fra Skrift tolket: {status, kode, melding, rad, vent (sekunder), j}
TolkSvar(svar) {
    r := {status: svar.status, kode: "", melding: "", rad: "", vent: VentSek(svar.vent), j: ""}
    try {
        j := JsonLes(svar.tekst)
        r.j := j
        if j is Map {
            if j.Has("error") && j["error"] is String
                r.kode := j["error"]
            if j.Has("message") && j["message"] is String
                r.melding := j["message"]
            if j.Has("rad") && (j["rad"] is Number)
                r.rad := j["rad"]
        }
    }
    return r
}

; Feilen til brukeren (handoffen §4). hva: «Innsjekken», «Ring», …
FeilForBruker(r, hva, rett := "") {
    vent := r.vent ? " Prøv igjen om " (r.vent < 60 ? r.vent " sekunder" : Ceil(r.vent / 60) " minutter") "." : ""
    ; Teksten fra Skrift: meldingen, ellers feilen når den ikke er en kode (for eksempel
    ; «Legemiddelgjennomgang er bare for leger»)
    fra := r.melding != "" ? r.melding : (r.kode != "" && !RegExMatch(r.kode, "^[A-Z0-9_]+$") ? r.kode : "")
    m := fra != "" ? " (" SubStr(fra, 1, 200) ")" : ""
    switch true {
        case r.status = 401:
            return hva ": tokenet virker ikke (" r.kode "). Lag et nytt i Skrift (Innstillinger → Integrasjoner) og lim det inn i tokenfilen."
        case r.kode = "SCOPE_MISSING":
            return hva ": tokenet mangler rettigheten «" rett "». Lag et nytt token med den i Skrift."
        case r.kode = "SKRIFT_IKKE_APEN":
            return "Skrift må være åpent i nettleseren. Åpne Skrift og trykk tasten igjen."
        case r.kode = "KOMMANDO_VENTER":
            return "En kommando venter allerede på et klikk i Skrift." vent
        case r.kode = "UGYLDIG_NUMMER":
            return "Skrift godtar ikke nummeret: det er ikke et norsk nummer som kan ringes."
        case r.kode = "TELEFON_IKKE_TILGJENGELIG":
            return "Telefonen i Skrift er ikke tilgjengelig for deg (TELEFON_IKKE_TILGJENGELIG)."
        case r.kode = "TELEFONKVOTE_BRUKT":
            return "Telefonminuttene i Skrift er brukt opp (TELEFONKVOTE_BRUKT)."
        case r.kode = "LISTE_IKKE_GJENKJENT":
            return "Skrift kunne ikke lese legemiddellisten sikkert" (r.rad != "" ? " (post nummer " r.rad ")" : "") ". Lag innsjekken i Skrift i stedet; der bekreftes listen før den sendes."
        case r.kode = "LISTE_FOR_LANG":
            return "Listen har over 80 legemidler. Lag innsjekken i Skrift i stedet."
        case r.kode = "FODSELSAR_MANGLER":
            return "Skrift trenger pasientens fødselsår før listen kan vises pasienten."
        case r.status = 403:
            return hva ": Skrift sa nei" m "."
        case r.status = 429:
            return "For mange kall til Skrift." (vent != "" ? vent : " Vent litt og prøv igjen.")
        case r.status >= 500:
            return hva ": Skrift svarte " r.status ". Prøv igjen senere."
        default:
            return hva ": Skrift svarte " r.status (r.kode != "" ? " " r.kode : "") m "."
    }
}

; Neste ledige filnavn: logg\<navn>-1.json, -2 …
NesteFil(navn) {
    DirCreate K.logg
    loop 999 {
        f := K.logg "\" navn "-" A_Index ".json"
        if !FileExist(f)
            return f
    }
    return K.logg "\" navn "-siste.json"
}

SkrivFil(fil, tekst) {
    try FileDelete fil
    FileAppend tekst, fil, "UTF-8-RAW"
}

; -------------------------------------------------- B1: legemiddelgjennomgang ----

; Kroppen til POST /checkins (handoffen §3). liste "" = uten liste (og uten fødselsår).
LmgKropp(ref, liste, far, tidsp) {
    n := "`n"
    j := "{" n '  "reference": ' JS(ref) "," n '  "kategori": "lmg",' n
    if liste != ""
        j .= '  "legemiddelliste": ' JS(liste) "," n
    if far
        j .= '  "fodselsar": ' Integer(far) "," n
    if tidsp != ""
        j .= '  "appointmentAt": ' JS(tidsp) "," n
    j .= '  "kilde": "WebMed",' n
    j .= '  "kildeVersjon": ' JS(KildeVersjon()) "," n
    j .= '  "skriptVersjon": ' JS(SKRIPT_VERSJON) n "}"
    return j
}

GyldigFodselsar(s) => RegExMatch(Trim(s), "^\d{4}$") && Integer(Trim(s)) >= 1900 && Integer(Trim(s)) <= Integer(A_YYYY)

SporFodselsar(ref) {
    svar := SkriftSpor("Fødselsår", "Pasientens fødselsår for " ref " (fire sifre). Pasienten må oppgi det før listen vises.", "Gjett ikke: et feil år stenger pasienten ute fra listen.")
    if svar = "" || !GyldigFodselsar(svar)
        return 0
    return Integer(svar)
}

LmgTast(*) {
    global KJORER, AVBRUTT, PASIENT_APEN, SETTE_PASIENTER, WM_VERSJON
    if KJORER
        return
    LesSending()
    hwnd := WinExist(K.vindu)
    ; v0.8.0 (Daniel 31.10): i journalen gjelder tasten pasienten som står framme
    if hwnd && MenyKontekst(hwnd) = "journal" {
        LmgFraJournal(hwnd)
        return
    }
    try {
        doc := AvtalerMedDato(hwnd)
    } catch as e {
        Melding(e.Message, "Icon!")
        return
    }
    try t := VelgTimeIAvtaler(doc, "Legemiddelgjennomgang")
    catch as e {
        Melding(e.Message, "Icon!")
        return
    }
    if !IsObject(t)
        return
    KJORER := true, AVBRUTT := false, PASIENT_APEN := ""
    t0 := A_TickCount
    lagret := ClipboardAll()
    plassering := "", ref := Referanse(t), les := 0
    Logg("=== Legemiddelgjennomgang v" SKRIPT_VERSJON " (" (K.sendLmg ? "sending PÅ" : "tørrkjøring") "), Avtaler " LISTEDATO " ===")
    try {
        if !SkriftJa("Legemiddelgjennomgang", "Lage innsjekk til legemiddelgjennomgang for`n`n" t.navn "`n" t.fdato "`nkl. " t.fra ", " DatoNavn(LISTEDATO) "?`n`nSkriptet henter legemiddellisten fra journalen. Ikke bruk mus eller tastatur imens.", "Ja, lag innsjekk", "Avbryt")
            throw Error("Avbrutt ved kontrollspørsmålet.")
        Hint "Skrift: henter legemiddellisten for " ref " … ikke bruk mus eller tastatur. " K.avbrytTekst " avbryter."
        pid := WinGetPID(hwnd)
        WM_VERSJON := ""
        try WM_VERSJON := FileGetVersion(WinGetProcessPath(hwnd))
        plassering := VinduForKjoring(hwnd, KalMal(), K.kalPos)
        Aktiver(hwnd)
        WinGetPos(, , &ww, &wh, hwnd)
        if (m := KalSjekk({vindu: K.kalVindu, dpi: K.kalDpi}, {vindu: ww "x" wh, dpi: VinduDpi(hwnd)}, K.kalibrerTekst)) != ""
            throw Error(m)
        SjekkVinduer(hwnd, pid, "start")
        SETTE_PASIENTER := Map()
        adv := []
        Logg("lmg " ref ": åpnes")
        ApneTime(hwnd, pid, t)
        tidl := KopierFelt(hwnd, "!s", "Tidligere sykdommer", adv)
        KontrollerPasientId(t, 1, [["Tidligere sykdommer", tidl]], false)
        lib := LesLegemiddelliste(hwnd, pid, adv)
        Logg("Legemiddelliste: " KopiLogg(lib.kopi) (lib.liste == lib.kopi.tekst ? "" : ", brukt: " StrLen(lib.liste) " tegn"))
        pasientId := KontrollerPasientId(t, 1, [["Tidligere sykdommer", tidl], ["Legemiddellisten", lib.kopi]])
        LukkTime(hwnd, pid, t, adv)
        try {
            VisAvtaler(hwnd)
            GaTilListedato(hwnd)
        }
        libFeil := false, ingen := false
        for a in adv {
            if InStr(a, "Lib/Cave ikke lest inn")
                libFeil := true
            if InStr(a, "Ingen legemidler registrert")
                ingen := true
        }
        les := {liste: lib.liste, libFeil: libFeil, ingen: ingen, pid: pasientId}
        Logg("lmg " ref ": lest på " (A_TickCount - t0) " ms")
    } catch as e {
        Logg("lmg " ref ": STOPP: " e.Message)
        tillegg := PASIENT_APEN != "" ? "`nPasienten for " PASIENT_APEN " står åpen i WebMed. Sjekk at notatfeltet er tomt før du lukker den selv." : ""
        if !InStr(e.Message, "Avbrutt ved kontrollspørsmålet") && !InStr(e.Message, "Ingen time valgt")
            Hint "Skrift: legemiddelgjennomgang STOPPET`n" e.Message tillegg "`nIngen innsjekk er laget."
        les := 0
    } finally {
        if IsObject(plassering) && hwnd
            VinduTilbake(hwnd, plassering)
        A_Clipboard := lagret
        lagret := ""
        KJORER := false
    }
    if !IsObject(les) {
        SetTimer HintSkjul, -30000
        return
    }
    LmgFerdig(les, ref, t, Tidspunkt(t.fra, LISTEDATO), t0)
}

; Resten av legemiddelgjennomgangen når listen er lest (fra Avtaler eller journalen):
; uten liste, fødselsår, kroppen, tørrkjøring eller sending. tidsp "" = ingen time.
LmgFerdig(les, ref, t, tidsp, t0) {
    if les.libFeil {
        Hint "Skrift: LIB ble ikke lest inn for " ref " (WebMed: «Lib/Cave ikke lest inn»).`nIngen innsjekk er laget. Prøv igjen senere."
        SetTimer HintSkjul, -30000
        return
    }
    far := 0, liste := les.liste
    if les.ingen || liste = "" {
        HintSkjul()
        if !SkriftJa("Legemiddelgjennomgang", "Ingen legemidler er registrert i LIB for " ref ".`n`nLage innsjekken uten liste? Pasienten skriver da legemidlene selv.", "Ja, uten liste", "Avbryt") {
            Logg("lmg " ref ": ingen liste, innsjekk ikke laget (brukerens valg)")
            return
        }
        liste := ""
    } else {
        far := t.fdato != "" ? FodselsarKjonn(t.fdato, LISTEDATO, FormatTime(, "yyyy-MM-dd")).ar : 0
        if !far
            far := AarFraFdato(t.fdato)   ; v0.10.4: fra journalen («dd.mm.åååå»)
        if !far {
            HintSkjul()
            far := SporFodselsar(ref)
            if !far {
                Logg("lmg " ref ": fødselsåret kunne ikke avgjøres, innsjekk ikke laget")
                Melding("Ingen innsjekk er laget: fødselsåret mangler.", "Icon!")
                return
            }
        }
    }
    kropp := LmgKropp(ref, liste, far, tidsp)
    Logg("lmg " ref ": liste " StrLen(liste) " tegn, " (liste = "" ? 0 : StrSplit(Trim(StrReplace(liste, "`r"), "`n"), "`n").Length) " linjer, fødselsår " (far ? "med" : "uten"))
    if !K.sendLmg {
        fil := NesteFil("torrkjoring-lmg")
        SkrivFil(fil, kropp)
        Logg("lmg " ref ": tørrkjøring skrevet til " StrReplace(fil, K.logg "\", "") " (" StrLen(kropp) " tegn)")
        Hint "Skrift: tørrkjøring skrevet (" ref ").`n" fil "`nIngenting er sendt ([skrift] send_lmg=0)."
        SetTimer HintSkjul, -30000
        return
    }
    SendLmg(kropp, ref, liste, tidsp, les.pid, t0, t)
}

SendLmg(kropp, ref, liste, tidsp, pasientId, t0, t, art := "lmg") {
    global INNSJEKK
    Hint "Skrift: lager innsjekken for " ref " …"
    try tok := LesToken()
    catch as e {
        Hint "Skrift: " e.Message "`nIngen innsjekk er laget."
        SetTimer HintSkjul, -30000
        return
    }
    loop 2 {
        t1 := A_TickCount
        try svar := KallSkrift("POST", "/checkins", kropp, tok)
        catch as e {
            tok := ""
            Logg("POST /checkins " art " " ref ": nettverksfeil (" e.Message ")")
            Hint "Skrift: fikk ikke kontakt med Skrift (" e.Message ").`nIngen innsjekk er laget."
            SetTimer HintSkjul, -30000
            return
        }
        r := TolkSvar(svar)
        Logg("POST /checkins " art " " ref ": " svar.status (r.kode != "" ? " " r.kode : "") (r.vent ? ", Retry-After " r.vent " s" : "") " på " (A_TickCount - t1) " ms")
        if svar.status = 400 && r.kode = "FODSELSAR_MANGLER" && A_Index = 1 && liste != "" {
            HintSkjul()
            far := SporFodselsar(ref)
            if !far
                break
            kropp := LmgKropp(ref, liste, far, tidsp)
            continue
        }
        break
    }
    tok := ""
    if svar.status != 201 {
        ; v0.10.2: kroppen (med legemiddellisten) skrives ikke til disk når sendingen er på
        if (r.kode = "LISTE_IKKE_GJENKJENT" || r.kode = "LISTE_FOR_LANG") && K.jsonVedSending {
            fil := NesteFil("torrkjoring-lmg-" r.status)
            SkrivFil(fil, kropp)
            Logg(art " " ref ": kroppen tatt vare på i " StrLen(kropp) " tegn til " StrReplace(fil, K.logg "\", "") (r.rad != "" ? ", rad " r.rad : ""))
        } else if r.kode = "LISTE_IKKE_GJENKJENT" || r.kode = "LISTE_FOR_LANG"
            Logg(art " " ref ": listen ble ikke lest av Skrift (" r.kode (r.rad != "" ? ", rad " r.rad : "") "); lag innsjekken i Skrift, der listen kontrolleres")
        Hint "Skrift: ingen innsjekk for " ref ".`n" FeilForBruker(r, "Innsjekken", "innsjekk")
        SetTimer HintSkjul, -60000
        return
    }
    j := r.j, pin := "", copy := "", rader := "?", adv := []
    try pin := j["pin"]
    try copy := j["copyText"]
    try rader := j["antallRader"]
    try {
        for a in j["advarsler"]
            adv.Push(a)
    }
    INNSJEKK := {ref: ref, tidspunkt: tidsp, melding: copy, pid: pasientId, navn: t.navn, fdato: t.fdato, laget: A_TickCount, brukt: false}
    copy := ""
    Logg(art " " ref ": innsjekk laget, antallRader " rader ", advarsler " adv.Length ", melding " StrLen(INNSJEKK.melding) " tegn, " (A_TickCount - t0) " ms fra tasten")
    HintSkjul()
    VisPin(pin, rader, adv, ref)
    pin := ""
}

; v0.7.1 (Daniel 30.10: «ingen behov for at PIN-koden skal vises der sånn»):
; vinduet viser ikke koden stort, men hele meldingen til pasienten i et felt som
; kan kopieres (lenke og PIN-kode står i den), og at Ctrl+Shift+F10 limer den inn.
VisPin(pin, rader, adv, ref) {
    global INNSJEKK
    d := DialogNy("Innsjekken er laget (" ref ")", "ok", 640)
    DialogTekst(d, (rader = "?" ? "" : rader " legemiddel" (rader = 1 ? "" : "er") " i listen pasienten får. ") "Meldingen til pasienten (lenke og PIN-kode) er klar: åpne meldingen i WebMed og trykk " K.tastLimInnTekst " der (én gang, innen 30 minutter), eller kopier den herfra.")
    for a in adv
        DialogTekst(d, "Advarsel: " a, "cB35C00")
    ; Daniel 31.10: feltet skal romme hele meldingen uten rulling (høyst 30 rader).
    ; v0.10.3 (rapportfunn 1): lange linjer brytes i feltet (Consolas 10 på 596 px
    ; er om lag 75 tegn per rad), så radene telles med brytingen, ikke bare linjene
    tekst := IsObject(INNSJEKK) ? INNSJEKK.melding : ""
    rader := Min(30, Max(4, TekstRader(tekst, Floor((d.w - 52) / 8)) + 1))
    d.g.SetFont("s10 norm c1F1F1F", "Consolas")
    e := d.g.AddEdit("x22 y" d.y " w" (d.w - 44) " r" rader " ReadOnly", tekst)
    d.g.SetFont("s11 norm c1F1F1F", "Segoe UI")
    e.GetPos(, , , &eh)
    d.y += eh + 12
    kn := DialogKnapper(d, Map("lukk", "Lukk"))
    kn["lukk"].OnEvent("Click", (*) => d.g.Destroy())
    d.g.OnEvent("Close", (*) => d.g.Destroy())
    d.g.OnEvent("Escape", (*) => d.g.Destroy())
    d.g.Show("w" d.w " h" d.y)
    ; v0.9.1 (funn 12): fokus på Lukk, ikke i tekstfeltet (som markerte hele meldingen)
    try kn["lukk"].Focus()
}

; ------------------------------------------ v0.8.0: fra journalen (Daniel 31.10) ----
; «Det må være veldig lett å lage en innsjekk eller legemiddelgjennomgang DIREKTE
; fra pasientjournalen på den man står på.» Navnet leses fra «Lukk pasienter»
; (Alt+X, så Avbryt), som forhåndskontrollen i dagslisten. Ingen tur innom Avtaler,
; pasienten blir stående åpen, notatet røres bare av Ctrl+Alt+L med angring.
; Referansen var «initialer dd.mm» (ingen time); v0.10.4 (Daniel 03.11: «Det skal
; være initialer og fødselsdato når man lager innsjekk fra en pasient som ikke er
; knyttet til en time»): «initialer dd.mm.åååå». «Lukk pasienter» har ikke
; fødselsdatoen, så den leses fra tittelen på meldingsvinduet («e-kontakt for
; NAVN ddmmåå ddddd», Ctrl+3), som lukkes igjen med en gang; kommer vinduet ikke
; (pasienten er ikke digitalt aktiv), spør skriptet. Fødselsåret til LMG-innsjekken
; kommer fra datoen, så Skrift spør ikke lenger (FODSELSAR_MANGLER bare som reserve).
; Innsjekken får ingen appointmentAt. Loggen viser aldri datoen (RensFnr).

; Pasienten som står framme. Svar: {navn, fdato: "dd.mm.åååå", fra: "", id: ""}.
PasientIJournalen(hwnd, pid) {
    dlg := ApneLukkDialog(hwnd, pid)
    navn := LukkDialogNavn(dlg)
    TrykkKnapp(dlg, "Avbryt")
    if !VentPaa(() => !FinnLukkDialog(pid, hwnd), 3000)
        throw Error("«Lukk pasienter» forsvant ikke etter Avbryt")
    Sleep 200
    if navn.Length != 1
        throw Error("«Lukk pasienter» viser " navn.Length " pasient(er). Ha bare én pasient framme.")
    fdato := FdatoFraMelding(hwnd, pid)
    if fdato = "" {
        HintSkjul()
        fdato := SporFdato(navn[1])
        if fdato = ""
            throw Error("Avbrutt: fødselsdatoen mangler, ingen innsjekk er laget.")
    }
    return {navn: navn[1], fdato: fdato, fra: "", id: ""}
}

JournalReferanse(t) => Initialer(t.navn) " " (t.HasOwnProp("fdato") && t.fdato != "" ? t.fdato : FormatTime(, "dd.MM"))

; v0.10.4: fødselsdatoen fra tittelen på meldingsvinduet (åpnes med melding_tast og
; lukkes igjen uten å røre teksten). "" når vinduet ikke kom eller tittelen ikke
; har fødselsnummeret. Tittelen logges aldri.
FdatoFraMelding(hwnd, pid) {
    Aktiver(hwnd)
    Send K.meldingTast
    mv := VentPaa(() => FinnMeldingsvindu(pid), 4000)
    if !mv {
        Logg("fødselsdato: meldingsvinduet kom ikke på 4 s (pasienten ikke digitalt aktiv?); spør brukeren")
        return ""
    }
    tit := ""
    try tit := WinGetTitle(mv)
    fd := FdatoFraTittel(tit)
    try WinClose mv
    if !VentPaa(() => !FinnMeldingsvindu(pid), 3000)
        Logg("fødselsdato: meldingsvinduet lot seg ikke lukke; lukk det selv")
    Sleep 150
    Aktiver(hwnd)
    if fd = ""
        Logg("fødselsdato: fant ikke fødselsnummeret i tittelen på meldingsvinduet; spør brukeren")
    return fd
}

; «… for NAVN ddmmåå ddddd» → «dd.mm.åååå» (århundret: ikke fram i tid). "" ellers.
FdatoFraTittel(tit, idag := "") {
    if !RegExMatch(tit, " (\d{2})(\d{2})(\d{2}) ?\d{5}$", &m)
        return ""
    return NormFdato(m[1] m[2] m[3], idag)
}

; «ddmmåå», «ddmmåååå», «dd.mm.åå» eller «dd.mm.åååå» → «dd.mm.åååå»; "" når
; datoen ikke finnes. To sifre i året: det siste århundret som ikke gir en dato
; fram i tid.
NormFdato(s, idag := "") {
    idag := idag != "" ? idag : FormatTime(, "yyyyMMdd")
    d := RegExReplace(s, "\D")
    if !RegExMatch(d, "^(\d{2})(\d{2})(\d{2}|\d{4})$", &m)
        return ""
    if StrLen(m[3]) = 4
        aar := Integer(m[3])
    else {
        aar := 2000 + Integer(m[3])
        if Format("{:04d}{}{}", aar, m[2], m[1]) > idag
            aar -= 100
    }
    if !IsTime(Format("{:04d}{}{}", aar, m[2], m[1])) || aar < 1900
        return ""
    return m[1] "." m[2] "." aar
}

; Fødselsåret fra «dd.mm.åååå» (0 når datoen mangler)
AarFraFdato(fdato) => RegExMatch(fdato, "^\d{2}\.\d{2}\.(\d{4})$", &m) ? Integer(m[1]) : 0

SporFdato(navn) {
    loop {
        svar := SkriftSpor("Fødselsdato", "Pasientens fødselsdato for " navn " (ddmmåå eller dd.mm.åååå). Den blir en del av referansen i Skrift, og året sendes med en legemiddelgjennomgang.", "Står i pasientbanneret i WebMed. Avbryt lager ingen innsjekk.")
        if svar = ""
            return ""
        fd := NormFdato(svar)
        if fd != ""
            return fd
        Melding("Skriv datoen som ddmmåå eller dd.mm.åååå.", "Icon!")
    }
}

LmgFraJournal(hwnd) {
    global KJORER, AVBRUTT, PASIENT_APEN, SETTE_PASIENTER, WM_VERSJON
    if KJORER
        return
    KJORER := true, AVBRUTT := false, PASIENT_APEN := ""
    t0 := A_TickCount
    lagret := ClipboardAll()
    plassering := "", les := 0, ref := "", t := 0
    Logg("=== Legemiddelgjennomgang fra journalen v" SKRIPT_VERSJON " (" (K.sendLmg ? "sending PÅ" : "tørrkjøring") ") ===")
    try {
        pid := WinGetPID(hwnd)
        WM_VERSJON := ""
        try WM_VERSJON := FileGetVersion(WinGetProcessPath(hwnd))
        plassering := VinduForKjoring(hwnd, KalMal(), K.kalPos)
        Aktiver(hwnd)
        WinGetPos(, , &ww, &wh, hwnd)
        if (m := KalSjekk({vindu: K.kalVindu, dpi: K.kalDpi}, {vindu: ww "x" wh, dpi: VinduDpi(hwnd)}, K.kalibrerTekst)) != ""
            throw Error(m)
        SjekkVinduer(hwnd, pid, "start")
        t := PasientIJournalen(hwnd, pid)
        ref := JournalReferanse(t)
        PASIENT_APEN := ref
        if !SkriftJa("Legemiddelgjennomgang", "Lage innsjekk til legemiddelgjennomgang for pasienten som er åpen,`n`n" t.navn "`n(referanse «" ref "»)?`n`nSkriptet henter legemiddellisten fra journalen. Ikke bruk mus eller tastatur imens.", "Ja, lag innsjekk", "Avbryt")
            throw Error("Avbrutt ved kontrollspørsmålet.")
        Hint "Skrift: henter legemiddellisten for " ref " … ikke bruk mus eller tastatur. " K.avbrytTekst " avbryter."
        Aktiver(hwnd)
        SETTE_PASIENTER := Map()
        adv := []
        tidl := KopierFelt(hwnd, "!s", "Tidligere sykdommer", adv)
        KontrollerPasientId(t, 1, [["Tidligere sykdommer", tidl]], false)
        lib := LesLegemiddelliste(hwnd, pid, adv)
        Logg("Legemiddelliste: " KopiLogg(lib.kopi) (lib.liste == lib.kopi.tekst ? "" : ", brukt: " StrLen(lib.liste) " tegn"))
        pasientId := KontrollerPasientId(t, 1, [["Tidligere sykdommer", tidl], ["Legemiddellisten", lib.kopi]])
        libFeil := false, ingen := false
        for a in adv {
            if InStr(a, "Lib/Cave ikke lest inn")
                libFeil := true
            if InStr(a, "Ingen legemidler registrert")
                ingen := true
        }
        les := {liste: lib.liste, libFeil: libFeil, ingen: ingen, pid: pasientId}
        Logg("lmg " ref ": lest fra journalen på " (A_TickCount - t0) " ms")
    } catch as e {
        Logg("lmg " (ref != "" ? ref : "journalen") ": STOPP: " e.Message)
        if !InStr(e.Message, "Avbrutt ved kontrollspørsmålet")
            Hint "Skrift: legemiddelgjennomgang STOPPET`n" e.Message "`nIngen innsjekk er laget. Pasienten står åpen; sjekk at notatfeltet er tomt."
        les := 0
    } finally {
        if IsObject(plassering) && hwnd
            VinduTilbake(hwnd, plassering)
        A_Clipboard := lagret
        lagret := ""
        KJORER := false
    }
    if !IsObject(les) {
        SetTimer HintSkjul, -30000
        return
    }
    LmgFerdig(les, ref, t, "", t0)
}

; ----------------------------------------------------- B2: lim inn meldingen ----

LimInnTast(*) {
    global INNSJEKK
    hwnd := WinExist("A")
    if !IsObject(INNSJEKK) || INNSJEKK.brukt || INNSJEKK.melding = "" || A_TickCount - INNSJEKK.laget > 30 * 60 * 1000 {
        if IsObject(INNSJEKK) && !INNSJEKK.brukt && A_TickCount - INNSJEKK.laget > 30 * 60 * 1000
            INNSJEKK.melding := ""
        Logg("lim inn: ingen melding i minnet")
        Melding("Ingen melding å lime inn. Lag innsjekken med " K.tastLmgTekst " først. Meldingen gjelder i 30 minutter og limes inn én gang.", "Icon!")
        return
    }
    erMelding := (K.meldingVindu != "" && WinActive(K.meldingVindu)) || ErMeldingsvindu(hwnd)
    erTest := K.meldingNotisblokk && WinActive("ahk_exe notepad.exe")
    ; v0.9.0: fra journalen åpnes meldingen til pasienten først (melding_tast), så
    ; kontrolleres og limes den inn som før
    if !(erMelding || erTest) && MenyKontekst(hwnd) = "journal" {
        mv := ApneMelding(hwnd)
        if !mv {
            Logg("lim inn " INNSJEKK.ref ": meldingsvinduet kom ikke fra journalen")
            Melding("Meldingsvinduet kom ikke (er pasienten digitalt aktiv?). Åpne meldingen selv (" TastTekst(K.meldingTast) ") og trykk " K.tastLimInnTekst " der.", "Icon!")
            return
        }
        hwnd := mv, erMelding := true
    }
    if !(erMelding || erTest) {
        kl := ""
        try kl := WinGetClass(hwnd)
        Logg("lim inn " INNSJEKK.ref ": nektet, aktivt vindu er ikke meldingsvinduet (klasse " kl ")")
        Melding("Meldingen limes bare inn i meldingsvinduet i WebMed" (K.meldingNotisblokk ? " (eller Notisblokk under test)" : "") ". Sett markøren i tekstfeltet der og trykk " K.tastLimInnTekst " igjen.", "Icon!")
        return
    }
    if erMelding && !FokusITekstfeltet(hwnd) {
        Logg("lim inn " INNSJEKK.ref ": nektet, markøren står ikke i meldingsteksten")
        Melding("Sett markøren i selve meldingsteksten (det store feltet, ikke emnet) og trykk " K.tastLimInnTekst " igjen.", "Icon!")
        return
    }
    ; Pasientkontroll (B2, H-e): navnet og fødselsdatoen i tittelen på meldingsvinduet
    ; mot timen innsjekken ble laget for. Uten sikker kontroll må brukeren si ja.
    kontroll := erMelding ? KontrollerMottaker(hwnd) : "ukjent"
    if kontroll = "ulik" {
        Logg("lim inn " INNSJEKK.ref ": nektet, mottakeren er en annen pasient")
        Melding("Meldingen gjelder «" INNSJEKK.ref "», men meldingsvinduet er for en annen pasient. Ingenting er limt inn.", "Iconx")
        return
    }
    if kontroll != "lik" {
        if !SkriftJa("Lim inn meldingen", "Lim inn meldingen for «" INNSJEKK.ref "» her?`n`nKontroller at meldingen går til riktig pasient.", "Ja, lim inn", "Avbryt", "varsel") {
            Logg("lim inn " INNSJEKK.ref ": avbrutt av brukeren")
            return
        }
        WinActivate hwnd
        if !WinWaitActive(hwnd, , 2) {
            Melding("Vinduet ble ikke aktivt igjen. Ingenting er limt inn.", "Icon!")
            return
        }
    }
    SlippTaster()
    tekst := StrReplace(INNSJEKK.melding, "`r`n", "`n")
    t1 := A_TickCount
    SendText tekst
    Logg("lim inn " INNSJEKK.ref ": " StrLen(tekst) " tegn limt inn på " (A_TickCount - t1) " ms (" (erMelding ? "meldingsvinduet" : "Notisblokk") ", kontroll: " kontroll ")")
    INNSJEKK.melding := "", INNSJEKK.brukt := true
}

; Meldingsvinduet i WebMed (kartlagt 27.10, B2): et eget WPF-vindu i WebMeds prosess
; med tittelen «e-kontakt for FORNAVN ETTERNAVN dddddd ddddd» (typen, navnet og
; fødselsnummeret), og InitiateDialogControlView i tilgjengelighetslaget.
ErMeldingsvindu(hwnd) {
    try {
        if WinGetProcessName(hwnd) != "TNW.Desktop.WPF.exe"
            return false
        if !RegExMatch(WinGetTitle(hwnd), "^.+? for .+ \d{6} ?\d{5}$")
            return false
        return !!UIA.ElementFromHandle(hwnd).ElementExist({ClassName: "InitiateDialogControlView"})
    }
    return false
}

; Markøren i meldingsteksten: det fokuserte elementet er en TextBox som er høyere enn
; emnefeltet (teksten er om lag 300 px høy ved 100 %, emnet 46 px).
FokusITekstfeltet(hwnd) {
    try {
        f := UIA.GetFocusedElement()
        if f.ClassName != "TextBox"
            return false
        r := f.BoundingRectangle
        return (r.b - r.t) > 100 * KalSkala(VinduDpi(hwnd))
    }
    return false
}

; Er meldingsvinduet for samme pasient som innsjekken? Navnet i tittelen mot navnet
; i timen (ordene, uten hensyn til rekkefølge og store bokstaver) og de seks første
; sifrene i fødselsnummeret mot fødselsdatoen i timen («ddmmåå»). Svar: "lik", "ulik"
; eller "ukjent". Navn og fødselsnummer brukes bare her og logges aldri.
KontrollerMottaker(hwnd) {
    if !IsObject(INNSJEKK) || !INNSJEKK.HasOwnProp("navn")
        return "ukjent"
    tit := ""
    try tit := WinGetTitle(hwnd)
    if !RegExMatch(tit, "^.+? for (.+) (\d{6}) ?\d{5}$", &m)
        return "ukjent"
    navnOk := SammeNavn(m[1], INNSJEKK.navn)
    datoOk := SubStr(RegExReplace(INNSJEKK.fdato, "\D"), 1, 6) == m[2]
    return navnOk && datoOk ? "lik" : "ulik"
}
