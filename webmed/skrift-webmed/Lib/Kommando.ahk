; =============================================================================
; Lib\Kommando.ahk  –  dagsliste.ahk v0.6.1 (del B av v0.6, 27.10.2026)
;
; B3: kommandoene til den åpne Skrift-fanen (POST /commands, rettigheten
; kommando): ring pasienten som er åpen i WebMed (v0.6.1) eller et markert
; nummer, ny innsjekk for en time i Avtaler, og et
; videorom med pasientlenken limt inn der markøren står. Ingenting sendes uten
; at brukeren trykker tasten, aldri i løkke, og [skrift] send_kommando=0 viser
; bare kroppen. Oppringing og Ny innsjekk skjer først når brukeren klikker i
; Skrift. Telefonnummer, lenke og rom-ID står aldri i loggen.
; =============================================================================

; Kopi av det som er markert (uten Ctrl+A), med markør på utklippstavlen.
; Svar: {kom, tekst, pt (PatientText funnet)}. Utklippstavlen settes tilbake.
KopierUtvalg() {
    SlippTaster()
    lagret := ClipboardAll()
    A_Clipboard := SENTINEL
    Sleep 30
    Send "^c"
    r := {kom: false, tekst: "", pt: false}
    slutt := A_TickCount + K.utklipp
    while A_TickCount < slutt {
        t := A_Clipboard
        if t != SENTINEL {
            ; En tom kopi kan komme før den riktige (Notisblokk, funnet i del A)
            igjen := A_TickCount + 500
            while t = "" && A_TickCount < igjen {
                Sleep 50
                t := A_Clipboard
            }
            r.kom := true, r.tekst := t
            try r.pt := LesPatientText(t).funnet
            break
        }
        Sleep 30
    }
    A_Clipboard := lagret
    lagret := ""
    return r
}

; Norske telefonnumre i en tekst: 8 sifre, med eller uten +47, 0047 eller 47,
; mellomrom, bindestrek eller parentes. Svar: liste med de 8 sifrene.
FinnNumre(t) {
    ut := []
    pos := 1
    while pos := RegExMatch(t, "\+?\d[\d \-()\x{00A0}]*\d", &m, pos) {
        d := RegExReplace(m[0], "\D")
        nr := ""
        if StrLen(d) = 8
            nr := d
        else if StrLen(d) = 10 && SubStr(d, 1, 2) = "47"
            nr := SubStr(d, 3)
        else if StrLen(d) = 12 && SubStr(d, 1, 4) = "0047"
            nr := SubStr(d, 5)
        if nr != ""
            ut.Push(nr)
        pos += m.Len
    }
    return ut
}

VisNummer(nr) => SubStr(nr, 1, 3) " " SubStr(nr, 4, 2) " " SubStr(nr, 6, 3)

RingKropp(nr) => '{"type": "ring", "til": ' JS(nr) '}'
NyInnsjekkKropp(ref, kat, tools := "", egne := "") {
    j := '{"type": "ny-innsjekk", "referanse": ' JS(ref) ', "kategori": ' JS(kat)
    if IsObject(tools) && tools.Length
        j .= ', "tools": ' JSListe(tools)
    if IsObject(egne) && egne.Length {
        s := ""
        for x in egne
            s .= (s = "" ? "" : ", ") Integer(x)
        j .= ', "customFormIds": [' s ']'
    }
    return j '}'
}
VideoKropp(ref := "") => ref = "" ? '{"type": "videorom"}' : '{"type": "videorom", "referanse": ' JS(SubStr(ref, 1, 60)) '}'

; ---------------------------------------------------------------- ring ----
; v0.6.1 (Daniel 27.10: «Hurtigtasten skal hente nummeret derfra», fra telefonknappen
; i pasientbanneret). Banneret er skjult for UIA, og knappen er en tel:-lenke. Samme
; nummer står i «Send SMS» (WebMeds Ctrl+1), et eget WPF-vindu som er synlig for UIA,
; i feltet med AutomationId PhoneNumber. Skriptet åpner vinduet, leser feltet og
; lukker det med WM_CLOSE. Det sender aldri en tast mens vinduet er åpent («Send»
; har tilgangstasten Alt+S).
; I WebMeds hovedvindu hentes alltid nummeret til pasienten som er åpen; skriptet
; kopierer ikke der. Sett 27.10: Ctrl+C i notatet uten markering kopierer hele
; notatet (med PatientText), så et nummer i notatet ville sett «markert» ut. I andre
; vinduer (Notisblokk, nettleseren, meldingsvinduet) ringes ett markert nummer som
; før. Nummeret og hvor det kom fra vises alltid før Ja.
RingTast(*) {
    LesSending()
    hwnd := WinExist("A")
    ; Ingen tast (heller ikke Ctrl+C) til et SMS-vindu brukeren har åpnet selv
    if WinExist(K.smsVindu) {
        Logg("ring: «Send SMS» er åpent fra før, stopper")
        Melding("«Send SMS» er åpent i WebMed. Lukk det først (uten å sende), og trykk " K.tastRingTekst " i journalen igjen.", "Icon!")
        return
    }
    hv := WebMedHoved(hwnd)
    try Logg("ring: aktivt vindu " WinGetProcessName(hwnd) ", WebMed: " (!hv ? "nei" : hv = hwnd ? "hovedvinduet" : "et lite vindu eid av hovedvinduet"))
    iWebMed := !!hv
    if hv && hv != hwnd {
        try {
            WinActivate hv
            WinWaitActive hv, , 1
        }
        hwnd := hv
    }
    if iWebMed {
        p := NummerFraPasient(hwnd)
        if p.feil != "" {
            Melding(p.feil, "Icon!")
            return
        }
        numre := [p.nr]
        kilde := "Nummeret er mobilnummeret til pasienten som er åpen i WebMed (fra «Send SMS»)."
    } else {
        kp := KopierUtvalg()
        if !kp.kom || Trim(kp.tekst) = "" {
            Logg("ring: ingen markert tekst, ikke i WebMed")
            Melding("Fant ingen markert tekst. Trykk " K.tastRingTekst " i journalen til pasienten i WebMed, eller marker et telefonnummer og trykk tasten igjen.", "Icon!")
            return
        }
        numre := FinnNumre(kp.tekst)
        Logg("ring: markert " StrLen(kp.tekst) " tegn, " numre.Length " norske nummer, PatientText " (kp.pt ? "ja" : "nei"))
        if numre.Length != 1 {
            Melding(numre.Length ? "Det markerte har " numre.Length " telefonnumre. Marker bare ett og prøv igjen." : "Det markerte er ikke et norsk telefonnummer (8 sifre, med eller uten +47).", "Icon!")
            return
        }
        kilde := "Nummeret er det du markerte."
    }
    nr := numre[1]
    if !SkriftJa("Ring via Skrift", "Ring " VisNummer(nr) " via Skrift?`n`n" kilde "`n`nSkrift spør deg igjen, og det ringes først når du klikker «Ring» der.", "Ja, be Skrift ringe", "Avbryt") {
        Logg("ring: avbrutt av brukeren")
        return
    }
    SendKommando(RingKropp(nr), "ring", "")
}

; WebMeds hovedvindu (journalen, Avtaler). Svar: hovedvinduets hwnd eller 0.
; Sett 27.10: forgrunnsvinduet i WebMed kan være et lite vindu uten tittel (574x14)
; som hovedvinduet eier; da regnes det som hovedvinduet, og det aktiveres før
; Ctrl+1. Egne dialoger med tittel («Send SMS», meldingsvinduet) teller ikke.
WebMedHoved(hwnd) {
    try {
        if !hwnd || WinGetProcessName(hwnd) != "TNW.Desktop.WPF.exe"
            return 0
        hv := WinExist(K.vindu)
        if hv && (hwnd = hv || (WinGetTitle(hwnd) = "" && DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr") = hv))
            return hv
    }
    return 0
}

; Mobilnummeret til pasienten som er åpen i WebMed. Svar: {nr, feil}.
; Åpner «Send SMS» med [webmed] sms_tast (Ctrl+1), leser PhoneNumber via UIA og lukker
; vinduet med WM_CLOSE. Ingen tastetrykk til SMS-vinduet. Nummeret logges aldri.
NummerFraPasient(hwnd) {
    if WinExist(K.smsVindu)
        return {nr: "", feil: "Et SMS-vindu er allerede åpent i WebMed. Lukk det først (uten å sende) og trykk " K.tastRingTekst " igjen."}
    ; v0.7.1 (R5 30.10): en meldingsboks fra WebMed (f.eks. «Lib/Cave ikke lest inn»)
    ; svelger Ctrl+1. Stopp før tasten sendes.
    try {
        for w in WinGetList("ahk_pid " WinGetPID(hwnd))
            if WinGetClass(w) = "#32770"
                return {nr: "", feil: "WebMed har en meldingsboks åpen. Les og lukk den først, og trykk " K.tastRingTekst " igjen."}
    }
    t0 := A_TickCount
    Hint("Henter telefonnummeret til pasienten i WebMed …")
    SlippTaster()
    try WinActivate hwnd
    Send K.smsTast
    sh := WinWait(K.smsVindu, , 3)
    if !sh {
        HintSkjul()
        Logg("ring: «Send SMS» åpnet seg ikke innen 3 s")
        return {nr: "", feil: "WebMed åpnet ikke «Send SMS» (" TastTekst(K.smsTast) "), så telefonnummeret kunne ikke hentes. Trykk " K.tastRingTekst " i journalen til pasienten (i Avtaler virker ikke " TastTekst(K.smsTast) ")."}
    }
    verdi := "", funnet := false
    slutt := A_TickCount + 1500
    while A_TickCount < slutt {
        try {
            verdi := UIA.ElementFromHandle(sh).FindElement({AutomationId: "PhoneNumber"}).Value
            funnet := true
            if Trim(verdi) != ""
                break
        }
        Sleep 100
    }
    try WinClose sh
    lukket := WinWaitClose(sh, , 2)
    try WinActivate hwnd
    HintSkjul()
    Logg("ring: «Send SMS» lest og " (lukket ? "lukket" : "IKKE lukket") ", felt " (funnet ? StrLen(Trim(verdi)) " tegn" : "ikke funnet") ", " (A_TickCount - t0) " ms")
    if !lukket
        return {nr: "", feil: "SMS-vinduet i WebMed ble ikke lukket. Lukk det selv med «Lukk», og trykk ikke Send."}
    if !funnet
        return {nr: "", feil: "Fant ikke telefonfeltet i «Send SMS» (WebMed kan være endret). Ring fra Skrift i stedet."}
    return TolkSmsNummer(verdi)
}

; Feltet i «Send SMS» -> {nr, feil}. Tomt: pasienten har ikke mobilnummer i WebMed.
TolkSmsNummer(verdi) {
    if Trim(verdi) = ""
        return {nr: "", feil: "Pasienten har ikke mobilnummer i WebMed (feltet i «Send SMS» er tomt)."}
    n := FinnNumre(verdi)
    if n.Length != 1
        return {nr: "", feil: "Telefonnummeret til pasienten i WebMed er ikke ett norsk nummer (8 sifre, med eller uten +47)."}
    return {nr: n[1], feil: ""}
}

; ---------------------------------------------------------- ny innsjekk ----
NyInnsjekkTast(*) {
    LesSending()
    hwnd := WinExist(K.vindu)
    ; v0.8.0 (Daniel 31.10): i journalen gjelder tasten pasienten som står framme
    fraJournal := hwnd && MenyKontekst(hwnd) = "journal"
    try {
        if fraJournal {
            pid := WinGetPID(hwnd)
            SjekkVinduer(hwnd, pid, "start")
            t := PasientIJournalen(hwnd, pid)
            ref := JournalReferanse(t)
        } else {
            doc := AvtalerMedDato(hwnd)
            t := VelgTimeIAvtaler(doc, "Ny innsjekk i Skrift")
            if !IsObject(t)
                return
            ref := Referanse(t)
        }
    } catch as e {
        Melding(e.Message, "Icon!")
        return
    }
    v := VelgKategori(ref)
    if !IsObject(v) {
        Logg("ny-innsjekk " ref ": avbrutt av brukeren")
        return
    }
    ; v0.7.1 (Daniel 31.10, S1): innsjekken lages direkte med POST /checkins (som
    ; legemiddelgjennomgangen), ikke via kommandoen ny-innsjekk som bare åpnet
    ; skjemaet i Skrift. Meldingen til pasienten kommer tilbake og kan limes inn.
    ; Bryteren er send_lmg (samme rettighet, innsjekk).
    t0 := A_TickCount
    tidsp := fraJournal ? "" : Tidspunkt(t.fra, LISTEDATO)
    kropp := InnsjekkKropp(ref, v.kategori, v.tools, v.egne, tidsp)
    Logg("=== Ny innsjekk v" SKRIPT_VERSJON " (" (K.sendLmg ? "sending PÅ" : "tørrkjøring") "), " ref " " v.kategori " ===")
    if !K.sendLmg {
        fil := NesteFil("torrkjoring-innsjekk")
        SkrivFil(fil, kropp)
        Logg("innsjekk " ref ": tørrkjøring skrevet til " StrReplace(fil, K.logg "\", "") " (" StrLen(kropp) " tegn)")
        Hint "Skrift: tørrkjøring skrevet (" ref ").`n" fil "`nIngenting er sendt ([skrift] send_lmg=0)."
        SetTimer HintSkjul, -30000
        return
    }
    SendLmg(kropp, ref, "", tidsp, "", t0, t, v.kategori)
}

; Kroppen til POST /checkins for kategori time eller skjema (handoffen §3).
InnsjekkKropp(ref, kat, tools, egne, tidsp) {
    n := "`n"
    j := "{" n '  "reference": ' JS(ref) "," n '  "kategori": ' JS(kat) "," n
    if IsObject(tools) && tools.Length
        j .= '  "tools": ' JSListe(tools) "," n
    if IsObject(egne) && egne.Length {
        s := ""
        for x in egne
            s .= (s = "" ? "" : ", ") Integer(x)
        j .= '  "customFormIds": [' s "]," n
    }
    if tidsp != ""
        j .= '  "appointmentAt": ' JS(tidsp) "," n
    j .= '  "kilde": "WebMed",' n
    j .= '  "kildeVersjon": ' JS(KildeVersjon()) "," n
    j .= '  "skriptVersjon": ' JS(SKRIPT_VERSJON) n "}"
    return j
}

; Time eller Skjema. Skjema: skjemaene fra GET /checkins/catalog (krever minst ett).
; Svar: {kategori, tools, egne} eller 0.
VelgKategori(ref) {
    d := DialogNy("Ny innsjekk for «" ref "»", "sporsmal")
    g := d.g
    DialogTekst(d, "Hva skal pasienten fylle ut? Innsjekken lages i Skrift med en gang, og meldingen til pasienten (lenke og PIN-kode) kommer tilbake hit. Legemiddelgjennomgang: bruk " K.tastLmgTekst ".")
    rTime := g.AddRadio("x22 y" d.y " Checked", "Time (standardspørsmålene før timen)")
    rSkjema := g.AddRadio("x22 y" (d.y + 30), "Skjema (velg skjemaene i neste steg)")
    d.y += 64
    valg := ""
    kn := DialogKnapper(d, Map("ok", "Fortsett", "avbryt", "Avbryt"))
    kn["ok"].OnEvent("Click", (*) => (valg := rSkjema.Value ? "skjema" : "time", g.Destroy()))
    kn["avbryt"].OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    h := g.Hwnd
    g.Show("w" d.w " h" d.y)
    WinWaitClose h
    if valg = ""
        return 0
    if valg = "time"
        return {kategori: "time", tools: [], egne: []}
    return VelgSkjema(ref)
}

VelgSkjema(ref) {
    try {
        tok := LesToken()
        svar := KallSkrift("GET", "/checkins/catalog", "", tok)
        tok := ""
    } catch as e {
        Melding("Fikk ikke hentet skjemaene fra Skrift: " e.Message, "Icon!")
        return 0
    }
    r := TolkSvar(svar)
    Logg("GET /checkins/catalog: " svar.status (r.kode != "" ? " " r.kode : ""))
    if svar.status != 200 || !(r.j is Map) {
        Melding(FeilForBruker(r, "Skjemaene", "innsjekk"), "Icon!")
        return 0
    }
    valg := []   ; {navn, id, egen}
    for del in ["standard", "egne", "klinikk"]
        if r.j.Has(del) && r.j[del] is Array
            for s in r.j[del]
                try valg.Push({navn: s["navn"] (del = "standard" ? "" : " (" del ")"), id: s["id"], egen: del != "standard"})
    if !valg.Length {
        Melding("Skrift har ingen skjemaer å velge.", "Icon!")
        return 0
    }
    navn := []
    for x in valg
        navn.Push(x.navn)
    d := DialogNy("Skjemaer for «" ref "»", "sporsmal")
    g := d.g
    DialogTekst(d, "Velg ett eller flere skjemaer (Ctrl+klikk for flere):")
    lb := g.AddListBox("x22 y" d.y " w" (d.w - 44) " Multi r" Min(12, valg.Length), navn)
    lb.GetPos(, , , &lh)
    d.y += lh + 6
    valgt := ""
    kn := DialogKnapper(d, Map("ok", "Fortsett", "avbryt", "Avbryt"))
    kn["ok"].OnEvent("Click", (*) => (valgt := lb.Value, g.Destroy()))
    kn["avbryt"].OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    h := g.Hwnd
    g.Show("w" d.w " h" d.y)
    WinWaitClose h
    if !IsObject(valgt) || !valgt.Length
        return 0
    tools := [], egne := []
    for i in valgt {
        if valg[i].egen
            egne.Push(valg[i].id)
        else
            tools.Push(valg[i].id)
    }
    return {kategori: "skjema", tools: tools, egne: egne}
}

; --------------------------------------------------------------- video ----
VideoTast(*) {
    global INNSJEKK
    LesSending()
    hwnd := WinExist("A")
    ref := ""
    ; Romnavnet: referansen til innsjekken fra B1 når den er fersk (og brukeren
    ; sier ja), ellers uten. Aldri navn.
    if IsObject(INNSJEKK) && A_TickCount - INNSJEKK.laget < 30 * 60 * 1000 {
        sp := SkriftBoks("Videorom", "Romnavn «" INNSJEKK.ref "» (fra innsjekken)?`n`n«Uten navn» gir et rom uten referanse.", Map("ja", "Ja, «" INNSJEKK.ref "»", "nei", "Uten navn", "avbryt", "Avbryt"), "sporsmal")
        if sp = "avbryt" || sp = "lukk"
            return
        if sp = "ja"
            ref := INNSJEKK.ref
        WinActivate hwnd
        WinWaitActive hwnd, , 2
    }
    ; v0.8.0 (Daniel 31.10): i journalen skal lenken rett på utklippstavlen, og kunne
    ; limes inn i meldingen til pasienten med en gang (Ctrl+3). Sendes aldri av skriptet.
    ; v0.9.0: i meldingen til pasienten limes lenken inn der; ellers (Avtaler, utenfor
    ; WebMed) legges den på utklippstavlen, uten å skrive i vinduet som var aktivt.
    kt := MenyKontekst(hwnd)
    SendKommando(VideoKropp(ref), "videorom", ref, hwnd, kt = "journal" ? "journal" : kt = "melding" ? "lim" : "utklipp")
}

; Åpner meldingen til pasienten ([webmed] melding_tast, Ctrl+3) og skriver teksten
; i tekstfeltet. Svar: true når teksten er skrevet inn.
LimInnIMelding(hwnd, tekst) {
    mv := ApneMelding(hwnd)
    if !mv
        return false
    SlippTaster()
    SendText tekst
    return true
}

; v0.9.0: åpner meldingen til pasienten (melding_tast) og setter markøren i det
; største tekstfeltet. Svar: meldingsvinduet, eller 0 når det ikke kom (pasienten
; er ikke digitalt aktiv, eller WebMed svarte ikke på 6 s).
ApneMelding(hwnd) {
    pid := WinGetPID(hwnd)
    Aktiver(hwnd)
    Send K.meldingTast
    mv := VentPaa(() => FinnMeldingsvindu(pid), 6000)
    if !mv
        return 0
    WinActivate mv
    WinWaitActive mv, , 2
    felt := 0, h := 0
    try {
        for e in UIA.ElementFromHandle(mv).FindElements({ClassName: "TextBox"}) {
            r := e.BoundingRectangle
            if r.b - r.t > h
                felt := e, h := r.b - r.t
        }
    }
    if !felt
        return 0
    try felt.SetFocus()
    Sleep 200
    return mv
}

FinnMeldingsvindu(pid) {
    for w in WinGetList("ahk_pid " pid)
        if ErMeldingsvindu(w)
            return w
    return 0
}

; -------------------------------------------------------------- felles ----
; modus (videorom): "journal" = utklippstavlen og tilbud om å åpne meldingen, "lim" =
; skriv lenken i vinduet som var aktivt (meldingen til pasienten), "utklipp" = bare
; utklippstavlen.
SendKommando(kropp, art, ref, hwnd := 0, modus := "utklipp") {
    if !K.sendKommando {
        Logg("kommando " art (ref != "" ? " " ref : "") ": tørrkjøring, " StrLen(kropp) " tegn, ingenting sendt")
        Melding("Tørrkjøring ([skrift] send_kommando=0). Dette ville blitt sendt til POST /commands:`n`n" kropp)
        return
    }
    try {
        tok := LesToken()
        t1 := A_TickCount
        svar := KallSkrift("POST", "/commands", kropp, tok)
        tok := ""
    } catch as e {
        Logg("POST /commands " art ": nettverksfeil (" e.Message ")")
        Melding("Fikk ikke kontakt med Skrift: " e.Message, "Iconx")
        return
    }
    r := TolkSvar(svar)
    Logg("POST /commands " art (ref != "" ? " " ref : "") ": " svar.status (r.kode != "" ? " " r.kode : "") (r.vent ? ", Retry-After " r.vent " s" : "") " på " (A_TickCount - t1) " ms")
    if svar.status = 202 {
        Melding(art = "ring" ? "Skrift spør nå om å ringe. Klikk «Ring» i Skrift innen 60 sekunder." : "Skrift spør nå om ny innsjekk for «" ref "». Klikk «Åpne» i Skrift innen 60 sekunder.")
        return
    }
    if svar.status = 201 && art = "videorom" {
        lenke := ""
        try lenke := r.j["lenke"]
        if !RegExMatch(lenke, "^https://[a-z0-9.-]*skrift\.md/\S+$") {
            Logg("videorom: lenken mangler eller har ukjent form (" StrLen(lenke) " tegn)")
            Melding("Rommet er laget, men svaret hadde ingen lenke skriptet kjenner igjen. Se under Video i Skrift.", "Icon!")
            return
        }
        if modus != "lim" {
            A_Clipboard := lenke
            Logg("videorom: lenke lagt på utklippstavlen (" StrLen(lenke) " tegn)")
            if modus != "journal" {
                Melding("Videolenken ligger på utklippstavlen (Ctrl+V limer den inn). Rommet står i Skrift under Video; der slipper du pasienten inn.")
                return
            }
            valg := SkriftBoks("Videorom", "Videolenken ligger på utklippstavlen (Ctrl+V limer den inn). Rommet står i Skrift under Video; der slipper du pasienten inn.`n`nÅpne meldingen til pasienten (" TastTekst(K.meldingTast) ") med lenken limt inn? Du sender den selv.", Map("ja", "Åpne meldingen", "nei", "Bare utklippstavlen"), "sporsmal")
            if valg = "ja" {
                if LimInnIMelding(hwnd, lenke)
                    Logg("videorom: lenke limt inn i meldingen til pasienten")
                else
                    Melding("Meldingsvinduet kom ikke (er pasienten digitalt aktiv?). Lenken ligger på utklippstavlen.", "Icon!")
            }
            return
        }
        if hwnd && WinExist(hwnd) {
            WinActivate hwnd
            if WinWaitActive(hwnd, , 2) {
                SlippTaster()
                SendText lenke
                Logg("videorom: lenke limt inn (" StrLen(lenke) " tegn)")
                Melding("Videolenken er limt inn. Rommet står i Skrift under Video; der slipper du pasienten inn.")
                return
            }
        }
        Logg("videorom: vinduet var borte, lenken ikke limt inn")
        Melding("Rommet er laget, men vinduet var borte, så lenken ble ikke limt inn. Se under Video i Skrift.", "Icon!")
        return
    }
    Melding(FeilForBruker(r, art = "ring" ? "Ring" : art = "videorom" ? "Videorommet" : "Ny innsjekk", "kommando"), "Icon!")
}
