; =============================================================================
; Meny.ahk  –  menyen (v0.9, Daniel 31.10: «én enkel og lett hurtigtast som
; åpner en meny med alle muligheter, men har grået ut de veiene som ikke
; fungerer der»).
;
; Én tast ([kjoring] meny, F11 – WebMed bruker F1–F10 og F12) åpner menyen ved
; musepekeren. Menyen er den samme overalt, i samme rekkefølge, så den sitter i
; fingrene: tallet velger linjen (F11, 1 = legemiddelgjennomgang; F11, 6 =
; dagslisten), piltastene og Enter virker også, og musen. Det som ikke passer
; flaten brukeren står i, er grått med grunnen bak en tankestrek. Første linje
; sier hvilken flate menyen gjelder. Hurtigtastene fra v0.6 (Ctrl+Shift+F6 …
; F12) står bak linjene og virker som før; de kan tømmes i config.ini.
; Mens skriptet kjører, er alt grått unntatt «Avbryt».
; Menyen tar fokus et øyeblikk; vinduet som var aktivt (med markert tekst eller
; markøren) aktiveres igjen før valget utføres.
; =============================================================================

; Flaten brukeren står i: "avtaler", "journal", "melding", "sms" eller "annet".
MenyKontekst(hwnd) {
    try {
        if ErMeldingsvindu(hwnd)
            return "melding"
        if K.smsVindu != "" && WinExist(K.smsVindu " ahk_id " hwnd)
            return "sms"
        hv := WebMedHoved(hwnd)
        if hv {
            doc := 0
            try doc := FinnPlanner(hv)
            return doc ? "avtaler" : "journal"
        }
    }
    return "annet"
}

MenyNavn(kontekst) {
    switch kontekst {
        case "avtaler": return "Avtaler"
        case "journal": return "journalen"
        case "melding": return "meldingen til pasienten"
        case "sms": return "«Send SMS»"
    }
    return "utenfor WebMed"
}

; Linjene i menyen: alltid de samme åtte, i samme rekkefølge, som
; {navn, nr, tekst, tast, fn, av, grunn}; «sep» er en skillelinje. Det som ikke
; passer flaten, er av (grått) med grunnen. Ren funksjon, så den kan testes
; uten vinduer. kjorer: skriptet holder på (alt grått unntatt avbryt).
MenyValg(kontekst, harMelding := false, ref := "", kjorer := false) {
    v := []
    L := (navn, nr, tekst, tast, fn, grunn := "") => v.Push({navn: navn, nr: nr, tekst: tekst, tast: tast, fn: fn, av: grunn != "", grunn: grunn})
    iWebMed := kontekst = "avtaler" || kontekst = "journal"
    ; Grunnen når linjen ikke passer flaten («» = linjen er på)
    g := (iWebMed ? "" : kontekst = "melding" ? "lukk meldingen først" : kontekst = "sms" ? "lukk «Send SMS» først" : "åpne WebMed")
    kj := kjorer ? "skriptet kjører" : ""   ; (ikke k: K er konfigurasjonen, og AutoHotkey skiller ikke store og små)
    denne := kontekst = "journal" ? "for denne pasienten" : "for en time"
    L("lmg", 1, "Legemiddelgjennomgang " denne " …", K.tastLmgTekst, "LmgTast", kj != "" ? kj : g)
    L("ny", 2, "Innsjekk " denne " (time eller skjema) …", K.tastNyInnsjekkTekst, "NyInnsjekkTast", kj != "" ? kj : g)
    L("video", 3, kontekst = "journal" ? "Videorom: lenken til utklippstavlen og meldingen" : kontekst = "melding" ? "Videorom: lim inn lenken her" : "Videorom: lenken til utklippstavlen"
        , K.tastVideoTekst, "VideoTast", kj != "" ? kj : kontekst = "sms" ? g : "")
    L("ring", 4, iWebMed || kontekst = "melding" ? "Ring pasienten via Skrift" : "Ring markert nummer via Skrift", K.tastRingTekst, "RingTast"
        , kj != "" ? kj : kontekst = "avtaler" ? "åpne pasienten først" : kontekst = "sms" ? g : "")
    mg := kj != "" ? kj : !harMelding ? "lag innsjekken først (1 eller 2)" : kontekst = "journal" || kontekst = "melding" ? "" : kontekst = "avtaler" ? "åpne pasienten først" : kontekst = "sms" ? g : "åpne meldingen til pasienten i WebMed"
    L("melding", 5, "Lim inn meldingen til pasienten" (harMelding ? " (" ref ")" : "") (kontekst = "journal" && harMelding ? ": åpner meldingen" : ""), K.tastLimInnTekst, "LimInnTast", mg)
    L("dag", 6, "Dagslisten til Skrift (" (K.send ? "sender" : "tørrkjøring") ")", K.hurtigtastTekst, "KjorDagsliste", kj != "" ? kj : g)
    v.Push({navn: "sep"})
    L("kalibrer", 7, "Kalibrer skjermpunktene …", K.kalibrerTekst, "Kalibrer", kj != "" ? kj : iWebMed ? "" : "åpne en fiktiv testpasient i WebMed")
    L("avbryt", 8, "Avbryt kjøringen", K.avbrytTekst, "Avbryt", kjorer ? "" : "ingenting kjører")
    return v
}

; Teksten på en linje: «&1  Legemiddelgjennomgang …  – grunnen	Ctrl+Shift+F9»
MenyLinjeTekst(x) => "&" x.nr "  " x.tekst (x.av && x.grunn != "" ? "  – " x.grunn : "") (x.tast != "" && x.tast != "(av)" ? "`t" x.tast : "")

MenyTast(*) {
    global INNSJEKK, KJORER
    hwnd := WinExist("A")
    kontekst := MenyKontekst(hwnd)
    harMelding := IsObject(INNSJEKK) && !INNSJEKK.brukt && INNSJEKK.melding != "" && A_TickCount - INNSJEKK.laget <= 30 * 60 * 1000
    ref := harMelding ? INNSJEKK.ref : ""
    Logg("meny: " kontekst (KJORER ? " (kjører)" : ""))
    m := Menu()
    Valg(fn, *) {
        try {
            WinActivate hwnd
            WinWaitActive hwnd, , 1
        }
        %fn%()
    }
    m.Add("Skrift · " MenyNavn(kontekst) (KJORER ? " · kjører …" : kontekst = "sms" ? " (lukk det uten å sende)" : ""), (*) => 0)
    m.Disable("1&")
    m.Add()
    n := 2
    for x in MenyValg(kontekst, harMelding, ref, KJORER) {
        n++
        if x.navn = "sep" {
            m.Add()
            continue
        }
        m.Add(MenyLinjeTekst(x), Valg.Bind(x.fn))
        if x.av
            m.Disable(n "&")
    }
    m.Add()
    m.Add("Mer", MenyMer(hwnd))
    m.Add("Brytere: " ModusKort(), (*) => 0)
    m.Disable((n + 3) "&")
    s := StartSjekk()
    if s != "" {
        m.Add("Kalibrer på nytt: skjermen er ikke som ved kalibreringen", Valg.Bind("Kalibrer"))
    }
    ; v0.9.1 (funn 14): vis menyen innenfor skjermen når pekeren står nær høyre
    ; eller nedre kant (menyen er om lag 420 x 380 px ved 100 %)
    pos := MenyPosisjon()
    m.Show(pos.x, pos.y)
}

; Punktet menyen vises på: musepekeren, klemt inn fra høyre og nedre skjermkant.
MenyPosisjon() {
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    s := A_ScreenDPI / 96
    bredde := Round(420 * s), hoyde := Round(380 * s)
    try MonitorGet(MonitorGetPrimary(), &ml, &mt, &mr, &mb)
    catch {
        ml := 0, mt := 0, mr := A_ScreenWidth, mb := A_ScreenHeight
    }
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if mx >= l && mx < r && my >= t && my < b {
            ml := l, mt := t, mr := r, mb := b
            break
        }
    }
    return {x: Max(ml, Min(mx, mr - bredde)), y: Max(mt, Min(my, mb - hoyde))}
}

; Undermenyen «Mer»: det som sjelden trengs
MenyMer(hwnd := 0) {
    u := Menu()
    u.Add("Åpne loggen for i dag", (*) => ApneFil(K.logg "\" FormatTime(, "yyyy-MM-dd") ".txt"))
    u.Add("Åpne config.ini", (*) => ApneFil(KONFIG))
    u.Add("Tastene og flatene (hjelp)", (*) => VisHjelp())
    u.Add("Oppsett (tokenet, bryterne, kalibreringen)", (*) => Veiviser(false))
    u.Add("Innhold i dagslisten (hva som hentes fra journalen) …", (*) => OppsettInnhold())
    u.Add()
    u.Add("Avslutt skriptet", (*) => AvsluttSkript())
    return u
}

ModusKort() => "dagslisten " (K.send ? "SENDES" : "tørrkjøring") " · legemiddelgjennomgang/innsjekk " (K.sendLmg ? "SENDES" : "tørrkjøring") " · ring/video " (K.sendKommando ? "SENDES" : "tørrkjøring")

ApneFil(sti) {
    if !FileExist(sti) {
        Melding("Finner ikke " sti, "Icon!")
        return
    }
    try Run sti
    catch
        Run 'notepad.exe "' sti '"'
}

AvsluttSkript() {
    global KJORER
    if KJORER && !SkriftJa("Avslutt", "Skriptet kjører. Avslutte likevel?", "Ja, avslutt", "Nei", "varsel")
        return
    ExitApp
}

VisHjelp() {
    t := "Skrift-skriptet " SKRIPT_VERSJON "`n`n"
        . K.tastMenyTekst " åpner menyen der du står; tallet (1–8) velger linjen, piltastene og Enter virker også.`n`n"
        . "I Avtaler: 1 legemiddelgjennomgang og 2 innsjekk for en time (velg timen i listen), 6 dagslisten til Skrift.`n"
        . "I journalen (pasienten framme): 1 og 2 for den pasienten, 3 videorom til utklippstavlen og meldingen, 4 ring, 5 lim inn meldingen.`n"
        . "I meldingen til pasienten: 5 lim inn meldingen, 3 videolenken, 4 ring.`n"
        . "Utenfor WebMed: 4 ring et markert nummer, 3 videolenken til utklippstavlen.`n`n"
        . "Grått = passer ikke der du står; grunnen står bak linjen.`n`n"
        . "Hurtigtastene virker fortsatt: " K.hurtigtastTekst " dagslisten, " K.tastLmgTekst " legemiddelgjennomgang, " K.tastNyInnsjekkTekst " innsjekk, " K.tastLimInnTekst " lim inn, " K.tastRingTekst " ring, " K.tastVideoTekst " videorom, " K.kalibrerTekst " kalibrer, " K.avbrytTekst " avbryt.`n`n"
        . "Brytere: " ModusKort() ". Dagslisten henter: " InnholdTekst() " (Mer → Innhold i dagslisten). Alt i config.ini."
    SkriftBoks("Hjelp", t, Map("ok", "Lukk"), "info", 560)
}

; Ikonet nede til høyre: det samme som menyen, uten flaten
TrayMenyOppsett() {
    tm := A_TrayMenu
    tm.Delete()
    tm.Add("Skrift-menyen`t" K.tastMenyTekst, (*) => MenyTast())
    tm.Add("Dagslisten til Skrift`t" K.hurtigtastTekst, (*) => KjorDagsliste())
    tm.Add("Kalibrer skjermpunktene …`t" K.kalibrerTekst, (*) => Kalibrer())
    tm.Add("Avbryt kjøringen`t" K.avbrytTekst, (*) => Avbryt())
    tm.Add()
    tm.Add("Åpne loggen for i dag", (*) => ApneFil(K.logg "\" FormatTime(, "yyyy-MM-dd") ".txt"))
    tm.Add("Åpne config.ini", (*) => ApneFil(KONFIG))
    tm.Add("Innhold i dagslisten …", (*) => OppsettInnhold())
    tm.Add("Tastene og flatene (hjelp)", (*) => VisHjelp())
    tm.Add()
    tm.Add("Avslutt skriptet", (*) => AvsluttSkript())
    tm.Default := "Skrift-menyen`t" K.tastMenyTekst
}
