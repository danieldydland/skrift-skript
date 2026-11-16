; =============================================================================
; Journal.ahk  –  Skrift.md / Eirskrift AS
; Siste konsultasjon fra Løpende journal i WebMed (dagsliste.ahk v0.4).
;
; WebMed viser ikke journalen (WPF) i tilgjengelighetslaget: UIA og MSAA ser bare
; hovedvinduet (kartlagt 18.10 og 24.10.2026). Derfor:
;   1. Overskriftene i Løpende journal finnes på fargen: grå felt (#E3E3E3,
;      46 px høye ved 100 % skalering) langs en loddrett linje i venstre marg.
;   2. Et klikk på en overskrift kopierer hele oppføringen, med PatientText.
;      Første linje er «DD.MM.ÅÅÅÅ TT.MM Type  Forfatter ».
;   3. Typen avgjør. Pasient-GUID-en i hver kopi må være lik feltene ellers.
;   4. Finnes ingen konsultasjon på skjermen, rulles listen ned. Forskyvningen
;      måles på fargelinjen, så overskrifter som er sjekket ikke klikkes igjen.
; Klikk på en overskrift endrer ikke journalen (bare markering og kopi).
; =============================================================================

; Fargene langs en loddrett linje på skjermen (x, y0 til y1-1), én per piksel
JournalProfil(x, y0, y1) {
    h := y1 - y0
    if h <= 0
        return []
    hdcS := DllCall("GetDC", "ptr", 0, "ptr")
    hdc := DllCall("CreateCompatibleDC", "ptr", hdcS, "ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0), NumPut("Int", 1, bi, 4), NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
    bits := 0
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &bits, "ptr", 0, "uint", 0, "ptr")
    o := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", 1, "int", h, "ptr", hdcS, "int", x, "int", y0, "uint", 0x00CC0020)
    arr := []
    arr.Capacity := h
    loop h
        arr.Push(NumGet(bits, (A_Index - 1) * 4, "UInt") & 0xFFFFFF)
    DllCall("SelectObject", "ptr", hdc, "ptr", o)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcS)
    return arr
}

; Profilen når listen står stille (rullingen i WebMed er animert): samme
; overskrifter i to målinger med 120 ms mellomrom, høyst maksMs. Overskriftene
; sammenlignes, ikke pikslene, så små fargeendringer andre steder ikke teller.
JournalStabil(x, y0, y1, farge := 0xE3E3E3, maksMs := 2000) {
    a := JournalProfil(x, y0, y1)
    ka := JournalHoderNokkel(a, y0, farge)
    slutt := A_TickCount + maksMs
    loop {
        Sleep 120
        b := JournalProfil(x, y0, y1)
        kb := JournalHoderNokkel(b, y0, farge)
        if kb == ka || A_TickCount > slutt
            return b
        a := b, ka := kb
    }
}

; v0.8.0: WebMed tømmer og laster Løpende journal på nytt når filteret
; endres; et øyeblikk er listen hvit. Venter til minst én overskrift er
; synlig igjen (høyst maksMs). Svar: true når en overskrift finnes.
; v0.10.3 (rapportfunn 3): en liste som er tom med filteret, er hvit og blir
; det; da ventes det ikke 8 s. Hvit regnes som ferdig når den har stått i
; 600 ms (listen er hvit også et øyeblikk mens den tegnes på nytt).
JournalVentPaaOverskrifter(x, y0, y1, farge, maksMs := 8000) {
    slutt := A_TickCount + maksMs
    hvitSiden := 0
    loop {
        prof := JournalProfil(x, y0, y1)
        s := JournalKlarEllerTom(prof, y0, farge)
        if s = "hoder"
            return true
        if s = "tom" {
            hvitSiden := hvitSiden ? hvitSiden : A_TickCount
            if A_TickCount - hvitSiden >= 600
                return true
        } else
            hvitSiden := 0
        if A_TickCount > slutt
            return false
        Sleep 150
    }
}

; v0.10.3: "hoder" når profilen har overskrifter, "tom" når den er hvit, ellers "".
JournalKlarEllerTom(profil, y0, farge) {
    if JournalOverskrifter(profil, y0, farge).Length
        return "hoder"
    return JournalHvit(profil) ? "tom" : ""
}

JournalHoderNokkel(profil, y0, farge) {
    s := ""
    for h in JournalOverskrifter(profil, y0, farge)
        s .= h.t "-" h.b ","
    return s
}

; Andelen piksler i fargen i en profil (0 til 1)
JournalAndel(profil, farge) {
    n := 0
    for c in profil
        n += JournalLikFarge(c, farge)
    return profil.Length ? n / profil.Length : 0
}

; Står det en overskrift der klikket skal gå (v0.5.1)? Et bånd øverst eller
; nederst i overskriften (o.inn px inn, over og under teksten) skal være minst
; 90 % i overskriftsfargen fra o.halv px til venstre til o.halv px til høyre
; for klikkpunktet. Er panelene i WebMed flyttet siden kalibreringen, kan
; fargelinjen treffe noe annet grått; da klikkes det ikke. Uten o.halv: ja.
JournalErHode(o, h) {
    if !o.HasOwnProp("halv")
        return true
    for y in [h.t + o.inn, h.b - o.inn]
        if JournalAndel(JournalRute(o.klikkX - o.halv, y, 2 * o.halv + 1, 1), o.farge) >= 0.9
            return true
    return false
}

; Minst 90 % hvite piksler: listen er tom
JournalHvit(profil) {
    hvit := 0
    for c in profil
        if c = 0xFFFFFF
            hvit++
    return profil.Length && hvit >= profil.Length * 0.9
}

; Lik farge innenfor toleranse per kanal
JournalLikFarge(a, b, tol := 4) => Abs((a >> 16) - (b >> 16)) <= tol && Abs(((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)) <= tol && Abs((a & 0xFF) - (b & 0xFF)) <= tol

; Overskriftene: sammenhengende felt i overskriftsfargen, minst minH px høye.
; Svar: liste med {t, b} i skjermkoordinater (øverste og nederste piksel).
JournalOverskrifter(profil, y0, farge := 0xE3E3E3, minH := 12) {
    ut := [], start := 0
    loop profil.Length + 1 {
        i := A_Index
        treff := i <= profil.Length && JournalLikFarge(profil[i], farge)
        if treff && !start
            start := i
        else if !treff && start {
            if i - start >= minH
                ut.Push({t: y0 + start - 1, b: y0 + i - 2})
            start := 0
        }
    }
    return ut
}

; Hvor langt innholdet flyttet seg opp mellom to profiler (rulling ned).
; Fargene grovsorteres (5 bit per kanal), så små avvik (kantutjevning, en
; halvgjennomsiktig flate over skjermen) ikke teller, og nesten hvite piksler
; hoppes over. Svar: {d, score}; score 0 til 1. Minst minOverlapp px må
; overlappe; beste treff med minst forskyvning vinner.
JournalForskyvning(fra, til, minOverlapp := 200) {
    n := Min(fra.Length, til.Length)
    qa := [], qb := []
    qa.Capacity := n, qb.Capacity := n
    loop n {
        qa.Push(JournalGrov(fra[A_Index]))
        qb.Push(JournalGrov(til[A_Index]))
    }
    best := 0, bestScore := 0
    d := 0
    while d <= n - minOverlapp {
        m := 0, tot := 0, i := 1
        while i + d <= n {
            c := qb[i]
            if c >= 0 {
                tot++
                if c = qa[i + d]
                    m++
            }
            i += 2
        }
        if tot >= 15 {
            s := m / tot
            if s > bestScore
                bestScore := s, best := d
            if s = 1 && tot >= 60
                break
        }
        d++
    }
    return {d: best, score: bestScore}
}

; 5 bit per kanal; -1 for nesten hvitt (alle kanaler 240 eller mer)
JournalGrov(c) {
    r := c >> 16, g := (c >> 8) & 0xFF, b := c & 0xFF
    if r >= 240 && g >= 240 && b >= 240
        return -1
    return ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
}

; Første linje med tekst: «DD.MM.ÅÅÅÅ TT.MM Type  Forfatter ». Svar: objekt eller "".
JournalOverskrift(tekst) {
    l := ""
    for linje in StrSplit(StrReplace(StrReplace(tekst, "`r`n", "`n"), "`r", "`n"), "`n")
        if Trim(linje) != "" {
            l := linje
            break
        }
    if !RegExMatch(l, "^\s*(\d{2})\.(\d{2})\.(\d{4}) (\d{2})[.:](\d{2}) +(.+?)(?:  +(.*?))?\s*$", &m)
        return ""
    if !IsTime(m[3] m[2] m[1] m[4] m[5])
        return ""
    return {dato: m[3] "-" m[2] "-" m[1], visDato: m[1] "." m[2] "." m[3], tid: m[4] ":" m[5]
        , type: Trim(m[6]), forfatter: Trim(m[7]), linje: l}
}

; Teksten etter overskriftslinjen, med LF og uten tomme linjer først og sist.
; Kopien gjentar forfatterens navn på linjen etter overskriften («Etternavn
; Fornavn »). Linjer som bare er navnet fjernes, og navnet ellers i teksten
; byttes med «[lege]» (SkjulNavn: begge rekkefølger, med komma, store
; bokstaver og hver del av navnet), så legens navn ikke følger med.
; antall: hvor mange ganger navnet ble byttet ut (til loggen).
JournalKropp(tekst, forfatter := "", &antall := 0) {
    s := StrReplace(StrReplace(tekst, "`r`n", "`n"), "`r", "`n")
    s := LTrim(s, " `t`n")
    p := InStr(s, "`n")
    s := p ? SubStr(s, p + 1) : ""
    navn := Trim(forfatter)
    ut := "", antall := 0
    for l in StrSplit(s, "`n") {
        if navn != "" {
            r := SkjulNavn(l, navn, "[lege]")
            ; Linjer med bare navnet (og tegnsetting) fjernes
            if r.antall && RegExMatch(r.tekst, "^[\s,.]*(\[lege\][\s,.]*)+$")
                continue
            antall += r.antall
            l := r.tekst
        }
        ut .= RTrim(l, " `t") "`n"
    }
    return Trim(ut, " `t`n")
}

; Bytter et navn i teksten med erstatning. Først hele navnet uten hensyn til
; store og små bokstaver: delene i rekkefølgen de står, med første del flyttet
; sist («Krank, Kalle» og «Kalle Krank»), og baklengs; komma og flere mellomrom
; mellom delene er lov. Så hver del på minst 3 bokstaver som eget ord, skrevet
; som i navnet, med stor forbokstav eller med bare store bokstaver. Et vanlig
; ord som er likt en del av navnet og står med stor forbokstav, byttes også;
; legen ser teksten før den brukes. Svar: {tekst, antall}.
SkjulNavn(tekst, navn, erstatning) {
    r := {tekst: tekst, antall: 0}
    deler := []
    for d in StrSplit(RegExReplace(Trim(navn), "[\s,]+", " "), " ")
        if d != ""
            deler.Push(d)
    if !deler.Length || tekst = ""
        return r
    fore := "(?<![\p{L}\p{N}])", etter := "(?![\p{L}\p{N}])"
    erst := StrReplace(erstatning, "$", "$$")
    ; Hele navnet bare når det har minst to deler (én del: som delene under)
    rekker := []
    if deler.Length > 1 {
        rekker.Push(deler)
        rot := [], bak := []
        loop deler.Length - 1
            rot.Push(deler[A_Index + 1])
        rot.Push(deler[1])
        loop deler.Length
            bak.Push(deler[deler.Length - A_Index + 1])
        rekker.Push(rot, bak)
    }
    for rekke in rekker {
        m := ""
        for d in rekke
            m .= (m = "" ? "" : "[ \t]*,?[ \t]+") "\Q" d "\E"
        r.tekst := RegExReplace(r.tekst, "i)" fore m etter, erst, &n), r.antall += n
    }
    for d in deler {
        if StrLen(d) < 3
            continue
        for form in [d, StrTitle(d), StrUpper(d)] {
            r.tekst := RegExReplace(r.tekst, fore "\Q" form "\E" etter, erst, &n)
            r.antall += n
        }
    }
    return r
}

; Piksler i et rektangel på skjermen, rad for rad (0xRRGGBB). Én BitBlt;
; GetPixel per piksel tar 10–20 ms med skrivebordskomposisjon (målt 25.10).
JournalRute(x, y, w, h) {
    hdcS := DllCall("GetDC", "ptr", 0, "ptr")
    hdc := DllCall("CreateCompatibleDC", "ptr", hdcS, "ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0), NumPut("Int", w, bi, 4), NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
    bits := 0
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &bits, "ptr", 0, "uint", 0, "ptr")
    o := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdcS, "int", x, "int", y, "uint", 0x00CC0020)
    arr := []
    arr.Capacity := w * h
    loop w * h
        arr.Push(NumGet(bits, (A_Index - 1) * 4, "UInt") & 0xFFFFFF)
    DllCall("SelectObject", "ptr", hdc, "ptr", o)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcS)
    return arr
}

; Avkrysningsboksen (16x16, sentrum cx,cy på skjermen) er krysset av når det
; er mørke piksler inne i boksen (haken). Tom boks er hvit innvendig.
; v0.9.0: boksens ramme finnes først (JournalBoksFinn), og bare det innenfor
; rammen telles. Før ble rammen telt som «hake» når punktet sto 3–4 px fra
; midten (100 %, 31.10: 12 mørke piksler i en tom boks).
JournalBoksAvkrysset(cx, cy) {
    b := JournalBoksFinn(cx, cy)
    if b
        return JournalMorke(b.x0 + 3, b.y0 + 3, b.x1 - b.x0 - 5, b.y1 - b.y0 - 5) >= 4
    return JournalBoksMorke(cx, cy) >= 5
}

; Mørke piksler i boksen (til loggen når boksen ikke reagerer, v0.9.0)
JournalBoksMorke(cx, cy) => JournalMorke(cx - 5, cy - 5, 11, 11)

JournalMorkPiksel(c) => (((c >> 16) & 0xFF) * 3 + ((c >> 8) & 0xFF) * 6 + (c & 0xFF)) // 10 < 180

JournalMorke(x, y, w, h) {
    n := 0
    if w < 1 || h < 1
        return 0
    for c in JournalRute(x, y, w, h)
        n += JournalMorkPiksel(c)
    return n
}

; Rammen rundt avkrysningsboksen nær (cx, cy): en firkant på 10–32 px med mørke
; kanter. Svar: {x0, y0, x1, y1, x, y} (skjermpiksler, x/y er midten) eller 0.
JournalBoksFinn(cx, cy) {
    n := 33, h := n // 2
    r := JournalRute(cx - h, cy - h, n, n)
    kol := [], rad := []
    loop n
        kol.Push(0), rad.Push(0)
    loop n {
        y := A_Index
        loop n {
            x := A_Index
            if JournalMorkPiksel(r[(y - 1) * n + x])
                kol[x]++, rad[y]++
        }
    }
    x0 := 0, x1 := 0, y0 := 0, y1 := 0
    loop n {
        if kol[A_Index] >= 10 {
            if !x0
                x0 := A_Index
            x1 := A_Index
        }
        if rad[A_Index] >= 10 {
            if !y0
                y0 := A_Index
            y1 := A_Index
        }
    }
    if !x0 || !y0
        return 0
    w := x1 - x0 + 1, hh := y1 - y0 + 1
    if w < 10 || w > 32 || hh < 10 || hh > 32 || Abs(w - hh) > 3
        return 0
    return {x0: cx - h + x0 - 1, y0: cy - h + y0 - 1, x1: cx - h + x1 - 1, y1: cy - h + y1 - 1
        , x: cx - h + (x0 + x1) // 2 - 1, y: cy - h + (y0 + y1) // 2 - 1}
}

; Setter filteret «Kontakt» i Løpende journal. Svar: true når boksen står som
; ønsket etterpå. Klikker bare når den ikke allerede gjør det.
JournalSettFilter(cx, cy, paa) {
    if JournalBoksAvkrysset(cx, cy) = paa
        return true
    CoordMode "Mouse", "Screen"
    MouseClick "Left", cx, cy
    slutt := A_TickCount + 2000
    while A_TickCount < slutt {
        Sleep 100
        if JournalBoksAvkrysset(cx, cy) = paa
            return true
    }
    return false
}

; Ruller Løpende journal helt til toppen (nyeste først). Svar: true når to
; målinger etter rulling opp er like.
JournalTilToppen(o) {
    CoordMode "Mouse", "Screen"
    loop 8 {
        MouseMove o.musBort.x, o.musBort.y, 0
        a := JournalHoderNokkel(JournalStabil(o.skannX, o.y0, o.y1, o.farge), o.y0, o.farge)
        MouseMove o.klikkX, (o.y0 + o.y1) // 2, 0
        loop 30 {
            MouseClick "WheelUp"
            Sleep 5
        }
        MouseMove o.musBort.x, o.musBort.y, 0
        b := JournalHoderNokkel(JournalStabil(o.skannX, o.y0, o.y1, o.farge), o.y0, o.farge)
        if a == b
            return true
    }
    return false
}

; Typen passer når den er lik et navn i typer (små bokstaver), eller er navnet
; fulgt av en presisering i parentes («Konsultasjon (…)»)
JournalErType(type, typer) {
    t := StrLower(Trim(type))
    for navn in typer
        if t == navn || SubStr(t, 1, StrLen(navn) + 2) == navn " ("
            return true
    return false
}

; o.logg og o.sjekk er funksjoner (ikke metoder): kalles uten o som første argument
JournalLogg(o, msg) {
    if o.HasOwnProp("logg")
        (f := o.logg, f(msg))
}

; Klikker på en overskrift og leser kopien. Svar som KopierPasientTekst:
; {tekst, endret, pt}. Utklippstavlen settes til sentinel først.
JournalKopier(x, y, o) {
    kp := {tekst: "", endret: false, pt: {funnet: false, id: "", tekst: "", feil: ""}}
    A_Clipboard := o.sentinel
    Sleep 30
    CoordMode "Mouse", "Screen"
    MouseClick "Left", x, y
    slutt := A_TickCount + o.timeout
    while A_TickCount < slutt {
        if A_Clipboard != o.sentinel {
            kp.endret := true
            kp.tekst := A_Clipboard
            break
        }
        Sleep 30
    }
    if kp.endret && Trim(kp.tekst, " `t`r`n") != "" {
        try
            kp.pt := LesPatientText(kp.tekst)
        catch as e
            kp.pt := {funnet: true, id: "", tekst: "", feil: "intern feil ved lesing (" e.Message ")"}
        if kp.pt.id != ""
            kp.tekst := kp.pt.tekst
    }
    return kp
}

; Finner den nyeste oppføringen med en av typene i o.typer (liste, små bokstaver).
; o: {skannX, klikkX, y0, y1, farge, typer, maks, maksSider, rull, ventRull,
;     timeout, sentinel, guid, musBort: {x, y}, logg: fn, sjekk: fn,
;     halv, inn (v0.5.1, JournalErHode)}
; Svar: {funnet, kp, hode, kropp, legeNavn (antall ganger legens navn er
; byttet ut), sjekket, uten (klikk uten kopi), sider, stopp, sett: [{dato, type}]}.
; Kaster bare når en kopi har en annen pasient-GUID enn o.guid.
FinnSisteKonsultasjon(o) {
    r := {funnet: false, kp: 0, hode: "", kropp: "", legeNavn: 0, sjekket: 0, uten: 0, sider: 0, stopp: "", tom: false, sett: []}
    CoordMode "Mouse", "Screen"
    sett := Map()
    forrige := 0, forrigeHoder := []
    ingenKopi := 0
    loop o.maksSider {
        side := A_Index
        r.sider := side
        overlapp := false
        if o.HasOwnProp("sjekk")
            (f := o.sjekk, f())
        MouseMove o.musBort.x, o.musBort.y, 0
        prof := JournalStabil(o.skannX, o.y0, o.y1, o.farge)
        hoder := JournalOverskrifter(prof, o.y0, o.farge)
        sjekketY := []
        if IsObject(forrige) {
            fs := JournalForskyvning(forrige, prof)
            JournalLogg(o, "Løpende journal: side " side ", rullet " fs.d " px (samsvar " Round(fs.score * 100) " %), " hoder.Length " overskrift(er)")
            if fs.d = 0 && fs.score >= 0.98 {
                r.stopp := "slutten av Løpende journal"
                return r
            }
            ; Uten overskrifter på forrige side (én lang oppføring) er det ingenting å
            ; kjenne igjen; rullingen er kortere enn skjermsiden
            if !forrigeHoder.Length
                overlapp := true
            if fs.score >= 0.95 && fs.d < o.y1 - o.y0 - 100 {
                overlapp := true
                for h in forrigeHoder
                    sjekketY.Push(h.t - fs.d)
            }
        } else
            JournalLogg(o, "Løpende journal: " hoder.Length " overskrift(er) på skjermen")
        if !hoder.Length && !IsObject(forrige) {
            ; Listen kan tegnes på nytt et øyeblikk etter at filteret er satt: vent
            ; inntil 3 s (v0.10.3, før 1,5 s) på overskrifter eller en hvit (tom) liste
            tom := JournalHvit(prof)
            loop 12 {
                if tom
                    break
                Sleep 250
                prof := JournalProfil(o.skannX, o.y0, o.y1)
                hoder := JournalOverskrifter(prof, o.y0, o.farge)
                if hoder.Length
                    break
                tom := JournalHvit(prof)
            }
            if !hoder.Length {
                ; Hvit linje: listen er tom (eller filteret viser ingenting). Ellers er
                ; noe annet på plassen, og koordinatene stemmer trolig ikke.
                ; v0.10.3 (rapportfunn 3): var listen lesbar før filteret (o.lesbar),
                ; stemmer koordinatene, og listen regnes som tom uten koordinatråd.
                r.tom := tom || (o.HasOwnProp("lesbar") && o.lesbar)
                r.stopp := r.tom ? "slutten av Løpende journal"
                    : "fant ingen overskrifter i Løpende journal (sjekk journal_skann_x og journal_y)"
                return r
            }
        }
        for h in hoder {
            hopp := false
            for y in sjekketY
                if Abs(y - h.t) <= 4 && h.t > o.y0
                    hopp := true
            if hopp
                continue
            if r.sjekket >= o.maks {
                r.stopp := "ikke blant de " o.maks " nyeste oppføringene"
                return r
            }
            if !JournalErHode(o, h) {
                r.stopp := "det skriptet skulle klikke på i Løpende journal, ser ikke ut som en overskrift (er panelene i WebMed flyttet? kalibrer på nytt)"
                return r
            }
            kp := JournalKopier(o.klikkX, (h.t + h.b) // 2, o)
            if !kp.endret {
                ; Ett nytt forsøk når listen står stille: overskriften nærmest samme sted
                MouseMove o.musBort.x, o.musBort.y, 0
                p2 := JournalStabil(o.skannX, o.y0, o.y1, o.farge)
                naer := 0
                for h2 in JournalOverskrifter(p2, o.y0, o.farge)
                    if Abs(h2.t - h.t) <= 60 && (!naer || Abs(h2.t - h.t) < Abs(naer.t - h.t))
                        naer := h2
                if naer && JournalErHode(o, naer)
                    kp := JournalKopier(o.klikkX, (naer.t + naer.b) // 2, o)
            }
            r.sjekket++
            if !kp.endret || Trim(kp.tekst, " `t`r`n") = "" {
                ; Noen oppføringer (dokumenter) kopieres ikke ved klikk: hopp over
                ; én, men to på rad stopper søket
                ingenKopi++
                r.uten++
                if ingenKopi >= 2 {
                    r.stopp := "to overskrifter på rad ga ingen kopi"
                    return r
                }
                continue
            }
            ingenKopi := 0
            if !kp.pt.funnet || kp.pt.feil != "" || kp.pt.id = "" {
                r.stopp := "kopien fra Løpende journal hadde ikke gyldig PatientText"
                return r
            }
            if o.guid = ""
                o.guid := kp.pt.id
            else if kp.pt.id != o.guid
                throw Error("Løpende journal: oppføringen har en annen pasient-GUID enn feltene. Dataene for timen er forkastet.")
            hd := JournalOverskrift(kp.tekst)
            if !IsObject(hd) {
                r.stopp := "kopien begynte ikke med dato, klokkeslett og type"
                return r
            }
            if sett.Has(hd.linje) {
                overlapp := true
                continue
            }
            ; Første nye oppføring på en ny side: noe fra forrige side må være sett
            ; igjen (eller forskyvningen sikker), ellers kan rullingen ha hoppet over
            if side > 1 && !overlapp {
                r.stopp := "rullingen kan ha hoppet over oppføringer"
                return r
            }
            overlapp := true
            sett[hd.linje] := true
            r.sett.Push({dato: hd.dato, type: hd.type})
            if JournalErType(hd.type, o.typer) {
                nb := 0
                r.funnet := true, r.kp := kp, r.hode := hd, r.kropp := JournalKropp(kp.tekst, hd.forfatter, &nb), r.legeNavn := nb
                return r
            }
        }
        forrige := prof, forrigeHoder := hoder
        ; Ett hjulhakk per hendelse: WebMed ruller like langt (48 px ved 100 %)
        ; uansett hvor mange hakk én hendelse har
        MouseMove o.klikkX, (o.y0 + o.y1) // 2, 0
        loop o.rull {
            MouseClick "WheelDown"
            Sleep 15
        }
        Sleep o.ventRull
        MouseMove o.musBort.x, o.musBort.y, 0
    }
    r.stopp := "ikke funnet på " o.maksSider " skjermsider"
    return r
}
