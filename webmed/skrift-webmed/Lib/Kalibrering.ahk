; =============================================================================
; Kalibrering.ahk  –  Skrift.md / Eirskrift AS
; Skjermpunktene til dagsliste.ahk (v0.5) måles hos brukeren i stedet for å stå
; fast i config.ini. Brukeren peker på fem ting i WebMed og trykker en tast;
; resten (kolonnen langs overskriftene, fargen, listens høyde, rullingen)
; regnes ut her. Funksjonene her er rene (profiler inn, tall eller tekst ut),
; så de kan testes uten WebMed (tester/test-v05.ahk). Lesing av skjermen og
; samtalen med brukeren står i dagsliste.ahk (Kalibrer).
;
; Profiler er lister med farger (0xRRGGBB) der indeks 1 er vinduskoordinat 0.
; s er skaleringen i forhold til 100 % (A_ScreenDPI / 96).
; =============================================================================

; Vinduet og skaleringen koordinatene i config.ini ble målt med før v0.5
; (Daniels skjerm, 3440 × 1440, 100 %, WebMed maksimert)
global KAL_REFERANSE := {vindu: "3456x1416", dpi: 96}

KalSkala(dpi) => dpi / 96

; v0.11.2 (SUP-2026-11-08-A): grunnen til at siste kalibrering stoppet, med
; klokkeslett ("07:40: Avbrutt: ingen tast på to minutter"). Tom når ingen har
; stoppet siden skriptet startet, eller når en senere kalibrering gikk bra.
; Legges til meldingen «ikke kalibrert», så den sier hvorfor.
global KAL_SISTE_STOPP := ""

KalStoppTillegg() {
    if KAL_SISTE_STOPP = ""
        return ""
    t := StrReplace(KAL_SISTE_STOPP, "`n", " ")
    return "`nSiste kalibrering stoppet kl. " (StrLen(t) > 220 ? SubStr(t, 1, 220) " …" : t)
}

; v0.11.2: en ekstra merketast som ikke trenger Fn på en bærbar PC (Ctrl+Shift+M),
; bare mens kalibreringen pågår. taster: alle tastene som er satt i config.ini.
; Svar: "^+m", eller "" når en av dem alt bruker den.
KalMerkAlt(taster) {
    for t in taster
        if StrLower(Trim(t)) = "^+m" || StrLower(Trim(t)) = "+^m"
            return ""
    return "^+m"
}

; Teksten om merketasten i hintet: «F8 eller Ctrl+Shift+M (bærbar PC: Fn+F8)»
KalMerkHint(merk, merkTekst, altTekst) {
    t := merkTekst (altTekst != "" ? " eller " altTekst : "")
    if RegExMatch(merk, "i)^\{?F\d{1,2}\}?$")
        t .= " (bærbar PC: Fn+" merkTekst ")"
    return t
}

; Rådet i boksen når kalibreringen stoppet, etter grunnen
KalStoppRaad(feil, merkTekst, altTekst) {
    if InStr(feil, "ingen tast")
        return "Skriptet fikk ikke merketasten. På en bærbar PC må du ofte holde Fn inne sammen med " merkTekst "." (altTekst != "" ? " Du kan også trykke " altTekst " i stedet." : "") " Pek på det hintet ber om (ikke klikk), og trykk tasten mens pekeren står der."
    if InStr(feil, "Avbrutt med Esc")
        return "Esc avbryter alltid kalibreringen, også når du trykker den for å lukke noe annet."
    if InStr(feil, "Fant ikke WebMed-vinduet")
        return "Åpne WebMed og logg inn, med en fiktiv testpasient framme i journalen, og prøv igjen."
    return "Åpne en fiktiv testpasient som har minst én oppføring i Løpende journal, pek midt på det hintet ber om, og prøv igjen."
}

; Skjermene som tekst til loggen. skjermer: [{l, t, r, b}, …], hoved og wm:
; nummeret til hovedskjermen og til skjermen WebMed står på (0 = ukjent).
SkjermTekst(skjermer, hoved, wm) {
    s := ""
    for i, m in skjermer
        s .= (s = "" ? "" : "; ") i ": " (m.r - m.l) "x" (m.b - m.t) " ved " m.l "," m.t (i = hoved ? " (hovedskjerm)" : "") (i = wm ? " (WebMed)" : "")
    return skjermer.Length " skjerm" (skjermer.Length = 1 ? "" : "er") ": " s
}

; DPI-en vinduet tegnes med (skjermen det står på, v0.5.1). A_ScreenDPI er
; hovedskjermens og stemmer ikke når WebMed står på en skjerm med annen
; skalering. A_ScreenDPI når Windows ikke svarer (eldre enn Windows 10 1607).
VinduDpi(hwnd) {
    d := 0
    try d := DllCall("GetDpiForWindow", "Ptr", hwnd, "UInt")
    return d ? d : A_ScreenDPI
}

; v0.8.0: et vindu som er skjult av Windows (DWM «cloaked», f.eks. en app som
; gjemmer seg mens den fjernstyrer maskinen) ligger fortsatt under pekeren for
; MouseGetPos, selv om det verken vises eller tar klikk. Kalibreringen skal
; ikke avvise et punkt i WebMed på grunn av et slikt vindu.
VinduSkjult(hwnd) {
    static DWMWA_CLOAKED := 14
    v := 0
    try DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "Int", DWMWA_CLOAKED, "Int*", &v, "Int", 4)
    return v != 0
}

; Nesten hvit: alle kanaler 240 eller mer (som JournalGrov)
KalNestenHvit(c) => (c >> 16) >= 240 && ((c >> 8) & 0xFF) >= 240 && (c & 0xFF) >= 240

; Lysstyrke 0 til 255
KalLys(c) => (((c >> 16) & 0xFF) * 3 + ((c >> 8) & 0xFF) * 6 + (c & 0xFF)) // 10

; Grå: kanalene ligger innenfor 16 av hverandre
KalGraa(c) {
    r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
    return Max(r, g, b) - Min(r, g, b) <= 16
}

; Den vanligste fargen i profil[fra..til] (bakgrunnen i en overskrift med tekst)
KalVanligste(profil, fra, til) {
    tall := Map(), beste := 0, n := 0
    fra := Max(1, fra), til := Min(profil.Length, til)
    i := fra
    while i <= til {
        c := profil[i]
        tall[c] := (tall.Has(c) ? tall[c] : 0) + 1
        if tall[c] > n
            n := tall[c], beste := c
        i++
    }
    return beste
}

; Kanten av et felt i fargen, fra start i retning (-1 eller 1). Tekst inne i
; feltet (høyst maksHull piksler på rad i en annen farge) hoppes over.
; v0.8.0: bare mørkere piksler regnes som tekst. En tydelig lysere piksel (hvit
; polstring, bakgrunnen mellom feltene) er kanten, uansett hvor smal den er:
; med 40 px hull (v0.7.1) hoppet kanten ellers over polstringen og videre
; inn i den grå bakgrunnen mellom Dagens og Løpende journal (sett ved 125 %).
; v0.9.0: «tydelig» = minst 8 lysere enn overskriften. ClearType-kantene rundt
; teksten (E3E3AE, E3E2C3 …) er nesten like lyse som bakgrunnen og er tekst
; (sett ved 100 % 31.10: kanten ble funnet midt i teksten).
; Svar: indeksen til den siste pikselen i fargen.
KalKant(profil, start, retning, farge, maksHull) {
    sist := start, hull := 0, i := start, lys := KalLys(farge)
    loop {
        i += retning
        if i < 1 || i > profil.Length
            break
        if JournalLikFarge(profil[i], farge)
            sist := i, hull := 0
        else {
            if KalLys(profil[i]) > lys + 8
                break
            hull++
            if hull > maksHull
                break
        }
    }
    return sist
}

; Overskriften brukeren pekte på, fra raden (vannrett profil gjennom punktet).
; px: pekerens x i vinduet. Svar: {farge, venstre, hoyre} (vindus-x) eller en
; feilmelding (streng).
KalOverskriftRad(rad, px, s) {
    i := px + 1
    if i < 1 || i > rad.Length
        return "Pekeren sto utenfor WebMed-vinduet."
    farge := KalVanligste(rad, i - Round(40 * s), i + Round(40 * s))
    if KalNestenHvit(farge) || !KalGraa(farge) || KalLys(farge) < 150
        return "Punktet ser ikke ut som en grå overskrift i Løpende journal (farge #" Format("{:06X}", farge) "). Pek midt på den grå overskriften."
    ; Nærmeste piksel i fargen (pekeren kan stå på teksten)
    start := 0
    loop Round(30 * s) + 1 {
        d := A_Index - 1
        for j in [i - d, i + d]
            if !start && j >= 1 && j <= rad.Length && JournalLikFarge(rad[j], farge)
                start := j
        if start
            break
    }
    if !start
        return "Fant ikke overskriftens farge ved pekeren."
    ; v0.7.1 (30.10): 40 px, ikke 14. Fet tekst i overskriften («Ingen pasientkontakt»)
    ; hadde 17 px på rad uten overskriftsfargen, og kanten ble funnet midt i teksten.
    hull := Round(40 * s)
    v := KalKant(rad, start, -1, farge, hull), h := KalKant(rad, start, 1, farge, hull)
    if h - v + 1 < Round(200 * s)
        return "Overskriften er bare " (h - v + 1) " px bred. Pek midt på den grå overskriften i Løpende journal."
    return {farge: farge, venstre: v - 1, hoyre: h - 1}
}

; Kontrollerer en loddrett profil (hele vinduets høyde) i en kandidat til
; skannekolonnen. py: y i overskriften brukeren pekte på; y0 og y1: listen.
; Gyldig når overskriften i punktet finnes og er 20 til 120 px høy ved 100 %,
; og minst 85 % av pikslene i listen som ikke er overskrift, er nesten hvite.
; Svar: {t, b, hoder} (vindus-y) eller en feilmelding (streng).
KalSjekkKolonne(kol, py, y0, y1, farge, s) {
    del := []
    y := y0
    while y < y1 && y < kol.Length {
        del.Push(kol[y + 1])
        y++
    }
    hoder := JournalOverskrifter(del, y0, farge)
    treff := 0
    for h in hoder
        if py >= h.t && py <= h.b
            treff := h
    if !treff
        return "fant ikke overskriften i kolonnen"
    hoyde := treff.b - treff.t + 1
    if hoyde < 20 * s || hoyde > 120 * s
        return "overskriften er " hoyde " px høy"
    hvit := 0, andre := 0
    for c in del
        if !JournalLikFarge(c, farge)
            andre++, hvit += KalNestenHvit(c)
    if andre && hvit < andre * 0.85
        return "for mye annet enn hvitt mellom overskriftene (" Round(hvit * 100 / andre) " % hvitt)"
    return {t: treff.t, b: treff.b, hoder: hoder}
}

; Skannekolonnen: første x fra venstre kant av overskriften (3 til 20 px inn
; ved 100 %) der KalSjekkKolonne godtar profilen. kolonne(x) gir profilen.
; Svar: {x, t, b, hoder} eller en feilmelding (streng).
KalVelgSkann(kolonne, venstre, hoyre, py, y0, y1, farge, s) {
    svar := ""
    d := Round(3 * s), maks := Round(20 * s)
    while d <= maks && venstre + d < hoyre {
        r := KalSjekkKolonne(kolonne(venstre + d), py, y0, y1, farge, s)
        if IsObject(r) {
            r.x := venstre + d
            return r
        }
        ; v0.8.0: alle kandidatene i meldingen (loggen), ikke bare den siste
        svar .= (svar != "" ? "; " : "") d ": " r
        d += Max(1, Round(s))
    }
    return "Fant ingen kolonne langs venstre kant av overskriftene der bare overskriftene er grå (overskrift " venstre ".." hoyre ", farge #" Format("{:06X}", farge) ", liste " y0 ".." y1 ", peker-y " py "; " svar ")."
}

; Regner ut punktene fra det brukeren pekte på. p: {avtaler, notat, kontakt,
; hode, bunn} (vindus-x/y), rad: {farge, venstre, hoyre}, vh: vinduets høyde.
; Svar: {y0, y1, klikkX, rull} eller en feilmelding (streng).
KalBeregn(p, rad, vh, s) {
    y0 := p.kontakt.y + Round(10 * s)
    y1 := p.bunn.y
    if p.hode.y <= y0
        return "Overskriften må stå under boksen «Kontakt». Pek på boksen «Kontakt» og så på den øverste overskriften i listen."
    if y1 > vh || y1 <= p.hode.y
        return "Punktet nederst i Løpende journal må stå under overskriften og inne i WebMed-vinduet."
    if y1 - y0 < Round(250 * s)
        return "Løpende journal er for lav (" (y1 - y0) " px). Maksimer WebMed og prøv igjen."
    ; Klikket: der brukeren pekte, men ikke ytterst (menyen ⋮ står til høyre)
    klikkX := Min(Max(p.hode.x, rad.venstre + Round(30 * s)), rad.hoyre - Round(80 * s))
    if klikkX <= rad.venstre
        return "Overskriften er for smal til et sikkert klikk."
    return {y0: y0, y1: y1, klikkX: klikkX, rull: KalRullHakk(y1 - y0, s)}
}

; Hjulhakk per side: WebMed ruller 48 px per hakk ved 100 %. Omtrent en halv
; side, så noe fra forrige side alltid er synlig igjen (2 til 15).
KalRullHakk(hoyde, s) => Min(15, Max(2, Floor(0.5 * hoyde / (48 * s))))

; Er vinduet og skaleringen som da punktene ble målt? lagret: {vindu, dpi}
; fra [kalibrering] ("" når skriptet ikke er kalibrert), naa: {vindu, dpi}.
; Uten kalibrering godtas bare oppsettet koordinatene før v0.5 ble målt på.
; Svar: "" når alt stemmer, ellers meldingen til brukeren.
KalSjekk(lagret, naa, tast) {
    if lagret.vindu = "" {
        if naa.vindu = KAL_REFERANSE.vindu && naa.dpi = KAL_REFERANSE.dpi
            return ""
        return "Skriptet er ikke kalibrert for denne skjermen (WebMed " naa.vindu ", " Round(naa.dpi / 96 * 100) " %). Åpne en fiktiv testpasient i WebMed og trykk " tast " for å kalibrere." KalStoppTillegg()
    }
    ; v0.10.3 (rapportfunn 2): endres Windows-skaleringen uten at WebMed startes på
    ; nytt, melder vinduet fortsatt den gamle DPI-en; bare størrelsen avslører det
    ; (3456x1416 ble 2768x1128 ved 125 %). Da er «100 %» i meldingen misvisende.
    if lagret.dpi = naa.dpi && lagret.vindu != naa.vindu && (f := KalSkaleringsFaktor(lagret.vindu, naa.vindu))
        return "Windows-skaleringen ser ut til å være endret siden kalibreringen (WebMed er " naa.vindu ", var " lagret.vindu "). Start WebMed på nytt og trykk " tast " for å kalibrere på nytt, eller sett skaleringen tilbake."
    if lagret.vindu != naa.vindu || lagret.dpi != naa.dpi
        return "WebMed har en annen størrelse eller skalering enn ved kalibreringen, også maksimert (da " lagret.vindu ", " Round(lagret.dpi / 96 * 100) " %, nå " naa.vindu ", " Round(naa.dpi / 96 * 100) " %). Flytt WebMed til skjermen du kalibrerte på, eller trykk " tast " for å kalibrere på nytt."
    return ""
}

; v0.10.3: ser vindusstørrelsene ("BxH") ut som samme skjerm med en annen
; Windows-skalering? Bredden og høyden må begge ha samme forhold, og forholdet
; må være et av Windows' trinn (100, 125, 150, 175, 200 % hver vei). Svar:
; forholdet (f.eks. 1.25) eller 0.
KalSkaleringsFaktor(a, b) {
    pa := StrSplit(a, "x"), pb := StrSplit(b, "x")
    if pa.Length != 2 || pb.Length != 2 || !IsNumber(pa[1]) || !IsNumber(pa[2]) || !IsNumber(pb[1]) || !IsNumber(pb[2]) || pb[1] <= 0 || pb[2] <= 0
        return 0
    fb := pa[1] / pb[1], fh := pa[2] / pb[2]
    if Abs(fb - fh) > 0.03
        return 0
    for t in [1.25, 1.5, 1.75, 2, 2.5, 1 / 1.25, 1 / 1.5, 1 / 1.75, 1 / 2, 1 / 2.5]
        if Abs(fb - t) <= 0.03
            return Round(t, 2)
    return 0
}

; Varselfeltet nederst til høyre er ca. 574 px bredt ved 100 %
KalVarselBredde(bw, s) => bw >= 400 * s && bw <= 800 * s

; Setter nokkel=verdi i [seksjon] i teksten til en ini-fil, uten å røre resten
; (kommentarer, rekkefølge, linjeskift). Mangler nøkkelen, legges den sist i
; seksjonen; mangler seksjonen, legges den sist i filen med kommentar (kan
; være ""). Store og små bokstaver i navnene spiller ingen rolle.
IniSettTekst(tekst, seksjon, nokkel, verdi, kommentar := "") {
    crlf := InStr(tekst, "`r`n") || tekst = ""
    linjer := StrSplit(StrReplace(tekst, "`r`n", "`n"), "`n")
    slutt := ""
    if linjer.Length && linjer[linjer.Length] = ""
        linjer.Pop(), slutt := "`n"
    inne := false, start := 0, sist := 0, funnet := false
    for i, l in linjer {
        t := Trim(l)
        if SubStr(t, 1, 1) = "[" {
            if inne
                break
            if StrLower(t) = "[" StrLower(seksjon) "]"
                inne := true, start := i, sist := i
            continue
        }
        if !inne
            continue
        if t != ""
            sist := i
        if RegExMatch(l, "i)^\s*\Q" nokkel "\E\s*=") {
            linjer[i] := nokkel "=" verdi
            funnet := true
            break
        }
    }
    if !funnet {
        if start
            linjer.InsertAt(sist + 1, nokkel "=" verdi)
        else {
            if linjer.Length && Trim(linjer[linjer.Length]) != ""
                linjer.Push("")
            linjer.Push("[" seksjon "]")
            if kommentar != ""
                for k in StrSplit(kommentar, "`n")
                    linjer.Push("; " k)
            linjer.Push(nokkel "=" verdi)
            if slutt = ""
                slutt := "`n"
        }
    }
    ut := ""
    for i, l in linjer
        ut .= (i = 1 ? "" : "`n") l
    ut .= slutt
    return crlf ? StrReplace(ut, "`n", "`r`n") : ut
}

; Skriver verdiene ({seksjon: [[nokkel, verdi], …]}) til ini-filen i én
; operasjon, med samme tegnkoding (UTF-8 med eller uten BOM) som før, via en
; midlertidig fil. kommentarer: {seksjon: tekst} for seksjoner som må lages.
IniSettFlere(fil, verdier, kommentarer := "") {
    f := FileOpen(fil, "r", "UTF-8")
    bom := f.Pos = 3
    tekst := f.Read()
    f.Close()
    for seksjon, par in verdier.OwnProps() {
        kom := IsObject(kommentarer) && kommentarer.HasOwnProp(seksjon) ? kommentarer.%seksjon% : ""
        for nv in par
            tekst := IniSettTekst(tekst, seksjon, nv[1], nv[2], kom)
    }
    tmp := fil ".ny"
    f := FileOpen(tmp, "w", bom ? "UTF-8" : "UTF-8-RAW")
    f.Write(tekst)
    f.Close()
    FileMove tmp, fil, 1
}
