; Skrift for WebMed  -  Versjon: 0.11.2  Journalsystem: WebMed  Testet: 2026-11-01 (V-testene) og 2026-11-02 (ekte bruk); v0.11.0 bare uten WebMed
; Ikke en del av Skrift.md som medisinsk utstyr. MIT-lisens; publisert i github.com/danieldydland/skrift-skript (fase 4).
; Versjonen i toppteksten skal være lik SKRIPT_VERSJON (test-v07 sjekker det).
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2
SetWorkingDir A_ScriptDir
#Include Lib\UIA.ahk
#Include Lib\PatientText.ahk
#Include Lib\Journal.ahk
#Include Lib\Kalibrering.ahk
#Include Lib\Innsjekk.ahk
#Include Lib\Kommando.ahk
#Include Lib\Dialog.ahk
#Include Lib\Meny.ahk
#Include Lib\Oppsett.ahk
; =============================================================================
; dagsliste.ahk  –  Skrift.md / Eirskrift AS  –  v0.7
; Leser dagslisten i WebMed (i dag eller en senere dato), skriver den til lokal
; JSON og sender den til Skrift som én bunke (POST /mailbox/batch) bare når
; [skrift] send=1 i config.ini.
;
; Per kjøring (hurtigtast i config.ini, standard Ctrl+Shift+F6 fra v0.6; før Ctrl+Alt+D):
;   1. Leser dagslisten fra Avtaler (nettinnhold i WebView2) via UI Automation.
;   2. For hver time, som v0.1.1: dobbeltklikker timen, kontrollerer
;      klokkeslett, navn og fødselsdato i «Velg kontakt» og velger «Ingen
;      pasientkontakt» (UIA), kontrollerer i «Lukk pasienter» at bare riktig
;      pasient er åpen og trykker Avbryt, kopierer «Tidligere sykdommer» (Alt+S)
;      og «Familie/Sosialt» (Alt+F), henter legemiddellisten med Ctrl+Alt+L,
;      kopierer den og angrer (Ctrl+Z), bekrefter at notatet er tomt, og lukker
;      pasienten med «Lagre og lukk» etter ny navnekontroll.
;      Fra v0.2: de tre feltene leses fra WebMeds utklippsformat PatientText
;      (tekst + pasient-GUID). Alle felt med tekst må ha PatientText, teksten må
;      være lik den kopierte, og GUID-en må være den samme i alle tre. Samme GUID
;      under et annet navn eller en annen fødselsdato senere i kjøringen stopper.
;   3. Skriver eksempler\dagsliste-ÅÅÅÅ-MM-DD.json (UTF-8 uten BOM). «bunke» i
;      filen er nøyaktig kroppen som sendes til POST /mailbox/batch.
;   4. Bare med send=1, hele listen lest og alle poster godkjent: én
;      POST /mailbox/batch med alle postene (tokenet og GET /me er sjekket før
;      WebMed ble rørt). Svaret logges per post: ny, oppdatert, allerede startet
;      i Skrift (ikke endret) eller avvist med grunn.
;   Nytt i v0.3: bunken i stedet for én POST /mailbox per pasient, kjønn og
;   alder fra «ddmmåå (K56)», konvolutten (kilde,
;   kildeVersjon, skriptVersjon) på bunken, avtale-ID-en alltid med som
;   eksternId, og grensene i Skrift (40 tegn i timetype og behandler, høyst 20
;   advarsler på 300 tegn, høyst 60 timer).
;   v0.3.1 (CR-499): navnet sendes ikke til Skrift; det brukes bare lokalt til
;   kontrollene i WebMed. Kjønn og alder på timedagen sendes.
;   v0.3.2 (CR-500): fødselsdatoen sendes som ÅÅÅÅ-MM-DD (fodselsdato). Skrift viser
;   den bare i innboksen; bare kjønn og alder følger med til bakgrunnen.
;   v0.3.3 (Cowork-testen 24.10): musepekeren flyttes til tittellinjen rett
;   etter dobbeltklikket på timen. Ellers kunne den bli stående over CAVE-
;   feltet i journalen, og hoverboksen (et lite vindu uten tittel) stoppet
;   kjøringen som «ukjent vindu».
;   v0.4.0 (24.–25.10, etter Daniels opptak): siste konsultasjon fra Løpende
;   journal, bak bryteren [journal] siste_konsultasjon. WebMed viser ikke
;   journalen i tilgjengelighetslaget, så overskriftene finnes på fargen og
;   klikkes (Lib\Journal.ahk). Et klikk kopierer oppføringen med PatientText;
;   pasient-GUID-en må være lik feltene. Filteret «Kontakt» settes før søket
;   (WebMed nullstiller det når journalen åpnes på nytt). Teksten legges sist i
;   bakgrunn under «Siste konsultasjon DD.MM.ÅÅÅÅ:» (andre typer: «… – Telefon
;   konsultasjon:»), uten legens navn. Typer: [journal] typer. Klikkene endrer
;   ikke journalen.
;   «Lukk pasienter» åpnes med Alt+X (den aktive pasienten), ikke med klikk på
;   den første fanen, så en annen pasient som står åpen fra før ikke er i veien.
;   Står timens egen pasient åpen fra før, leses og lukkes den som de andre
;   (notatet må være tomt; ellers stopper skriptet og lar den stå åpen).
;   v0.4.1 (kodeøkten 25.10): legens navn byttes med «[lege]» også i andre
;   skrivemåter (fornavn først, komma, store bokstaver, hver del av navnet), og
;   pasientens navn byttes med «[pasient]» i all fritekst som går til Skrift
;   (Lib\Journal.ahk SkjulNavn). Antallet står i loggen, aldri navnet.
;   v0.5.0 (kodeøkten 25.10, Daniels beslutning): kalibrering i stedet for faste
;   skjermpunkter. Ctrl+Alt+K (config.ini [kjoring] kalibrer): brukeren peker på
;   fem ting i WebMed hos en fiktiv testpasient og trykker F8 ([kjoring] merk);
;   kolonnen langs overskriftene, fargen, listens høyde og hjulhakkene regnes ut
;   (Lib\Kalibrering.ahk), filteret, en kopi og «Avtaler» prøves, og punktene
;   skrives til config.ini med vindusstørrelse og DPI i [kalibrering]. Er vinduet
;   eller skaleringen annerledes ved kjøring, stopper skriptet før WebMed røres.
;   Uten [kalibrering] godtas bare oppsettet koordinatene ble målt på før v0.5
;   (3456x1416, 96 DPI). Varselfeltets bredde og klikket i timen skaleres med DPI.
;   v0.5.1 (Daniels spørsmål 25.10): WebMed trenger ikke stå maksimert. Skriptet
;   husker plasseringen (GetWindowPlacement), maksimerer vinduet på skjermen
;   kalibreringen ble gjort på, og setter det tilbake (SetWindowPlacement) når
;   kjøringen eller kalibreringen er ferdig eller stopper. Før hvert klikk i
;   Løpende journal sjekkes det at det står en overskrift der (et bånd i
;   overskriftsfargen), så et flyttet panel gir stopp i søket og ikke et klikk
;   på noe annet. Skaleringen leses fra skjermen WebMed står på (GetDpiForWindow),
;   ikke fra hovedskjermen.
;   v0.6.0 (Cowork 27.10, del B av v0.6): tre nye funksjoner med egne taster og
;   egne brytere, av som standard ([skrift] send_lmg=0, send_kommando=0):
;   innsjekk til legemiddelgjennomgang for én time i Avtaler med listen fra
;   Ctrl+Alt+L og fødselsåret (Lib\Innsjekk.ahk, POST /checkins), meldingen til
;   pasienten limt inn der markøren står, og kommandoene ring, ny-innsjekk og
;   videorom (Lib\Kommando.ahk, POST /commands). Tastene er flyttet bort fra
;   WebMeds egne (Ctrl+Alt+D er «Velg diagnose» og Ctrl+Alt+K «Pasient logg
;   flytevindu» i WebMed): Ctrl+Shift+F6 kjører dagslisten, Ctrl+Shift+F7
;   kalibrerer, Ctrl+Shift+F8 til F12 er de nye. Avtaler åpnes med WebMeds egen
;   tast F3 ([kjoring] avtaler_tast; tom = klikk på avtaler_meny som før).
;   Ctrl+Shift+F5 ([kjoring] meny) åpner en meny med alle valgene. Hintet
;   er et større, tydeligere felt nede til venstre (ikke en vanlig ToolTip), og
;   det går ikke an å klikke på det. LesTime er delt i ApneTime og LukkTime,
;   så B1 bruker nøyaktig samme åpning, kontroller og lukking som dagslisten.
;   v0.6.1 (Daniel 27.10: «Hurtigtasten skal hente nummeret derfra»): ring henter
;   nummeret til pasienten som er åpen i WebMed. Telefonknappen i banneret er
;   skjult for UIA, men «Send SMS» (WebMeds Ctrl+1) er et eget vindu med nummeret
;   i feltet PhoneNumber. Skriptet åpner det, leser feltet og lukker det med
;   WM_CLOSE uten å sende en tast til det. Ett markert nummer brukes fortsatt
;   først. [webmed] sms_vindu og sms_tast.
;
;   v0.10.0 (Daniel 02.11): veiviser ved første kjøring (Lib\Oppsett.ahk): tokenet fra
;   Skrift tas imot i et skjult felt og skrives til en egen fil utenfor skriptmappen,
;   prøves med GET /me; bryterne (normal bruk eller tørrkjøring); kalibreringen. Også
;   fra menyen (Mer → Oppsett).
;   v0.11.2 (SUP-2026-11-08-A, første eksterne bruker, to skjermer): veiviseren
;   startet kalibreringen samtidig med boksen «Ferdig», og når kalibreringen
;   stoppet, ble grunnen straks overskrevet av «Skrift er klar». Nå kjøres
;   kalibreringen ferdig før «Ferdig»; en stoppet kalibrering viser grunnen i en
;   boks («Prøv igjen», «Åpne loggen») og huskes til meldingen «ikke kalibrert»;
;   Ctrl+Shift+M merker et punkt i tillegg til F8 (bærbar PC uten Fn); hintet står
;   på skjermen WebMed står på; skjermene skrives i loggen.
;   v0.7.0 (Daniel 29.10): kontekstmeny (Lib\Meny.ahk): menytasten, og valgfritt et
;   musetrykk ([kjoring] meny_mus), viser det som kan gjøres fra flaten man står i
;   (Avtaler, journalen, meldingsvinduet, utenfor WebMed), med «Alle valg» under.
;   Alle bokser, spørsmål og innskrivingsfelt har samme utseende (Lib\Dialog.ahk):
;   toppbånd i Skrifts farge, Segoe UI, knappene nederst til høyre, Esc lukker.
;   v0.8.0 (Daniel 31.10): innsjekk (Ctrl+Shift+F8) og legemiddelgjennomgang
;   (Ctrl+Shift+F9) rett fra journalen for pasienten som står framme (navnet fra
;   «Lukk pasienter», referansen «initialer dd.MM»); videorom (Ctrl+Shift+F12)
;   fra journalen legger lenken på utklippstavlen og kan åpne meldingen til
;   pasienten (Ctrl+3, [webmed] melding_tast) med lenken limt inn – sendes aldri.
;   v0.9.0 (Daniel 31.10: «én enkel og lett hurtigtast som åpner en meny som viser
;   alle muligheter, men har grået ut de veiene som ikke fungerer der»): F11
;   ([kjoring] meny; F1–F10 og F12 er WebMeds) åpner menyen. Den er lik overalt,
;   i samme rekkefølge, tallet velger linjen (F11, 1 = legemiddelgjennomgang);
;   det som ikke passer flaten er grått med grunnen bak. «Mer» har loggen,
;   config.ini, hjelp og avslutt; ikonet nede til høyre har det samme. Hintet
;   ved oppstart er én setning. Ctrl+Shift-tastene virker som før (Lib\Meny.ahk).
;
; Sikkerhet: «Lagre og lukk» trykkes bare når notatet er bekreftet tomt. Alt
; uventet (kladd i notatet, sen legemiddelliste, ukjent vindu eller
; meldingsboks, manglende eller ulik PatientText) stopper kjøringen og lar
; pasienten stå åpen. Ingen innliming i WebMed, fødselsnummer fjernes.
; Nettverk: bare https://api.skrift.md, og bare når send=1.
; Loggen (logg\ÅÅÅÅ-MM-DD.txt) inneholder referanser, lengder, tider og
; statuskoder, aldri journaltekst, navn, dialogtekst, pasient-ID eller token.
; Ctrl+Alt+X avbryter mellom to steg.
; =============================================================================

global SKRIPT_VERSJON := "0.11.2"
global SKRIFT_BASE := "https://api.skrift.md/api/integrations/v1"
global KONFIG := A_ScriptDir "\config.ini"
; v0.10.4 (Daniel 04.11): config.ini følger ikke med i pakken, så en oppdatering aldri
; overskriver bryterne, menytasten og kalibreringen. Mangler filen, lages den fra
; malen Lib\config-standard.ini (veiviseren tar seg av tokenet og resten etterpå).
global KONFIG_NY := false
if !FileExist(KONFIG) && FileExist(A_ScriptDir "\Lib\config-standard.ini") {
    try {
        FileCopy A_ScriptDir "\Lib\config-standard.ini", KONFIG
        KONFIG_NY := true
    }
}
global K := LesKonfig()
if KONFIG_NY
    Logg("config.ini laget fra Lib\config-standard.ini (første kjøring)")
global AVBRUTT := false
global KJORER := false
global PASIENT_APEN := ""
global SENTINEL := "<<skrift-utklipp-tomt-" A_TickCount ">>"
global WM_VERSJON := ""
global LISTEDATO := ""            ; datoen Avtaler skal vise (i dag, eller testdato)
global SETTE_PASIENTER := Map()   ; pasient-GUID -> {nokkel: "navn|fødselsdato", nr}
; Feltrekkefølgen i hver post i POST /mailbox/batch (handoffen §3). Konvolutten
; (kilde, kildeVersjon, skriptVersjon) står på bunken; på en post gir den «avvist».
; Navnet sendes ikke (CR-499): pasientOverskrift og fodselsar er ikke med. Fødselsdatoen
; går i fodselsdato (CR-500) og vises bare i innboksen i Skrift.
global POST_FELT := ["referanse", "tidspunkt", "eksternId", "fodselsdato", "kjonn", "alder",
    "timekommentar", "bakgrunn", "familieSosialt", "legemiddelliste", "advarsler",
    "timetype", "varighetMin", "behandler", "eksternPasientId"]

PatientTextFormat()   ; registrerer utklippsformatet; stopper her hvis det feiler
Hotkey K.hurtigtast, KjorDagsliste
Hotkey K.avbryt, Avbryt
Hotkey K.kalibrer, Kalibrer
; v0.6.0: legemiddelgjennomgang, lim inn meldingen, ny innsjekk, ring og video
for tast, fn in Map(K.tastLmg, LmgTast, K.tastLimInn, LimInnTast, K.tastNyInnsjekk, NyInnsjekkTast, K.tastRing, RingTast, K.tastVideo, VideoTast, K.tastMeny, MenyTast)
    if tast != ""
        Hotkey tast, fn
; v0.7: menyen også på et musetrykk i WebMed (tom = av), for eksempel ^RButton
if K.tastMenyMus != "" {
    HotIfWinActive K.vindu
    Hotkey K.tastMenyMus, MenyTast
    HotIfWinActive
}
A_IconTip := "Skrift " SKRIPT_VERSJON " – " K.tastMenyTekst " åpner menyen (" Modus() ")"
TrayMenyOppsett()
; v0.10.0: uten et gyldig token startes veiviseren (etter at tastene er på plass)
global FORSTE_KJORING := !TokenKlar()
if FORSTE_KJORING
    SetTimer(() => Veiviser(true), -800)
for arg in A_Args
    if arg = "/kjor"
        SetTimer KjorDagsliste, -500
; v0.9.0: én tast og én setning. Alt annet står i menyen (og under Mer → hjelp).
if !FORSTE_KJORING {
    Hint "Skrift " SKRIPT_VERSJON " er klar. " K.tastMenyTekst " åpner menyen der du står (tallet velger). " ModusKort() "." StartSjekk()
    SetTimer HintSkjul, -8000
}
SetTimer () => ToolTip(), -4000

Modus() => K.send ? "sending til Skrift er PÅ" : "tørrkjøring, ingenting sendes"
ModusNye() => "legemiddelgjennomgang " (K.sendLmg ? "SENDES" : "tørrkjøring") ", kommandoer " (K.sendKommando ? "SENDES" : "tørrkjøring")

; Ved oppstart: er skaleringen en annen enn ved kalibreringen, sier hintet det
; med en gang. Vinduets størrelse sjekkes ved kjøring, når WebMed er maksimert.
; v0.10.3 (rapportfunn 2): står WebMed alt maksimert, sammenlignes den
; faktiske størrelsen alt her (før bekreftelsen og hintet), så en endret
; Windows-skalering uten omstart av WebMed stopper før noe leses.
StartSjekk() {
    hwnd := WinExist(K.vindu)
    vindu := KalMal()
    if hwnd {
        try if WinGetMinMax(hwnd) = 1
            vindu := VinduStr(hwnd)
    }
    m := KalSjekk({vindu: K.kalVindu, dpi: K.kalDpi}, {vindu: vindu, dpi: hwnd ? VinduDpi(hwnd) : A_ScreenDPI}, K.kalibrerTekst)
    return m = "" ? "" : "`n" m
}

; Størrelsen WebMed skal ha når det er maksimert: fra kalibreringen, ellers
; oppsettet koordinatene før v0.5 ble målt på
KalMal() => K.kalVindu != "" ? K.kalVindu : KAL_REFERANSE.vindu

; Hintet står fast nederst til venstre, ikke ved musepekeren, så det aldri
; ligger over et punkt skriptet klikker på (menyvalg, fane-x, notatfelt).
; v0.6.0 (Daniel 27.10: «litt mer synlig underveis»): et eget felt med større
; skrift og farget bakgrunn i stedet for en ToolTip. Det tar aldri fokus
; (WS_EX_NOACTIVATE) og slipper musen gjennom (WS_EX_TRANSPARENT og
; gjennomsiktighet), så klikk og dobbeltklikk under det går til WebMed.
global HINT_GUI := 0
global HINT_STRIPE := ""   ; fargen på stripen i hintet (for testene)
; v0.9.1 (funn 10): art "stopp" gir rød stripe også når teksten ikke har ordet STOPP.
; Teksten "Ingen innsjekk er laget" og "STOPPET" regnes som stopp uansett.
Hint(tekst, art := "") {
    global HINT_GUI, HINT_STRIPE
    if art = "" && (InStr(tekst, "STOPP") || InStr(tekst, "Ingen innsjekk er laget") || InStr(tekst, "ingen innsjekk for"))
        art := "stopp"
    ; v0.7.1 (30.10): en ventende HintSkjul fra forrige kjøring (30 s etter et stopp)
    ; skjulte hintet midt i neste kalibrering. Avlyses her.
    try SetTimer HintSkjul, 0
    try {
        if IsObject(HINT_GUI)
            HINT_GUI.Destroy()
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x08000020", "Skrift-hint")
        ; v0.7: hvit flate med en stripe i Skrifts farge til venstre (rød ved STOPP)
        g.BackColor := "FFFFFF"
        g.MarginX := 0, g.MarginY := 0
        HINT_STRIPE := art = "stopp" ? "B00000" : art = "varsel" ? "B35C00" : "009090"
        stripe := g.AddText("x0 y0 w8 h40 Background" HINT_STRIPE)
        g.SetFont("s13 c1F1F1F", "Segoe UI")
        g.AddText("x24 y12 w760", tekst)
        g.Show("Hide AutoSize")
        g.GetPos(, , &w, &h)
        h += 12
        stripe.Move(0, 0, 8, h)
        hp := HintPlass(h)
        g.Show("x" hp.x " y" hp.y " w" (w + 24) " h" h " NoActivate")
        WinSetTransparent 240, g
        HINT_GUI := g
    } catch {
        CoordMode "ToolTip", "Screen"
        ToolTip tekst, 20, A_ScreenHeight - 200
    }
}

; v0.11.2 (SUP-2026-11-08-A, to skjermer): hintet står nederst til venstre på
; skjermen WebMed står på, ikke alltid på hovedskjermen. Uten WebMed-vindu
; (eller minimert): hovedskjermen som før.
HintPlass(h) {
    x := 20, y := A_ScreenHeight - h - 70
    try {
        hw := WinGetID(K.vindu)
        if WinGetMinMax(hw) != -1 {
            WinGetPos(&wx, &wy, &ww, &wh, hw)
            if (n := SkjermVed(wx + ww // 2, wy + wh // 2)) {
                MonitorGet(n, &l, &t, &r, &b)
                x := l + 20, y := b - h - 70
            }
        }
    }
    return {x: x, y: y}
}

; Skjermene til loggen (antall, størrelse, plassering, hovedskjermen og hvor WebMed står)
SkjermOversikt(hwnd := 0) {
    try {
        skjermer := [], wm := 0
        loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            skjermer.Push({l: l, t: t, r: r, b: b})
        }
        if hwnd {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            wm := SkjermVed(wx + ww // 2, wy + wh // 2)
        }
        return SkjermTekst(skjermer, MonitorGetPrimary(), wm)
    }
    return "ukjent"
}

HintSkjul(*) {
    global HINT_GUI
    try {
        if IsObject(HINT_GUI)
            HINT_GUI.Destroy()
    }
    HINT_GUI := 0
    ToolTip()
}

; -----------------------------------------------------------------------------
KjorDagsliste(*) {
    global KJORER, AVBRUTT, PASIENT_APEN
    if KJORER
        return
    KJORER := true, AVBRUTT := false, PASIENT_APEN := ""
    DirCreate K.logg
    DirCreate K.eksempler
    lagret := ClipboardAll()
    t0 := A_TickCount
    LesSending()   ; [skrift] leses på nytt ved hver kjøring
    ; v0.9.1 (funn 19): kalibreringen sjekkes før hintet sier at listen leses
    if (s := StartSjekk()) != "" {
        Logg("STOPP før start (v" SKRIPT_VERSJON "): " Trim(s, "`n"))
        Hint "Skrift: STOPPET`n" Trim(s, "`n"), "stopp"
        SetTimer HintSkjul, -30000
        KJORER := false
        return
    }
    ; v0.9.1 (funn 13): bekreftelse med datoen Avtaler viser, så tasten aldri
    ; leser dagens ekte liste uten at brukeren har sett datoen
    if !BekreftDagsliste() {
        Logg("Dagslisten: avbrutt ved bekreftelsen (ingen kjøring)")
        KJORER := false
        return
    }
    ; v0.10.3 (rapportfunn 4): startlinjen først når brukeren har sagt «Les»
    Logg("=== Start v" SKRIPT_VERSJON " (" Modus() ") ===")
    Logg("Innhold i dagslisten: " InnholdTekst() (K.jPa && K.jFilter ? " (siste konsultasjon med filteret «Kontakt»)" : ""))
    if K.sendUkjent
        Logg("[skrift] send er verken 0 eller 1 (" K.sendUkjent " tegn); behandles som 0")
    Hint "Skrift: leser dagslisten … ikke bruk mus eller tastatur. " K.avbrytTekst " avbryter."
    res := 0
    try {
        if K.send
            SjekkToken()
        r := Kjor()
        Logg("Dagslisten er lest: " r.antall " timer på " (A_TickCount - t0) " ms" (r.fil != "" ? " -> " r.fil : " (ingen fil, sending er på)"))
        res := r
    } catch as e {
        res := 0
        Logg("STOPP: " e.Message)
        try Logg("  (teknisk: " e.What ", " StrReplace(e.File, A_ScriptDir "\", "") " linje " e.Line ")`r`n" StrReplace(e.Stack, A_ScriptDir "\", ""))
        tillegg := ""
        if PASIENT_APEN != "" {
            tillegg := "`nPasienten for " PASIENT_APEN " står åpen i WebMed. Sjekk at notatfeltet er tomt før du lukker den selv."
            Logg("Pasient står åpen: " PASIENT_APEN)
        }
        Hint "Skrift: STOPPET`n" e.Message tillegg "`nIngenting er sendt til Skrift. Se loggen."
    }
    ; Utklippstavlen tilbake før eventuell sending; WebMed-delen er ferdig her
    A_Clipboard := lagret
    lagret := ""
    Logg("Utklippstavlen er satt tilbake")
    if IsObject(res) {
        melding := "Skrift: ferdig. " res.antall " timer " (res.fil != "" ? "skrevet til " res.fil : "lest (ingenting lagret på PC-en)")
        if K.send {
            try {
                ; Bryteren må fortsatt stå på 1 når sendingen starter
                LesSending()
                if !K.send
                    throw Error("[skrift] send er ikke lenger 1 i config.ini; ingenting er sendt")
                melding .= "`n" SendTilSkrift(res)
            }
            catch as e {
                Logg("SENDING STOPPET: " e.Message)
                melding .= "`nSending STOPPET: " e.Message "`nSe loggen."
            }
        } else
            melding .= "`nTørrkjøring: ingenting er sendt ([skrift] send=0)."
        Logg("FERDIG på " (A_TickCount - t0) " ms")
        Hint melding
    }
    SetTimer HintSkjul, -30000
    KJORER := false
}

; Datoen Avtaler viser nå (ÅÅÅÅ-MM-DD), eller "" når Avtaler ikke er synlig
AvtalerDatoNaa() {
    hwnd := WinExist(K.vindu)
    doc := hwnd ? FinnPlanner(hwnd) : 0
    url := ""
    try url := doc ? doc.Value : ""
    return RegExMatch(url, "date=(\d{4}-\d{2}-\d{2})", &m) ? m[1] : ""
}

; v0.9.1 (funn 13, Cowork 30.10): spør før dagslisten leses, med datoen Avtaler
; viser og om det sendes. Svar: true for ja.
BekreftDagsliste() {
    dato := AvtalerDatoNaa()
    hva := dato != "" ? "Avtaler viser " DatoNavn(dato) "." : "Avtaler er ikke synlig; skriptet åpner Avtaler (" K.avtalerTastTekst "), som viser dagens dato."
    hva .= K.testdato != "" ? "`nTestdato i config.ini: " K.testdato "." : ""
    hva .= "`n`nSkriptet leser alle timene for datoen, åpner hver pasient og " (K.send ? "SENDER dagslisten til Skrift." : "skriver dagslisten til en fil (tørrkjøring, ingenting sendes).")
    hva .= "`nIkke bruk mus eller tastatur imens. " K.avbrytTekst " avbryter."
    return SkriftJa("Dagslisten til Skrift", hva, K.send ? "Les og send" : "Les (tørrkjøring)", "Avbryt")
}

Avbryt(*) {
    global AVBRUTT := true
    Logg("Avbryt-tast trykket")
}

Sjekk() {
    if AVBRUTT
        throw Error("Avbrutt med " K.avbrytTekst)
}

; -----------------------------------------------------------------------------
Kjor() {
    global PASIENT_APEN, SETTE_PASIENTER, WM_VERSJON, LISTEDATO
    SETTE_PASIENTER := Map()
    if K.testdato != "" && !GyldigDato(K.testdato)
        throw Error("[kjoring] testdato må være ÅÅÅÅ-MM-DD eller tom")
    hwnd := WinExist(K.vindu)
    if !hwnd
        throw Error("Fant ikke WebMed-vinduet (" K.vindu ")")
    pid := WinGetPID(hwnd)
    adv := []
    wmVer := ""
    try wmVer := FileGetVersion(WinGetProcessPath(hwnd))
    if wmVer = ""
        adv.Push("WebMed-versjonen kunne ikke leses fra programfilen")
    WM_VERSJON := wmVer
    Logg("WebMed-vindu funnet, versjon " wmVer ", AutoHotkey " A_AhkVersion ", skjerm " A_ScreenWidth "x" A_ScreenHeight " (DPI " A_ScreenDPI ")")
    Logg("Skjermer: " SkjermOversikt(hwnd))
    ; v0.5.1: WebMed maksimeres for kjøringen (på skjermen kalibreringen ble gjort
    ; på) og settes tilbake til plasseringen fra før når kjøringen er ferdig eller
    ; stopper. Plasseringen leses før Aktiver, som ellers gjenoppretter et minimert vindu.
    plassering := VinduForKjoring(hwnd, KalMal(), K.kalPos)
    try
        return KjorIWebMed(hwnd, pid, adv, wmVer)
    finally
        VinduTilbake(hwnd, plassering)
}

KjorIWebMed(hwnd, pid, adv, wmVer) {
    global PASIENT_APEN, LISTEDATO
    Aktiver(hwnd)
    ; v0.5: skjermpunktene gjelder bare for vinduet og skaleringen de ble målt med
    WinGetPos(, , &ww, &wh, hwnd)
    dpi := VinduDpi(hwnd)
    if (m := KalSjekk({vindu: K.kalVindu, dpi: K.kalDpi}, {vindu: ww "x" wh, dpi: dpi}, K.kalibrerTekst)) != ""
        throw Error(m)
    if dpi != A_ScreenDPI
        Logg("WebMed står på en skjerm med DPI " dpi " (hovedskjermen " A_ScreenDPI ")")
    Logg(K.kalVindu = "" ? "Ikke kalibrert; WebMed har samme vindu og skalering som koordinatene før v0.5 ble målt med" : "Kalibrert " K.kalDato " for WebMed " K.kalVindu " (DPI " K.kalDpi ")")
    SjekkVinduer(hwnd, pid, "start")
    doc := VisAvtaler(hwnd)
    ; Datoen som er valgt i Avtaler (fra adressen i tilgjengelighetslaget):
    ; i dag eller senere. En passert dato bare når den står som testdato.
    url := ""
    try url := doc.Value
    idag := LesListedato(url, FormatTime(, "yyyy-MM-dd"), K.testdato)
    LISTEDATO := idag
    Logg("Leser Avtaler for " idag " (" DatoNavn(idag) ")" (idag = FormatTime(, "yyyy-MM-dd") ? ", i dag" : ""))
    Hint "Skrift: leser Avtaler for " DatoNavn(idag) " … ikke bruk mus eller tastatur. " K.avbrytTekst " avbryter."
    if idag = K.testdato && StrCompare(idag, FormatTime(, "yyyy-MM-dd")) < 0
        adv.Push("Testkjøring: Avtaler for " idag " (passert dato, tillatt av testdato i config.ini)")
    if !InStr(url, "view=day") || !InStr(url, "viewType=list")
        throw Error("Avtaler må stå i dagsvisning som liste (testet slik). Bytt visning og prøv igjen.")
    timer := LesDagsliste(doc, adv)
    Logg("Dagsliste lest via UIA: " timer.Length " pasienttimer")
    if !timer.Length
        adv.Push("Ingen pasienttimer funnet i Avtaler")
    poster := []
    if timer.Length > K.maks {
        adv.Push("Bare de første " K.maks " timene er lest (maks_timer i config.ini)")
        timer.Length := K.maks
    }
    fil := K.eksempler "\dagsliste-" idag ".json"
    for i, t in timer {
        try {
            Sjekk()
            ; Hintet viser hvilken time som leses (det sto «leser Avtaler» hele kjøringen før)
            Hint "Skrift: leser time " i " av " timer.Length " (" Referanse(t) ") for " DatoNavn(idag) " … ikke bruk mus eller tastatur. " K.avbrytTekst " avbryter."
            tp := A_TickCount
            rec := ForberedPost(LesTime(hwnd, pid, t, i))
            poster.Push(rec)
            ref := rec.post["referanse"]
            Logg("Time " i " (" ref ") ferdig på " (A_TickCount - tp) " ms, " rec.post["advarsler"].Length " advarsel(er)"
                . (rec.feil.Length ? ", " rec.feil.Length " feil i posten" : "") (rec.innhold ? "" : ", ingenting å sende"))
            for a in rec.post["advarsler"]
                adv.Push("Time " i " (" ref "): " a)
            for f in rec.feil
                adv.Push("Time " i " (" ref "): KAN IKKE SENDES: " f)
            if !rec.innhold
                adv.Push("Time " i " (" ref "): posten sendes ikke (ingen av feltene Skrift tar imot er fylt)")
            Sleep K.pause
        } catch as e {
            adv.Push("Kjøringen stoppet ved time " i " (" Referanse(t) "): " e.Message)
            SkrivJson(fil, wmVer, idag, poster, adv, false)
            Logg("Delvis fil skrevet (" poster.Length " poster, ingenting sendes)")
            throw e
        }
    }
    ; v0.7.1 (30.10): tilbake til listedatoen etterpå. F3 viser dagens dato, og da
    ; ville neste trykk lese dagens ekte liste når testlisten står på en annen dag.
    try {
        VisAvtaler(hwnd)
        GaTilListedato(hwnd)
    }
    ; Bunken: alle poster med innhold. Én ugyldig post eller en bunke som ikke
    ; blir lik etter JSON-koding gir null sendte.
    gyldig := true, klare := []
    for r in poster {
        if r.feil.Length
            gyldig := false
        if r.innhold
            klare.Push(r)
    }
    kropp := BunkeJson(klare)
    for f in KontrollerBunke(kropp, klare) {
        adv.Push("KAN IKKE SENDES (bunken): " f)
        gyldig := false
    }
    ; v0.10.2 (Daniel 02.11): JSON-filen med pasientbakgrunnen skrives bare ved tørrkjøring
    ; (eller med [filer] json_ved_sending=1, for testene). Ved sending holdes alt i minnet.
    if !K.send || K.jsonVedSending
        SkrivJson(fil, wmVer, idag, poster, adv, true)
    else {
        fil := ""
        for a in adv
            Logg("advarsel: " a)
    }
    return {antall: poster.Length, fil: fil, poster: poster, klare: klare, kropp: kropp, gyldig: gyldig}
}

; -----------------------------------------------------------------------------
; Dagslisten (Avtaler = planner i WebView2, lesbar med UIA)
; -----------------------------------------------------------------------------
FinnPlanner(hwnd) {
    try {
        root := UIA.ElementFromHandle(hwnd)
        doc := root.ElementExist({Type: "Document", AutomationId: "RootWebArea"})
        if doc && InStr(doc.Value, "/planner")
            return doc
    }
    return 0
}

VisAvtaler(hwnd) {
    if doc := FinnPlanner(hwnd)
        return doc
    ; v0.6.0: WebMeds egen tast (F3, «Gå til Kalender») i stedet for klikk på menyen.
    ; Kommer ikke Avtaler innen 4 s, klikkes menyvalget som før.
    if K.avtalerTast != "" {
        Logg("Går til Avtaler med " K.avtalerTastTekst)
        Aktiver(hwnd)
        Send K.avtalerTast
        if doc := VentPaa(() => FinnPlanner(hwnd), 4000) {
            Sleep 400
            return doc
        }
        Logg("Avtaler kom ikke etter " K.avtalerTastTekst "; klikker menyvalget")
    } else
        Logg("Går til Avtaler via menyen")
    KlikkVindu(hwnd, K.pAvtaler)
    doc := VentPaa(() => FinnPlanner(hwnd), 8000)
    if !doc
        throw Error("Avtaler-visningen dukket ikke opp etter klikk på menyen (sjekk koordinaten avtaler_meny)")
    Sleep 400
    return doc
}

LesDagsliste(doc, adv) {
    ; vent til antall rader er stabilt (to like tellinger), maks 4 s
    rader := [], forrige := -1
    start := A_TickCount, slutt := start + 4000
    loop {
        rader := doc.FindElements({Type: "Button", ClassName: "slot", mm: 2})
        if (rader.Length = forrige && (rader.Length > 0 || A_TickCount > start + 2000)) || A_TickCount > slutt
            break
        forrige := rader.Length
        Sleep 300
    }
    timer := [], hoppet := 0
    for r in rader {
        t := LesRad(r)
        if t.id = "" || t.navn = "" || t.fdato = "" || !RegExMatch(t.fra, "^\d{1,2}[.:]\d{2}$") {
            hoppet++
            Logg("Rad hoppet over (ikke en pasienttime eller mangler felt): fra=" (RegExMatch(t.fra, "^\d{1,2}[.:]\d{2}$") ? t.fra : "?") ", id " (t.id = "" ? "mangler" : "ok") ", navn " (t.navn = "" ? "mangler" : "ok") ", fødselsdato " (t.fdato = "" ? "mangler" : "ok"))
            continue
        }
        timer.Push(t)
    }
    if hoppet
        adv.Push(hoppet " rad(er) i Avtaler uten pasient, klokkeslett eller fødselsdato ble hoppet over")
    return timer
}

LesRad(r) {
    t := {id: "", fra: "", varighet: "", type: "", navn: "", kommentar: "", fdato: "", lege: ""}
    try t.id := r.AutomationId
    tekster := []
    for c in r.Children {
        if c.Type = UIA.Type.Text {
            tekster.Push(Trim(c.Name))
            continue
        }
        cls := ""
        try cls := c.ClassName
        tekst := SamletTekst(c)
        if InStr(cls, "comment")
            t.kommentar := tekst
        else if InStr(cls, "birthdate")
            t.fdato := tekst
        else if InStr(cls, "doctor")
            t.lege := tekst
        else if InStr(cls, "created-by") || InStr(cls, "phone") || InStr(cls, "room") || InStr(cls, "resources")
            continue
        else if t.navn = ""
            t.navn := tekst
    }
    if tekster.Length >= 1
        t.fra := tekster[1]
    if tekster.Length >= 2
        t.varighet := tekster[2]
    if tekster.Length >= 3
        t.type := tekster[3]
    return t
}

SamletTekst(el) {
    s := ""
    for x in el.FindElements({Type: "Text"})
        s .= (s = "" ? "" : " ") Trim(x.Name)
    return Trim(s)
}

SokRad(hwnd, id) {
    if doc := FinnPlanner(hwnd)
        try return doc.ElementExist({AutomationId: id})
    return 0
}

; Velger listedatoen i månedskalenderen i Avtaler (knapper med navn som
; «søndag 25. oktober 2026», Invoke via UIA, ingen klikk) og venter til
; adressen viser datoen. Blar høyst 13 måneder.
GaTilListedato(hwnd) {
    doc := FinnPlanner(hwnd)
    if !doc
        throw Error("Avtaler er ikke synlig")
    url := ""
    try url := doc.Value
    if InStr(url, "date=" LISTEDATO)
        return doc
    navn := DatoNavn(LISTEDATO)
    vis := RegExMatch(url, "date=(\d{4}-\d{2}-\d{2})", &m) ? m[1] : FormatTime(, "yyyy-MM-dd")
    bla := StrCompare(LISTEDATO, vis) > 0 ? "Neste måned" : "Forrige måned"
    Logg("Avtaler viser en annen dato; velger listedatoen i kalenderen")
    loop 14 {
        Sjekk()
        if knapp := doc.ElementExist({Type: "Button", Name: navn}) {
            knapp.GetPattern(UIA.Pattern.Invoke).Invoke()
            doc := VentPaa(() => VisPaaDato(hwnd), 6000)
            if !doc
                throw Error("Avtaler gikk ikke til listedatoen " LISTEDATO " etter valg i kalenderen")
            Sleep 400
            return doc
        }
        if A_Index = 14 || !(b := doc.ElementExist({Type: "Button", Name: bla}))
            break
        b.GetPattern(UIA.Pattern.Invoke).Invoke()
        Sleep 300
        doc := FinnPlanner(hwnd)
        if !doc
            break
    }
    throw Error("Fant ikke listedatoen " LISTEDATO " i kalenderen i Avtaler")
}

VisPaaDato(hwnd) {
    if doc := FinnPlanner(hwnd) {
        url := ""
        try url := doc.Value
        if InStr(url, "date=" LISTEDATO)
            return doc
    }
    return 0
}

; «søndag 25. oktober 2026» (navnet på dagknappen i kalenderen i Avtaler)
DatoNavn(dato) {
    static dager := ["søndag", "mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lørdag"]
    static mnd := ["januar", "februar", "mars", "april", "mai", "juni", "juli", "august", "september", "oktober", "november", "desember"]
    return dager[Integer(FormatTime(StrReplace(dato, "-"), "WDay"))] " " Integer(SubStr(dato, 9, 2)) ". "
        . mnd[Integer(SubStr(dato, 6, 2))] " " SubStr(dato, 1, 4)
}

FinnKnapp(hwnd, navn) {
    if doc := FinnPlanner(hwnd)
        return doc.ElementExist({Type: "Button", Name: navn})
    return 0
}

; «Info om time» i «Velg kontakt» som Map: kolonneoverskrift -> verdi
VelgKontaktRad(hwnd) {
    m := Map()
    doc := FinnPlanner(hwnd)
    if !doc
        return m
    tab := doc.ElementExist({Type: "Table"})
    if !tab
        return m
    rader := []
    for c in tab.Children
        if c.Type = UIA.Type.DataItem
            rader.Push(c)
    if rader.Length != 2
        return m
    hode := rader[1].Children, verdi := rader[2].Children
    for i, h in hode
        if i <= verdi.Length
            m[Trim(h.Name)] := Trim(verdi[i].Name)
    return m
}

; -----------------------------------------------------------------------------
; Én time
; -----------------------------------------------------------------------------
LesTime(hwnd, pid, t, nr) {
    adv := []
    ref := Referanse(t)
    Logg("Time " nr ": " ref " åpnes")
    ApneTime(hwnd, pid, t)

    ; v0.11.0: bare feltene som er valgt i [innhold] hentes (en tom kopi for resten,
    ; så pasientkontrollen og posten er som før)
    tidl := K.innTidl ? KopierFelt(hwnd, "!s", "Tidligere sykdommer", adv) : TomKopi()
    fam := K.innFam ? KopierFelt(hwnd, "!f", "Familie/Sosialt", adv) : TomKopi()
    Logg("Tidligere sykdommer: " (K.innTidl ? KopiLogg(tidl) : "ikke valgt") "; familie/sosialt: " (K.innFam ? KopiLogg(fam) : "ikke valgt"))
    if tidl.tekst != "" && tidl.tekst = fam.tekst
        adv.Push("Tidligere sykdommer og familie/sosialt ga samme tekst; sjekk at Alt+S og Alt+F flytter fokus")
    ; Første pasient-GUID-kontroll før Ctrl+Alt+L: feil her stopper før notatet røres
    idFelt := KontrollerPasientId(t, nr, [["Tidligere sykdommer", tidl], ["Familie/Sosialt", fam]], false)
    ; v0.4: siste konsultasjon før notatet røres (bare klikk i Løpende journal)
    kons := {kopi: TomKopi(), tekst: ""}
    if K.jPa
        kons := LesSisteKonsultasjon(hwnd, pid, idFelt, adv)
    lib := K.innLib ? LesLegemiddelliste(hwnd, pid, adv) : {kopi: TomKopi(), liste: ""}
    Logg("Legemiddelliste: " (K.innLib ? KopiLogg(lib.kopi) (lib.liste == lib.kopi.tekst ? "" : ", brukt i posten: " StrLen(lib.liste) " tegn") : "ikke valgt"))

    ; Pasient-GUID i alle tre. Notatet er tomt her (eller aldri endret),
    ; så et stopp lar pasienten stå åpen uten at noe er skrevet i journalen.
    pasientId := KontrollerPasientId(t, nr, [["Tidligere sykdommer", tidl], ["Familie/Sosialt", fam], ["Legemiddellisten", lib.kopi], ["Siste konsultasjon", kons.kopi]])

    LukkTime(hwnd, pid, t, adv)

    return ByggPost(t, ref, tidl.tekst, fam.tekst, lib.liste, pasientId, adv, kons.tekst)
}

; Åpner timen fra Avtaler: dobbeltklikk, kontroll i «Velg kontakt», «Ingen
; pasientkontakt», og forhåndskontrollen i «Lukk pasienter» (v0.6.0: skilt ut fra
; LesTime, så innsjekken i Lib\Innsjekk.ahk åpner timen på nøyaktig samme måte).
ApneTime(hwnd, pid, t) {
    global PASIENT_APEN
    ref := Referanse(t)
    doc := VisAvtaler(hwnd)
    ; Viser Avtaler en annen dato etter menyklikket, velges listedatoen i
    ; kalenderen (UIA). Raden må tilhøre listedatoen.
    doc := GaTilListedato(hwnd)
    url := ""
    try url := doc.Value
    if !InStr(url, "date=" LISTEDATO)
        throw Error("Avtaler viser ikke listedatoen " LISTEDATO " når timen skal åpnes")
    ; Radene kan komme litt etter selve visningen: vent inntil 5 s på timen
    rad := VentPaa(() => SokRad(hwnd, t.id), 5000)
    if !rad
        throw Error("Fant ikke timen igjen i Avtaler")
    rn := ""
    try rn := rad.Name
    if !(InStr(rn, t.navn, true) && InStr(rn, t.fdato, true))
        throw Error("Timen i Avtaler har endret seg siden listen ble lest")
    try rad.GetPattern(UIA.Pattern.ScrollItem).ScrollIntoView()
    Sleep 300
    br := rad.BoundingRectangle
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    s := KalSkala(VinduDpi(hwnd))
    x := br.l + Round(25 * s), y := (br.t + br.b) // 2
    if br.r <= br.l || br.b <= br.t || x < wx || x > wx + ww || y < wy + Round(100 * s) || y > wy + wh
        throw Error("Timen er ikke synlig på skjermen etter rulling")
    Aktiver(hwnd)
    CoordMode "Mouse", "Screen"
    MouseClick "Left", x, y, 2
    ; Pekeren bort fra der journalen åpner (ellers hoverboks over CAVE-feltet)
    MouseMove wx + ww // 2, wy + 12, 0
    knapp := VentPaa(() => FinnKnapp(hwnd, "Ingen pasientkontakt"), 6000)
    if !knapp {
        SjekkVinduer(hwnd, pid, "etter dobbeltklikk")
        throw Error("«Velg kontakt» kom ikke")
    }
    info := VelgKontaktRad(hwnd)
    for kol, forventet in Map("Fra", t.fra, "Pasientnavn", t.navn, "F.Nummer", t.fdato)
        if !info.Has(kol) || !(info[kol] == forventet)
            throw Error("«Velg kontakt» stemmer ikke med timen (kolonnen " kol ")")
    Logg("Velg kontakt: klokkeslett, navn og fødselsdato stemmer; velger «Ingen pasientkontakt»")
    knapp.GetPattern(UIA.Pattern.Invoke).Invoke()
    PASIENT_APEN := ref
    if !VentPaa(() => !FinnPlanner(hwnd), 8000)
        throw Error("Journalen åpnet seg ikke")
    Sleep K.ventJournal
    SjekkVinduer(hwnd, pid, "journal åpnet")

    if K.kontroll {
        dlg := ApneLukkDialog(hwnd, pid)
        navn := LukkDialogNavn(dlg)
        if !(navn.Length = 1 && SammeNavn(navn[1], t.navn)) {
            TrykkKnapp(dlg, "Avbryt")
            throw Error("Forhåndskontroll: «Lukk pasienter» viser " navn.Length " pasient(er), ikke bare forventet pasient")
        }
        TrykkKnapp(dlg, "Avbryt")
        if !VentPaa(() => !FinnLukkDialog(pid, hwnd), 3000)
            throw Error("«Lukk pasienter» forsvant ikke etter Avbryt")
        Sleep 200
        Logg("Forhåndskontroll ok: riktig pasient er åpen")
    }
}

; «Lagre og lukk» bare med bekreftet tomt notat og ny navnekontroll (v0.6.0:
; skilt ut fra LesTime). Stopper og lar pasienten stå åpen ved alt uventet.
LukkTime(hwnd, pid, t, adv) {
    global PASIENT_APEN
    ; «Lagre og lukk» bare med bekreftet tomt notat
    if !NotatErTomt(hwnd)
        throw Error("NOTATFELTET ER IKKE TOMT før lukking. Pasienten er ikke lukket.")
    ; Lukket vinduskontrollen en meldingsboks, bekreftes notatet på nytt
    if SjekkVinduer(hwnd, pid, "før lukking", adv) && !NotatErTomt(hwnd)
        throw Error("NOTATFELTET ER IKKE TOMT etter at en meldingsboks ble lukket. Pasienten er ikke lukket.")
    dlg := ApneLukkDialog(hwnd, pid, adv)
    navn := LukkDialogNavn(dlg)
    if !(navn.Length = 1 && SammeNavn(navn[1], t.navn)) {
        TrykkKnapp(dlg, "Avbryt")
        throw Error("«Lukk pasienter» viser feil pasient; dataene for timen er forkastet")
    }
    TrykkKnapp(dlg, "Lagre og lukk")
    if !VentPaa(() => !FinnLukkDialog(pid, hwnd), 5000)
        throw Error("«Lukk pasienter» forsvant ikke etter «Lagre og lukk»")
    PASIENT_APEN := ""
    Sleep 300
    SjekkVinduer(hwnd, pid, "etter lukking")
    Logg("Pasienten er lukket")
}

; Alle felt med tekst må ha gyldig PatientText med lik tekst, og alle
; pasient-GUID-ene må være like. Felt uten tekst (tomt felt, legemiddelliste
; som ikke kunne hentes) har ingenting å sikre og teller bare når de har en
; gyldig PatientText. endelig = false: kontroll uten å huske GUID-en.
KontrollerPasientId(t, nr, felt, endelig := true) {
    global SETTE_PASIENTER
    ider := Map(), antall := 0
    for x in felt {
        navn := x[1], kp := x[2]
        if !kp.endret
            continue
        if Trim(kp.tekst, " `t`r`n") = "" {
            if kp.pt.funnet && kp.pt.feil = "" && kp.pt.id != "" {
                ider[kp.pt.id] := true
                antall++
            }
            continue
        }
        if !kp.pt.funnet
            throw Error(navn ": teksten kom uten PatientText, så den er ikke bekreftet fra WebMeds journal. Dataene for timen er forkastet.")
        if kp.pt.feil != ""
            throw Error(navn ": PatientText kunne ikke brukes (" kp.pt.feil "). Dataene for timen er forkastet.")
        ider[kp.pt.id] := true
        antall++
    }
    if ider.Count > 1
        throw Error("Pasient-GUID-en er ikke lik i feltene (" ider.Count " ulike i " antall " felt). Fokus kan ha byttet pasient; dataene for timen er forkastet.")
    if !ider.Count {
        if endelig
            Logg("Ingen felt med tekst; pasient-GUID kunne ikke kontrolleres")
        return ""
    }
    for id in ider
        guid := id
    nokkel := t.navn "|" t.fdato
    if SETTE_PASIENTER.Has(guid) {
        tidligere := SETTE_PASIENTER[guid]
        if !(tidligere.nokkel == nokkel)
            throw Error("Pasient-GUID-en er den samme som ved time " tidligere.nr ", men navn eller fødselsdato er ulikt. Dataene for timen er forkastet.")
        if endelig
            Logg("Samme pasient-GUID som time " tidligere.nr " (samme navn og fødselsdato)")
    } else if endelig
        SETTE_PASIENTER[guid] := {nokkel: nokkel, nr: nr}
    if endelig
        Logg("Pasient-GUID lik i " antall " felt")
    return guid
}

; -----------------------------------------------------------------------------
; Journal (WPF, skjult for UIA): hurtigtaster og utklippstavle
; -----------------------------------------------------------------------------
KopierFelt(hwnd, tast, felt, adv) {
    Aktiver(hwnd)
    Send tast
    Sleep 200
    kp := KopierPasientTekst()
    Send "^{Home}"
    Sleep 50
    if !kp.endret
        adv.Push(felt ": ingenting ble kopiert innen " Round(K.utklipp / 1000, 1) " s (tomt felt eller fokus et annet sted)")
    return kp
}

TomKopi() => ({tekst: "", endret: false, pt: {funnet: false, id: "", tekst: "", feil: ""}})

; Ctrl+A, Ctrl+C og PatientText fra samme kopi. Er PatientText gyldig, er
; tekst hentet derfra (lik den kopierte teksten, kontrollert i LesPatientText).
; lesTom = false: PatientText leses bare når kopien har tekst.
KopierPasientTekst(lesTom := true) {
    kp := TomKopi()
    kp.tekst := KopierMarkert(&endret)
    kp.endret := endret
    if endret && (lesTom || Trim(kp.tekst, " `t`r`n") != "") {
        ; Kjører også mens legemiddellisten står i notatet: ingen unntak herfra,
        ; en feil blir et stopp i KontrollerPasientId etter angringen.
        try
            kp.pt := LesPatientText(kp.tekst)
        catch as e
            kp.pt := {funnet: true, id: "", tekst: "", feil: "intern feil ved lesing (" e.Message ")"}
        if kp.pt.id != ""
            kp.tekst := kp.pt.tekst
    }
    return kp
}

KopiLogg(kp) {
    if !kp.endret
        return "ingen kopi"
    s := StrLen(kp.tekst) " tegn"
    if !kp.pt.funnet
        return s ", uten PatientText"
    return s (kp.pt.feil = "" ? ", PatientText ok" : ", PatientText-feil: " kp.pt.feil)
}

; Ctrl+A, Ctrl+C. endret = utklippstavlen ble faktisk endret (også til tom tekst)
KopierMarkert(&endret := 0) {
    A_Clipboard := SENTINEL
    Sleep 30
    Send "^a"
    Sleep 40
    Send "^c"
    slutt := A_TickCount + K.utklipp
    while A_TickCount < slutt {
        if A_Clipboard != SENTINEL {
            endret := true
            return A_Clipboard
        }
        Sleep 30
    }
    endret := false
    return ""
}

; Klikker i hovednotatet og kopierer alt. Tomt notat gir en tom kopi (sjekket).
; Kom ingen kopi, prøves det én gang til; ellers stopper skriptet.
NotatErTomt(hwnd) {
    loop 2 {
        KlikkVindu(hwnd, K.pNotat)
        Sleep 200
        s := KopierMarkert(&endret)
        Send "^{End}"
        if endret
            return Trim(s, " `t`r`n") = ""
        Logg("Notatfeltet ga ingen kopi; prøver igjen")
    }
    throw Error("Kunne ikke bekrefte om notatfeltet er tomt (ingen kopi). Sjekk koordinaten notatfelt.")
}

; Svar: {kopi, liste}. kopi er kopien av notatet (med PatientText), liste er
; teksten som skal i posten ("" når listen mangler eller er «Ingen registrert»).
LesLegemiddelliste(hwnd, pid, adv) {
    if !NotatErTomt(hwnd)
        throw Error("Notatfeltet har tekst fra før (kladd). Legemiddellisten er ikke hentet, notatet er ikke endret og pasienten er ikke lukket.")
    KlikkVindu(hwnd, K.pNotat)
    Sleep 100
    Send "^!l"
    kp := TomKopi()
    slutt := A_TickCount + K.ventLib
    loop {
        Sleep 250
        if mb := WinExist("ahk_class #32770 ahk_pid " pid) {
            mt := ""
            try mt := WinGetText(mb)
            if InStr(mt, "Lib/Cave ikke lest inn") {
                if !LukkMeldingsboks(mb)
                    throw Error("Meldingsboksen «Lib/Cave ikke lest inn» lot seg ikke lukke")
                adv.Push("Legemiddellisten kunne ikke hentes (WebMed: «Lib/Cave ikke lest inn. Ukjent feil.»)")
                Logg("Meldingsboks «Lib/Cave ikke lest inn» lukket med OK")
                return {kopi: TomKopi(), liste: ""}
            }
            throw Error("Uventet meldingsboks under henting av legemiddelliste (" StrLen(mt) " tegn, les den i WebMed). Pasienten er ikke lukket.")
        }
        if SjekkVinduer(hwnd, pid, "henting av legemiddelliste", adv)
            return {kopi: TomKopi(), liste: ""}
        Aktiver(hwnd)
        kp := KopierPasientTekst(false)
        if Trim(kp.tekst, " `t`r`n") != ""
            break
        if A_TickCount > slutt
            throw Error("Legemiddellisten kom ikke innen " Round(K.ventLib / 1000) " s. Pasienten er ikke lukket; sjekk notatfeltet.")
    }
    Send "^z"
    Sleep 250
    if !NotatErTomt(hwnd) {
        Send "^z"
        Sleep 250
        if !NotatErTomt(hwnd)
            throw Error("NOTATFELTET ER IKKE TOMT etter angring. Pasienten er ikke lukket. Tøm notatet selv før du lukker pasienten.")
    }
    Logg("Legemiddelliste kopiert og innsettingen angret; notatfeltet er tomt")
    if RegExMatch(kp.tekst, "i)^\s*LIB:\s*Ingen\s+registrert\.?\s*$") {
        adv.Push("Ingen legemidler registrert (LIB: Ingen Registrert)")
        return {kopi: kp, liste: ""}
    }
    return {kopi: kp, liste: kp.tekst}
}

; -----------------------------------------------------------------------------
; Siste konsultasjon fra Løpende journal (v0.4, Lib\Journal.ahk)
; -----------------------------------------------------------------------------
; Svar: {kopi, tekst}. kopi er kopien av oppføringen (med PatientText) til
; GUID-kontrollen; tekst er avsnittet til bakgrunn ("" når ingen er funnet).
; Feiler søket, blir det en advarsel og timen leses videre. Annen pasient-GUID
; i en oppføring stopper kjøringen.
LesSisteKonsultasjon(hwnd, pid, idFelt, adv) {
    Aktiver(hwnd)
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    o := {skannX: wx + K.jSkann, klikkX: wx + K.jKlikk, y0: wy + K.jTopp, y1: wy + K.jBunn
        , farge: K.jFarge, typer: K.jTyper, maks: K.jMaks, maksSider: 15, rull: K.jRull, ventRull: 300
        , timeout: K.utklipp, sentinel: SENTINEL, guid: idFelt, musBort: {x: wx + ww // 2, y: wy + 12}
        , logg: Logg, sjekk: Sjekk, halv: Round(100 * KalSkala(VinduDpi(hwnd))), inn: Round(4 * KalSkala(VinduDpi(hwnd)))}
    ; Filteret «Kontakt» settes og blir stående: WebMed nullstiller det neste gang
    ; journalen åpnes (Daniel 25.10), og pasienten lukkes etterpå uansett
    ; Før filteret: har listen overskrifter (koordinatene stemmer) eller er den tom?
    MouseMove o.musBort.x, o.musBort.y, 0
    p0 := JournalStabil(o.skannX, o.y0, o.y1, o.farge)
    lest0 := JournalOverskrifter(p0, o.y0, o.farge).Length > 0 || JournalHvit(p0)
    o.lesbar := lest0   ; v0.10.3 (rapportfunn 3): ingen koordinatråd når listen var lesbar før filteret
    if K.jFilter {
        bx := wx + K.pKontakt.x, by := wy + K.pKontakt.y
        if !JournalBoksAvkrysset(bx, by) {
            if JournalSettFilter(bx, by, true) {
                Logg("Løpende journal: filteret «Kontakt» satt på")
                if !JournalVentPaaOverskrifter(o.skannX, o.y0, o.y1, o.farge)
                    Logg("Løpende journal: ingen overskrift synlig 8 s etter at filteret ble satt")
                if !JournalTilToppen(o)
                    Logg("Løpende journal: fikk ikke bekreftet at listen står øverst")
            } else
                Logg("Løpende journal: filteret «Kontakt» lot seg ikke sette; søker i alle oppføringer")
        }
    }
    try
        r := FinnSisteKonsultasjon(o)
    finally
        MouseMove wx + ww // 2, wy + 12, 0
    SjekkVinduer(hwnd, pid, "løpende journal", adv)
    if r.funnet {
        bort := r.legeNavn ? ", legens navn byttet med [lege] " r.legeNavn " gang(er)" : ""
        Logg("Siste konsultasjon funnet etter " r.sjekket " oppføring(er): " StrLen(r.kropp) " tegn, PatientText ok" bort)
        ; Legens navn er fjernet (JournalKropp); typen står med når den ikke er «Konsultasjon»
        tittel := "Siste konsultasjon " r.hode.visDato (StrLower(r.hode.type) == "konsultasjon" ? "" : " – " r.hode.type) ":`n"
        return {kopi: r.kp, tekst: tittel (Trim(r.kropp, " `t`n") = "" ? "(ingen tekst i oppføringen)`n" : Linjer(r.kropp))}
    }
    ; v0.9.0: «ingen oppføringer» bare når søket faktisk nådde slutten (tom liste);
    ; et annet stopp med 0 sjekket (f.eks. «ser ikke ut som en overskrift») skal
    ; stå i loggen og gi advarsel, ikke gjemmes bak lest0 (sett 31.10 21:34)
    ingen := r.tom || (r.sjekket = 0 && lest0 && r.stopp = "slutten av Løpende journal")
    Logg("Siste konsultasjon ikke funnet: " (ingen ? "ingen oppføringer i Løpende journal" (K.jFilter ? " med filteret «Kontakt»" : "") : r.stopp) " (" r.sjekket " oppføring(er) sjekket" (r.uten ? ", " r.uten " uten kopi" : "") ")")
    ; Ingen overskrifter med filteret, men listen var lesbar uten: ingen kontakter,
    ; ingen advarsel. Til Skrift ellers bare en kort advarsel; grunnen står i loggen.
    if !ingen
        adv.Push("Siste konsultasjon kunne ikke hentes fra Løpende journal")
    return {kopi: TomKopi(), tekst: ""}
}

; -----------------------------------------------------------------------------
; Kalibrering (v0.5, Lib\Kalibrering.ahk): skjermpunktene måles hos brukeren
; -----------------------------------------------------------------------------
; Brukeren peker på fem ting hos en fiktiv testpasient og trykker merketasten
; (F8); ingenting klikkes mens det pekes. Så prøver skriptet punktene: boksen
; «Kontakt» av og på igjen, en kopi av en overskrift (PatientText og
; overskriftslinjen) og klikket på «Avtaler». Først når alt virker, skrives
; punktene til config.ini. Loggen får mål og antall, aldri tekst fra journalen.
global KAL_TAST := ""

KalTrykk(v, *) {
    global KAL_TAST := v
}

; v0.11.2 (SUP-2026-11-08-A): svaret er true når kalibreringen er lagret. Stopper
; den, vises grunnen i en boks som står til brukeren lukker den (med «Prøv
; igjen» og «Åpne loggen»), ikke bare i hintet som forsvinner etter 30 s, og
; grunnen huskes til meldingen «ikke kalibrert» (KAL_SISTE_STOPP).
Kalibrer(*) {
    loop {
        r := KalibrerEn()
        if r.ok || r.opptatt
            return r.ok
        if !KalStoppBoks(r.feil)
            return false
    }
}

; Tastene som er satt i config.ini (for KalMerkAlt)
KalTaster() => [K.merk, K.hurtigtast, K.avbryt, K.kalibrer, K.tastLmg, K.tastLimInn, K.tastNyInnsjekk, K.tastRing, K.tastVideo, K.tastMeny, K.tastMenyMus]

; Boksen etter en stoppet kalibrering. Svar: true når brukeren vil prøve igjen.
KalStoppBoks(feil) {
    alt := KalMerkAlt(KalTaster())
    t := feil "`n`nIngenting er endret i config.ini, så skriptet er ikke kalibrert ennå. "
        . KalStoppRaad(feil, K.merkTekst, alt = "" ? "" : TastTekst(alt))
        . "`n`nGrunnen står også i loggen. Stopper det igjen, send loggen for i dag til kontakt@skrift.md (den har klokkeslett, mål og statuskoder, aldri navn eller journaltekst)."
    loop {
        v := SkriftBoks("Kalibreringen stoppet", t, Map("ok", "Prøv igjen", "avbryt", "Lukk", "logg", "Åpne loggen"), "stopp", 640)
        if v != "logg"
            return v = "ok"
        ApneFil(K.logg "\" FormatTime(, "yyyy-MM-dd") ".txt")
    }
}

; Én kalibrering. Svar: {ok, feil, opptatt}
KalibrerEn() {
    global KJORER, AVBRUTT, KAL_SISTE_STOPP
    if KJORER
        return {ok: false, feil: "", opptatt: true}
    KJORER := true, AVBRUTT := false
    DirCreate K.logg
    lagret := ClipboardAll()
    plassering := ""
    alt := KalMerkAlt(KalTaster())
    svar := {ok: false, feil: "", opptatt: false}
    try {
        Hotkey K.merk, KalTrykk.Bind("merk"), "On"
        if alt != ""
            try Hotkey alt, KalTrykk.Bind("merk"), "On"
        Hotkey "Esc", KalTrykk.Bind("avbryt"), "On"
        Hint KalibrerSteg(&plassering)
        svar.ok := true
        KAL_SISTE_STOPP := ""
    } catch as e {
        svar.feil := e.Message
        KAL_SISTE_STOPP := FormatTime(, "HH:mm") ": " e.Message
        Logg("Kalibrering STOPPET: " e.Message)
        Hint "Skrift: kalibreringen STOPPET`n" e.Message "`nIngenting er endret i config.ini."
    } finally {
        try Hotkey K.merk, "Off"
        if alt != ""
            try Hotkey alt, "Off"
        try Hotkey "Esc", "Off"
        if IsObject(plassering) && (hw := WinExist(K.vindu))
            VinduTilbake(hw, plassering)
        A_Clipboard := lagret
        lagret := ""
        SetTimer HintSkjul, -30000
        KJORER := false
    }
    return svar
}

; Venter på merketasten eller Esc. Svar: {x, y} i vinduet.
KalPek(hwnd, pid, nr, tekst) {
    global KAL_TAST
    loop {
        KAL_TAST := ""
        alt := KalMerkAlt(KalTaster())
        Hint "Skrift: kalibrering, punkt " nr " av 5`n" tekst "`nPek (ikke klikk) og trykk " KalMerkHint(K.merk, K.merkTekst, alt = "" ? "" : TastTekst(alt)) ". Esc avbryter."
        slutt := A_TickCount + 120000
        while KAL_TAST = "" && A_TickCount < slutt
            Sleep 50
        if KAL_TAST = ""
            throw Error("Avbrutt: ingen tast på to minutter")
        if KAL_TAST = "avbryt"
            throw Error("Avbrutt med Esc")
        CoordMode "Mouse", "Screen"
        MouseGetPos &mx, &my, &mw
        WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        iWebMed := false
        try iWebMed := mw = hwnd || WinGetPID(mw) = pid || VinduSkjult(mw)
        if iWebMed && mx >= wx && mx < wx + ww && my >= wy && my < wy + wh
            return {x: mx - wx, y: my - wy}
        kl := ""
        try kl := WinGetClass(mw) " / " WinGetProcessName(mw) ", stil " Format("{:X}/{:X}", WinGetStyle(mw), WinGetExStyle(mw)) ", minmax " WinGetMinMax(mw)
        Logg("Kalibrering: punkt " nr " avvist, pekeren sto over " (kl != "" ? "«" kl "»" : "ingen kjent vindu") " ved " (mx - wx) "," (my - wy))
        Hint "Skrift: pekeren sto ikke i WebMed-vinduet. Prøv igjen."
        Sleep 1500
    }
}

KalibrerSteg(&plassering) {
    global K
    hwnd := WinExist(K.vindu)
    if !hwnd
        throw Error("Fant ikke WebMed-vinduet (" K.vindu ")")
    pid := WinGetPID(hwnd)
    ; v0.5.1: står WebMed ikke maksimert, maksimeres det for kalibreringen og
    ; settes tilbake etterpå (Kalibrer). Punktene måles alltid maksimert.
    plassering := VinduForKjoring(hwnd, "", "")
    Aktiver(hwnd)
    if WinGetMinMax(hwnd) != 1
        throw Error("WebMed lot seg ikke maksimere.")
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    dpi := VinduDpi(hwnd)
    s := KalSkala(dpi)
    Logg("=== Kalibrering v" SKRIPT_VERSJON ": WebMed " ww "x" wh ", skjerm " A_ScreenWidth "x" A_ScreenHeight " (DPI " dpi ") ===")
    Logg("Skjermer: " SkjermOversikt(hwnd) "; merketast " K.merkTekst)
    p := {}
    p.avtaler := KalPek(hwnd, pid, 1, (IsObject(plassering) ? "WebMed er maksimert for kalibreringen og settes tilbake etterpå.`n" : "") "Åpne en fiktiv testpasient som har minst én oppføring i Løpende journal.`nPek på menyvalget «Avtaler» øverst i WebMed.")
    p.notat := KalPek(hwnd, pid, 2, "Pek midt i notatfeltet (Dagens).")
    p.kontakt := KalPek(hwnd, pid, 3, "Pek midt på avkrysningsboksen «Kontakt» i filteret over Løpende journal.")
    p.hode := KalPek(hwnd, pid, 4, "Pek midt på den øverste grå overskriften i Løpende journal (ikke på ⋮ til høyre).")
    p.bunn := KalPek(hwnd, pid, 5, "Pek nederst i Løpende journal, rett over kanten av listen.")
    WinGetPos(&x2, &y2, &w2, &h2, hwnd)
    if x2 != wx || y2 != wy || w2 != ww || h2 != wh
        throw Error("WebMed-vinduet ble flyttet eller endret størrelse under kalibreringen")
    Hint "Skrift: kalibrering, måler og prøver punktene … ikke bruk mus eller tastatur."
    Aktiver(hwnd)
    ; Pekeren bort, så ingen overskrift er markert av pekeren når fargene leses
    bort := {x: wx + ww // 2, y: wy + Round(12 * s)}
    MouseMove bort.x, bort.y, 0
    Sleep 400
    rad := KalOverskriftRad(JournalRute(wx, wy + p.hode.y, ww, 1), p.hode.x, s)
    if !IsObject(rad)
        throw Error(rad)
    b := KalBeregn(p, rad, wh, s)
    if !IsObject(b)
        throw Error(b)
    sk := KalVelgSkann((x) => JournalRute(wx + x, wy, 1, wh), rad.venstre, rad.hoyre, p.hode.y, b.y0, b.y1, rad.farge, s)
    if !IsObject(sk)
        throw Error(sk)
    Logg("Kalibrering: overskrift " (rad.hoyre - rad.venstre + 1) "x" (sk.b - sk.t + 1) " px, " sk.hoder.Length " overskrift(er) synlige, liste " (b.y1 - b.y0) " px, " b.rull " hjulhakk per side")
    ; 1. Boksen «Kontakt»: av og på igjen (eller omvendt); filteret står som før
    ; v0.9.0: punktet flyttes til midten av rammen når den finnes (et punkt 3–4 px
    ; fra midten ga feil lesing av boksen ved 100 %)
    bf := JournalBoksFinn(wx + p.kontakt.x, wy + p.kontakt.y)
    if bf {
        Logg("Kalibrering: boksen «Kontakt» er " (bf.x1 - bf.x0 + 1) "x" (bf.y1 - bf.y0 + 1) " px; punktet flyttet " (bf.x - wx - p.kontakt.x) "," (bf.y - wy - p.kontakt.y) " px til midten")
        p.kontakt := {x: bf.x - wx, y: bf.y - wy}
    } else
        Logg("Kalibrering: fant ingen ramme rundt punkt 3; bruker punktet som det er")
    bx := wx + p.kontakt.x, by := wy + p.kontakt.y
    loop 2 {
        tidligere := JournalBoksAvkrysset(bx, by)
        m0 := JournalBoksMorke(bx, by)
        if !JournalSettFilter(bx, by, !tidligere) {
            MouseMove bort.x, bort.y, 0
            Sleep 300
            Logg("Kalibrering: boksen «Kontakt» ved " p.kontakt.x "," p.kontakt.y " (vindus-x/y): " m0 " mørke piksler før klikket, " JournalBoksMorke(bx, by) " etter (uten pekeren over)")
            throw Error("Boksen «Kontakt» (punkt 3) reagerte ikke på klikk. Pek midt på avkrysningsboksen.")
        }
        MouseMove bort.x, bort.y, 0
    }
    Logg("Kalibrering: boksen «Kontakt» virker")
    ; v0.8.0: listen lastes på nytt etter filterendringen (hvit et øyeblikk)
    if !JournalVentPaaOverskrifter(wx + sk.x, wy + b.y0, wy + b.y1, rad.farge)
        throw Error("Løpende journal viste ingen overskrift igjen 8 s etter at boksen «Kontakt» ble prøvd.")
    ; 2. En kopi av en overskrift med gyldig PatientText og overskriftslinje
    prof := JournalStabil(wx + sk.x, wy + b.y0, wy + b.y1, rad.farge)
    hoder := JournalOverskrifter(prof, wy + b.y0, rad.farge)
    ok := false
    for i, h in hoder {
        if i > 3
            break
        kp := JournalKopier(wx + b.klikkX, (h.t + h.b) // 2, {timeout: K.utklipp, sentinel: SENTINEL})
        MouseMove bort.x, bort.y, 0
        if kp.endret && kp.pt.funnet && kp.pt.feil = "" && kp.pt.id != "" && IsObject(JournalOverskrift(kp.tekst))
            ok := true
        kp := ""
        if ok
            break
    }
    if !ok
        throw Error("Klikk på overskriftene ga ingen gyldig kopi med pasient-ID (" hoder.Length " overskrift(er) funnet). Pek midt på den grå overskriften (punkt 4).")
    Logg("Kalibrering: kopi av en overskrift med PatientText virker")
    SjekkVinduer(hwnd, pid, "kalibrering")
    ; 3. «Avtaler»
    if !FinnPlanner(hwnd) {
        KlikkVindu(hwnd, p.avtaler)
        if !VentPaa(() => FinnPlanner(hwnd), 8000)
            throw Error("Klikket på «Avtaler» (punkt 1) åpnet ikke Avtaler.")
    }
    Logg("Kalibrering: «Avtaler» virker")
    IniSettFlere(KONFIG, {
        koordinater: [["avtaler_meny", p.avtaler.x "," p.avtaler.y], ["notatfelt", p.notat.x "," p.notat.y]
            , ["journal_skann_x", sk.x], ["journal_klikk_x", b.klikkX], ["journal_y", b.y0 "," b.y1]
            , ["journal_kontaktfilter", p.kontakt.x "," p.kontakt.y], ["journal_farge", Format("{:06X}", rad.farge)]],
        journal: [["rull_hakk", b.rull]],
        kalibrering: [["dato", FormatTime(, "yyyy-MM-dd HH:mm")], ["vindu", ww "x" wh], ["dpi", dpi]
            , ["posisjon", wx "," wy], ["skjerm", A_ScreenWidth "x" A_ScreenHeight]]
    }, {kalibrering: "Skrevet av kalibreringen (" K.kalibrerTekst "). Skriptet stopper når WebMed-vinduet eller`nskaleringen er annerledes enn her; kalibrer da på nytt."})
    K := LesKonfig()
    Logg("Kalibrering lagret i config.ini (" ww "x" wh ", DPI " dpi ")")
    return "Skrift: kalibrert for WebMed " ww "x" wh " (" Round(s * 100) " %).`nNotatfeltet prøves ved neste kjøring. Kjør en tørrkjøring (" K.hurtigtastTekst ") med fiktive pasienter før du sender."
}

; Lukker en kjent informasjonsboks (bare OK-knapp). ControlClick alene virket
; ikke hver gang, derfor: vent til boksen er klar, prøv OK, så Enter til boksen.
LukkMeldingsboks(mb) {
    Sleep 300
    loop 3 {
        try ControlClick "Button1", "ahk_id " mb
        if WinWaitClose("ahk_id " mb, , 1)
            return true
        try {
            WinActivate "ahk_id " mb
            if WinWaitActive("ahk_id " mb, , 1)
                Send "{Enter}"
        }
        if WinWaitClose("ahk_id " mb, , 1)
            return true
    }
    return false
}

; -----------------------------------------------------------------------------
; «Lukk pasienter» (eget WPF-vindu, lesbart med UIA)
; -----------------------------------------------------------------------------
ApneLukkDialog(hwnd, pid, adv := 0) {
    LukkPasientTast(hwnd)
    dlg := VentPaa(() => FinnLukkDialog(pid, hwnd), 2500)
    if !dlg {
        ; Første klikk etter en meldingsboks kan bare aktivere vinduet; prøv én gang til
        Logg("«Lukk pasienter» kom ikke; prøver én gang til")
        SjekkVinduer(hwnd, pid, "før nytt lukkeklikk", adv)
        LukkPasientTast(hwnd)
        dlg := VentPaa(() => FinnLukkDialog(pid, hwnd), 3000)
    }
    if !dlg
        throw Error("«Lukk pasienter» kom ikke (" (K.lukkTast != "" ? K.lukkTastTekst : "klikk på lukk_forste_fane") ")")
    return dlg
}

; v0.4: Alt+X lukker den aktive pasienten (tipset fra Daniel 25.10). Fanens
; lukkeknapp gjaldt den første fanen, som er en annen pasient når legen har en
; pasient åpen fra før. Tom lukk_tast i config.ini gir det gamle klikket.
LukkPasientTast(hwnd) {
    if K.lukkTast != "" {
        Aktiver(hwnd)
        Send K.lukkTast
    } else
        KlikkVindu(hwnd, K.pLukk)
}

FinnLukkDialog(pid, hwnd) {
    for w in WinGetList("ahk_pid " pid) {
        if w = hwnd
            continue
        try {
            el := UIA.ElementFromHandle(w)
            if el.ElementExist({AutomationId: "SaveButton"}) && el.ElementExist({Type: "Text", Name: "Lukk pasienter"})
                return el
        }
    }
    return 0
}

LukkDialogNavn(dlg) {
    navn := []
    for hs in dlg.FindElements({AutomationId: "HeaderSite"})
        for tx in hs.FindElements({Type: "Text"}) {
            n := Trim(tx.Name)
            if n != "" && !RegExMatch(n, "^\d{1,2}:\d{2}$")
                navn.Push(n)
        }
    return navn
}

TrykkKnapp(dlg, hva) {
    if hva = "Lagre og lukk"
        b := dlg.FindElement({AutomationId: "SaveButton"})
    else
        b := dlg.FindElement({Type: "Button", Name: hva})
    b.GetPattern(UIA.Pattern.Invoke).Invoke()
}

SammeNavn(a, b) => OrdSett(a) == OrdSett(b)

OrdSett(s) {
    s := StrLower(RegExReplace(s, "[,.]", " "))
    liste := ""
    for w in StrSplit(s, " ", " `t")
        if w != ""
            liste .= w "`n"
    return Sort(liste)
}

; -----------------------------------------------------------------------------
; Vinduskontroll: alt som ikke er kjent stopper kjøringen
; -----------------------------------------------------------------------------
SjekkVinduer(hwnd, pid, fase, adv := 0) {
    lukket := 0
    for w in WinGetList("ahk_pid " pid) {
        if w = hwnd
            continue
        cls := WinGetClass(w), tit := WinGetTitle(w)
        WinGetPos(&x, &y, &bw, &bh, w)
        if cls = "#32770" {
            mt := ""
            try mt := WinGetText(w)
            if InStr(mt, "Lib/Cave ikke lest inn") && LukkMeldingsboks(w) {
                Logg("Sen meldingsboks «Lib/Cave ikke lest inn» lukket (" fase ")")
                if IsObject(adv)
                    adv.Push("Legemiddellisten kunne ikke hentes (WebMed: «Lib/Cave ikke lest inn. Ukjent feil.»)")
                lukket++
                continue
            }
            throw Error("Uventet meldingsboks (" fase ", " StrLen(mt) " tegn). Les den i WebMed.")
        }
        if InStr(cls, "HwndWrapper") && tit = "" && ErVarselvert(w, x, bw) {
            if bh > 30
                Logg("Varsler synlige i WebMed (" fase "), " bw "x" bh)
            continue
        }
        throw Error("Ukjent vindu (" fase "): klasse=" cls ", tittel " StrLen(tit) " tegn, " bw "x" bh ". Se vinduet i WebMed.")
    }
    return lukket
}

; Varselfeltet nederst til høyre: ca. 574 px bredt ved 100 % (skaleres med DPI
; fra v0.5), ett eller flere barn som alle er List/ItemsControl. Vinduer uten
; barn regnes IKKE som varselfelt.
ErVarselvert(w, x, bw) {
    if !KalVarselBredde(bw, KalSkala(VinduDpi(w))) || x + bw < A_ScreenWidth * 0.6
        return false
    try {
        el := UIA.ElementFromHandle(w)
        if el.ElementExist({AutomationId: "SaveButton"})
            return false
        barn := el.Children
        if barn.Length = 0
            return false
        for c in barn
            if !(c.Type = UIA.Type.List && c.ClassName = "ItemsControl")
                return false
        return true
    }
    return false
}

; -----------------------------------------------------------------------------
; Posten til Skrift (én post i POST /mailbox/batch, handoffen §3)
; -----------------------------------------------------------------------------
ByggPost(t, ref, tidl, fam, liste, pasientId, adv, kons := "") {
    p := Map()
    p["referanse"] := ref
    p["tidspunkt"] := Tidspunkt(t.fra, LISTEDATO)
    ; Avtale-ID-en er nøkkelen Skrift oppdaterer på (påkrevd i dagslisten)
    eid := EksternIdFor(t.id)
    if eid = ""
        Logg(ref ": avtale-ID-en er ikke en GUID; posten kan ikke sendes i dagslisten")
    else {
        p["eksternId"] := eid
        if !(eid == StrLower(t.id))
            Logg(ref ": avtale-ID-en har 11 sifre på rad (ligner fødselsnummer); sendes med sifrene byttet til bokstaver")
    }
    ; Navnet brukes bare her og sendes ikke (CR-499). Fødselsdatoen sendes som
    ; ÅÅÅÅ-MM-DD (CR-500), bare når århundret er sikkert.
    fk := FodselsarKjonn(Trim(t.navn " " t.fdato), LISTEDATO, FormatTime(, "yyyy-MM-dd"))
    if fk.dato != ""
        p["fodselsdato"] := fk.dato
    if fk.kjonn != ""
        p["kjonn"] := fk.kjonn
    if fk.alder != ""
        p["alder"] := fk.alder
    Logg(ref ": fødselsdato " (fk.dato != "" ? "lest" : "ikke bestemt") ", kjønn " (fk.kjonn != "" ? "lest" : "ikke lest") ", alder " (fk.alder != "" ? "lest" : "ikke bestemt"))
    ; Står pasientens navn i fritekst (kommentaren, journalfeltene, konsultasjonen),
    ; byttes det med «[pasient]» før teksten legges i posten (v0.4.1)
    nn := 0
    kommentar := UtenPasientNavn(t.kommentar, t.navn, &nn)
    tidl := UtenPasientNavn(tidl, t.navn, &nn)
    fam := UtenPasientNavn(fam, t.navn, &nn)
    liste := UtenPasientNavn(liste, t.navn, &nn)
    kons := UtenPasientNavn(kons, t.navn, &nn)
    if nn
        Logg(ref ": pasientens navn byttet med [pasient] " nn " gang(er) i teksten")
    ; WebMed har bare kommentaren på timen, ikke et eget felt for årsaken:
    ; arsak sendes ikke, kommentaren går i timekommentar (planen §5.2).
    SettTekst(p, "timekommentar", kommentar, 1000, adv)
    ; Bakgrunn: tidligere sykdommer, og fra v0.4 siste konsultasjon sist
    bak := Trim(tidl, " `t`r`n") != "" ? "Tidligere sykdommer:`n" Linjer(tidl) : ""
    if kons != ""
        bak .= (bak = "" ? "" : "`n") kons
    if bak != ""
        SettTekst(p, "bakgrunn", bak, 20000, adv)
    if Trim(fam, " `t`r`n") != ""
        SettTekst(p, "familieSosialt", Linjer(fam), 5000, adv)
    if Trim(liste, " `t`r`n") != ""
        SettTekst(p, "legemiddelliste", Linjer(liste), 10000, adv)
    if !(p.Has("timekommentar") || p.Has("bakgrunn") || p.Has("familieSosialt") || p.Has("legemiddelliste"))
        adv.Push("Verken timekommentar, bakgrunn, familie/sosialt eller legemiddelliste ble funnet")
    SettTekst(p, "timetype", t.type, 40, adv)
    if RegExMatch(t.varighet, "^(\d{1,4})'$", &m) && Integer(m[1]) <= 1440
        p["varighetMin"] := Integer(m[1])
    SettTekst(p, "behandler", t.lege, 40, adv)
    if pasientId != "" {
        if TrygId(pasientId)
            p["eksternPasientId"] := pasientId
        else
            Logg(ref ": pasient-GUID-en sendes ikke med (ligner fødselsnummer)")
    }
    ; Høyst 20 advarsler per post, hver høyst 300 tegn (grensene i Skrift)
    for i, a in adv
        adv[i] := SubStr(RensFnr(NormLinjer(a)), 1, 300)
    if adv.Length > 20 {
        for i, a in adv
            if i >= 20
                Logg(ref ": advarsel " i " (ikke sendt): " a)
        rest := adv.Length - 19
        adv.Length := 19
        adv.Push(rest " advarsler til står i loggen på PC-en")
    }
    p["advarsler"] := adv
    return p
}

UtenPasientNavn(s, navn, &antall) {
    r := SkjulNavn(s, navn, "[pasient]")
    antall += r.antall
    return r.tekst
}

; Avtale-ID-en som eksternId. WebMeds avtale-ID er en GUID. Har den 11 sifre på
; rad, ligner den et fødselsnummer (gjelder rundt 0,4 % av GUID-er); da byttes
; hvert siffer med en bokstav (0 = g … 9 = p) bak «wm-». Byttet er fast, så samme
; time får samme eksternId ved hver kjøring. Ikke en GUID: "" (kan ikke sendes).
EksternIdFor(id) {
    if !ErGuid(id)
        return ""
    id := StrLower(id)
    if TrygId(id)
        return id
    ut := "wm-"
    loop parse id
        ut .= IsDigit(A_LoopField) ? Chr(Ord("g") + Integer(A_LoopField)) : A_LoopField
    return TrygId(ut) ? ut : ""
}

; Kjønn og alder fra timebokas «ddmmåå (K56)» (fødselsdato med to sifre for
; året, kjønn og alder). Århundret velges slik at alderen stemmer med den WebMed
; viser, regnet fra i dag eller fra listedatoen; alderen som sendes, regnes fra
; fødselsdatoen på listedatoen (timedagen). Stemmer ingen av århundrene, sendes
; ikke alderen. Kjønn bare K eller M.
; Svar: {ar: fødselsår eller 0, dato: "ÅÅÅÅ-MM-DD" eller "", kjonn: "K", "M" eller "",
;        alder: tall eller ""}
FodselsarKjonn(overskrift, listedato, idag) {
    r := {ar: 0, dato: "", kjonn: "", alder: ""}
    if !RegExMatch(overskrift, "i)(?<!\d)(\d{2})(\d{2})(\d{2})\s*\(\s*([KM])\s*(\d{1,3})\s*\)", &m)
        return r
    r.kjonn := StrUpper(m[4])
    alder := Integer(m[5])
    treff := 0, antall := 0
    for hundre in [1900, 2000] {
        ar := hundre + Integer(m[3])
        if ar > Integer(SubStr(idag, 1, 4)) || !IsTime(Format("{:04d}{}{}", ar, m[2], m[1]))
            continue
        if AlderPa(ar, m[2], m[1], idag) = alder || AlderPa(ar, m[2], m[1], listedato) = alder
            treff := ar, antall++
    }
    if antall = 1 {
        r.ar := treff
        r.dato := Format("{:04d}-{}-{}", treff, m[2], m[1])
        r.alder := AlderPa(treff, m[2], m[1], listedato)
    }
    return r
}

; Alder på en dato (ÅÅÅÅ-MM-DD) for en som er født dd.mm.ar
AlderPa(ar, mm, dd, dato) {
    a := Integer(SubStr(dato, 1, 4)) - ar
    if Integer(SubStr(dato, 6, 2) SubStr(dato, 9, 2)) < Integer(mm dd)
        a--
    return a
}

; Normaliserte linjeskift, uten fødselsnummer, kuttet til maks. Tomt felt utelates.
SettTekst(p, felt, verdi, maks, adv) {
    v := RensFnr(NormLinjer(String(verdi)))
    if StrLen(v) > maks {
        adv.Push(felt " var lengre enn " maks " tegn og er kuttet")
        v := SubStr(RensFnr(SubStr(v, 1, maks)), 1, maks)
    }
    if Trim(v, " `t`n") != ""
        p[felt] := v
}

; ID-er som sendes: synlige ASCII-tegn, ikke for lange, og uten noe som
; ligner fødselsnummer (Skrift avviser hele posten da).
TrygId(s) => s is String && RegExMatch(s, "^[\x21-\x7E]{1,100}$") && !InStr(s, '"') && !InStr(s, "\") && RensFnr(s) == s

; Lager JSON-en for posten og kontrollerer den mot handoffen og grensene i
; Skrift. Svar: {post, kropp, innhold (har minst ett innholdsfelt), feil: [], sendbar}
ForberedPost(p) {
    rec := {post: p, kropp: PostJson(p), innhold: false, feil: [], sendbar: false}
    rec.innhold := p.Has("timekommentar") || p.Has("bakgrunn") || p.Has("familieSosialt") || p.Has("legemiddelliste") || p.Has("arsak")
    r := p["referanse"]
    if StrLen(r) < 1 || StrLen(r) > 200 || RensFnr(r) !== r
        rec.feil.Push("referanse må være 1–200 tegn uten fødselsnummer")
    for felt, maks in Map("timekommentar", 1000, "bakgrunn", 20000, "familieSosialt", 5000,
        "legemiddelliste", 10000, "timetype", 40, "behandler", 40)
        if p.Has(felt) && StrLen(p[felt]) > maks
            rec.feil.Push(felt " er lengre enn " maks " tegn")
    if !RegExMatch(p["tidspunkt"], "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:00[+-]\d{2}:\d{2}$")
        rec.feil.Push("tidspunkt har feil format")
    if !p.Has("eksternId")
        rec.feil.Push("avtale-ID-en (eksternId) mangler; dagslisten i Skrift krever den")
    else if !TrygId(p["eksternId"])
        rec.feil.Push("eksternId har ugyldige tegn")
    if p.Has("eksternPasientId") && !ErGuid(p["eksternPasientId"])
        rec.feil.Push("eksternPasientId er ikke en GUID")
    if p.Has("pasientOverskrift") || p.Has("fodselsar")
        rec.feil.Push("navn og fødselsår skal ikke sendes (CR-499)")
    if p.Has("fodselsdato") && !(RegExMatch(p["fodselsdato"], "^\d{4}-\d{2}-\d{2}$") && IsTime(StrReplace(p["fodselsdato"], "-")))
        rec.feil.Push("fodselsdato er ikke en gyldig dato (ÅÅÅÅ-MM-DD)")
    if p.Has("alder") && !(p["alder"] is Integer && p["alder"] >= 0 && p["alder"] <= 130)
        rec.feil.Push("alder er utenfor 0 til 130")
    if p.Has("kjonn") && !(p["kjonn"] == "K" || p["kjonn"] == "M")
        rec.feil.Push("kjonn er verken K eller M")
    if p.Has("varighetMin") && !(p["varighetMin"] is Integer && p["varighetMin"] >= 0 && p["varighetMin"] <= 1440)
        rec.feil.Push("varighetMin er utenfor 0 til 1440")
    if p["advarsler"].Length > 20
        rec.feil.Push("mer enn 20 advarsler")
    for a in p["advarsler"]
        if StrLen(a) > 300 {
            rec.feil.Push("en advarsel er lengre enn 300 tegn")
            break
        }
    if RegExMatch(rec.kropp, "(?<!\d)\d{11}(?!\d)|(?<!\d)\d{6}[ .]\d{5}(?!\d)")
        rec.feil.Push("posten inneholder noe som ligner et fødselsnummer")
    ; Posten må leses tilbake til nøyaktig de samme verdiene
    try {
        tilbake := JsonLes(rec.kropp)
        for f in POST_FELT
            if p.Has(f) != tilbake.Has(f) || p.Has(f) && !LikVerdi(p[f], tilbake[f])
                rec.feil.Push("feltet " f " ble ikke likt etter JSON-koding")
        for f in tilbake
            if !p.Has(f)
                rec.feil.Push("ukjent felt " f " i posten")
    } catch as e
        rec.feil.Push("posten er ikke gyldig JSON (" e.Message ")")
    rec.sendbar := rec.innhold && !rec.feil.Length
    return rec
}

LikVerdi(a, b) {
    if a is Array {
        if !(b is Array) || a.Length != b.Length
            return false
        for i, v in a
            if !(b[i] is String) || !(v == b[i])
                return false
        return true
    }
    if a is Integer
        return b is Number && a = b
    return b is String && a == b
}

PostJson(p, innrykk := "") {
    s := "{", forste := true
    for f in POST_FELT {
        if !p.Has(f)
            continue
        v := p[f]
        s .= (forste ? "" : ",") "`n" innrykk '  "' f '": ' (v is Array ? JSListe(v) : v is Integer ? String(v) : JS(v))
        forste := false
    }
    return s "`n" innrykk "}"
}

KildeVersjon() => SubStr(RensFnr(String(WM_VERSJON)), 1, 40)

; Kroppen til POST /mailbox/batch: konvolutten og postene med innhold. Den samme
; funksjonen lager «bunke» i JSON-filen (med innrykk) og kroppen som sendes, så
; filen viser nøyaktig det som sendes.
BunkeJson(recs, innrykk := "") {
    n := "`n", i2 := innrykk "  "
    s := "{" n i2 '"kilde": "webmed-ahk",' n
    if KildeVersjon() != ""
        s .= i2 '"kildeVersjon": ' JS(KildeVersjon()) "," n
    s .= i2 '"skriptVersjon": ' JS(SKRIPT_VERSJON) "," n
    s .= i2 '"poster": ['
    for i, r in recs
        s .= (i = 1 ? "" : ",") n i2 "  " StrReplace(r.kropp, "`n", "`n" i2 "  ")
    s .= (recs.Length ? n i2 : "") "]" n
    return s innrykk "}"
}

; Bunken leses tilbake og sammenlignes med postene. Svar: liste med feil.
KontrollerBunke(kropp, recs) {
    feil := []
    if recs.Length > 60
        feil.Push("mer enn 60 poster (grensen per bunke i Skrift)")
    sett := Map()
    for r in recs {
        if !r.post.Has("eksternId")
            continue
        e := r.post["eksternId"]
        if sett.Has(e)
            feil.Push("to timer har samme avtale-ID (" sett[e] " og " r.post["referanse"] ")")
        else
            sett[e] := r.post["referanse"]
    }
    try {
        j := JsonLes(kropp)
        if !(j is Map) || !j.Has("poster") || !(j["poster"] is Array) || j["poster"].Length != recs.Length
            feil.Push("bunken har ikke de samme postene etter JSON-koding")
        else {
            for i, r in recs {
                pr := j["poster"][i]
                for f in POST_FELT
                    if !(pr is Map) || r.post.Has(f) != pr.Has(f) || r.post.Has(f) && !LikVerdi(r.post[f], pr[f]) {
                        feil.Push("post " i " (" r.post["referanse"] "): feltet " f " ble ikke likt i bunken")
                        break
                    }
            }
            if !(j.Has("kilde") && j["kilde"] == "webmed-ahk" && j.Has("skriptVersjon") && j["skriptVersjon"] == SKRIPT_VERSJON)
                feil.Push("konvolutten ble ikke lik etter JSON-koding")
            for k in j
                if !(k == "kilde" || k == "kildeVersjon" || k == "skriptVersjon" || k == "poster")
                    feil.Push("ukjent felt " k " i bunken")
        }
    } catch as e
        feil.Push("bunken er ikke gyldig JSON (" e.Message ")")
    if RegExMatch(kropp, "(?<!\d)\d{11}(?!\d)|(?<!\d)\d{6}[ .]\d{5}(?!\d)")
        feil.Push("bunken inneholder noe som ligner et fødselsnummer")
    return feil
}

; -----------------------------------------------------------------------------
; Sending til Skrift (bare når [skrift] send=1)
; -----------------------------------------------------------------------------
; Før WebMed røres: tokenet finnes, virker og har rettigheten postkasse.
SjekkToken() {
    tok := LesToken()
    svar := KallSkrift("GET", "/me", "", tok)
    tok := ""
    if svar.status != 200
        throw Error(StatusTekst(svar, "GET /me") " WebMed er ikke rørt.")
    rett := "", utl := ""
    try {
        me := JsonLes(svar.tekst)
        rett := me["token"]["rettigheter"]
        utl := me["token"]["utloper"]
    }
    har := false, liste := ""
    if rett is Array
        for x in rett {
            liste .= (liste = "" ? "" : ", ") x
            if x == "postkasse"
                har := true
        }
    if !har
        throw Error("Tokenet mangler rettigheten «postkasse». Lag et token med postkasse i Skrift (Innstillinger → Integrasjoner). WebMed er ikke rørt.")
    Logg("Skrift: tokenet virker (rettigheter: " liste (utl is String ? ", utløper " SubStr(utl, 1, 10) : "") ")")
}

SendTilSkrift(res) {
    if !res.gyldig
        throw Error("ingenting er sendt fordi minst én post ikke er gyldig (se advarslene i " ((res.HasProp("fil") && res.fil != "") ? "JSON-filen" : "loggen") ")")
    if !res.klare.Length
        return "Ingen poster å sende til Skrift."
    tok := LesToken()
    Logg("Sender dagslisten til Skrift: " res.klare.Length " post(er) i én bunke (POST /mailbox/batch)")
    Hint "Skrift: sender dagslisten (" res.klare.Length " poster) … " K.avbrytTekst " avbryter."
    try
        svar := SendBunke(res.kropp, tok)
    finally
        tok := ""
    return TolkBunkesvar(svar, res.klare)
}

; Én POST /mailbox/batch. Alle postene har eksternId, så et nytt forsøk etter
; nettverksfeil eller 5xx lager aldri doble poster (Skrift oppdaterer på
; eksternId). Alt annet enn 200 stopper, og da er ingenting sendt (400, 401,
; 403, grensen på 5 dagslister i timen) eller usikkert (gjentatt 5xx).
SendBunke(kropp, tok) {
    forsok := 0
    loop {
        forsok++
        Sjekk()
        try
            svar := KallSkrift("POST", "/mailbox/batch", kropp, tok)
        catch as e {
            if forsok = 1 {
                Logg("POST /mailbox/batch: nettverksfeil (" e.Message "); prøver igjen om 5 s")
                VentSjekk(5000)
                continue
            }
            throw Error("POST /mailbox/batch: nettverksfeil (" e.Message "). Kjør på nytt; sendte poster oppdateres, ikke dobles.")
        }
        s := svar.status
        if s = 200
            return svar
        if s = 429 {
            if ErBunkegrense(svar)
                throw Error("Skrift tar imot høyst 5 dagslister i timen per token. Prøv igjen om " VentTekst(svar.vent) "; ingenting er sendt nå.")
            if forsok <= 2 {
                vent := VentTid(svar.vent)
                Logg("POST /mailbox/batch: 429 (for mange kall); venter " vent // 1000 " s")
                VentSjekk(vent)
                continue
            }
        }
        if s >= 500 && s < 600 && forsok = 1 {
            Logg("POST /mailbox/batch: " s "; prøver igjen om 5 s")
            VentSjekk(5000)
            continue
        }
        if s = 400
            throw Error("POST /mailbox/batch: hele bunken er avvist (400) " FeilDetaljer(svar.tekst) "; ingenting er sendt.")
        throw Error(StatusTekst(svar, "POST /mailbox/batch"))
    }
}

; 429 fra grensen på 5 dagslister i timen, ikke den vanlige på 60 kall i minuttet
ErBunkegrense(svar) {
    melding := ""
    try {
        j := JsonLes(svar.tekst)
        if j is Map && j.Has("error") && j["error"] is String
            melding := j["error"]
    }
    return InStr(melding, "dagslist") || VentSek(svar.vent) > 65
}

VentSek(h) => RegExMatch(h, "^\s*(\d{1,6})(?!\d)", &m) ? Integer(m[1]) : 0

VentTekst(h) {
    s := VentSek(h)
    if !s
        return "inntil en time"
    return s < 60 ? s " sekunder" : Ceil(s / 60) " minutter"
}

; Svar 200: én rad per post (indeks i bunken). Logger hver post med referansen
; og lager meldingen til hintet. Grunnen ved avvist er Skrifts feilmelding
; (feltnavn og regel, ikke innholdet), kuttet og uten fødselsnummer.
TolkBunkesvar(svar, klare) {
    j := ""
    try j := JsonLes(svar.tekst)
    if !(j is Map) || !j.Has("resultater") || !(j["resultater"] is Array)
        throw Error("POST /mailbox/batch: svaret (200) mangler resultater; sjekk innboksen i Skrift")
    tall := Map("opprettet", 0, "oppdatert", 0, "hoppet_over", 0, "avvist", 0)
    avviste := "", sett := Map()
    for x in j["resultater"] {
        if !(x is Map) || !x.Has("indeks") || !(x["indeks"] is Integer) || x["indeks"] < 0 || x["indeks"] >= klare.Length || sett.Has(x["indeks"]) {
            Logg("Svaret har en rad som ikke kan knyttes til en post i bunken")
            continue
        }
        sett[x["indeks"]] := true
        ref := klare[x["indeks"] + 1].post["referanse"]
        st := x.Has("status") && x["status"] is String ? x["status"] : ""
        id := x.Has("id") && x["id"] is Number ? " (id " x["id"] ")" : ""
        grunn := x.Has("grunn") && x["grunn"] is String ? SubStr(RensFnr(NormLinjer(x["grunn"])), 1, 200) : ""
        if tall.Has(st)
            tall[st]++
        switch st, true {
            case "opprettet":
                Logg("POST /mailbox/batch " ref ": ny i innboksen" id)
            case "oppdatert":
                Logg("POST /mailbox/batch " ref ": oppdatert" id)
            case "hoppet_over":
                Logg("POST /mailbox/batch " ref ": ikke endret, timen er allerede startet i Skrift" id)
            case "avvist":
                Logg("POST /mailbox/batch " ref ": AVVIST" (grunn != "" ? ": " grunn : ""))
                avviste .= (avviste = "" ? "" : ", ") ref
            default:
                Logg("POST /mailbox/batch " ref ": ukjent status i svaret")
        }
    }
    mangler := klare.Length - sett.Count
    if mangler > 0
        Logg("ADVARSEL: svaret manglet " mangler " av " klare.Length " poster; sjekk innboksen i Skrift")
    Logg("Sending ferdig: " tall["opprettet"] " nye, " tall["oppdatert"] " oppdatert, " tall["hoppet_over"] " allerede startet, " tall["avvist"] " avvist")
    m := "Sendt til Skrift: " tall["opprettet"] " nye, " tall["oppdatert"] " oppdatert"
    if tall["hoppet_over"]
        m .= ", " tall["hoppet_over"] " allerede startet (ikke endret)"
    m .= "."
    if tall["avvist"]
        m .= "`nAVVIST: " avviste " (grunnen står i loggen)."
    if mangler > 0
        m .= "`n" mangler " post(er) uten svar; sjekk innboksen i Skrift."
    return m
}

; -----------------------------------------------------------------------------
; v0.11.1 (Daniel 09.11, NHN-nett): proxyen. WinHttpRequest følger ikke
; Windows' proxyinnstillinger (PAC-skript som config.nhn.no/kunde.pac eller en
; manuell proxy), så kallet gikk rett ut og ble fanget av nettets sperre med et
; sertifikat skriptet ikke stoler på (0x80072F0D). Nå slås proxyen opp slik
; Windows gjør det (WinHttpGetIEProxyConfigForCurrentUser og WinHttpGetProxyForUrl)
; og settes på kallet. [skrift] proxy i config.ini: tom = automatisk (Windows'
; innstillinger), «ingen» = direkte, «vert:port» = fast proxy. Bare verten
; logges, aldri tokenet.
; -----------------------------------------------------------------------------
global PROXY_FUNNET := ""   ; proxyen fra Windows, slått opp én gang per kjøring av skriptet

; Proxyen for et kall: "" = direkte, ellers «vert:port[;vert:port]» til SetProxy
ProxyForKall(url) {
    global PROXY_FUNNET
    v := StrLower(Trim(K.proxy))
    if v = "ingen" || v = "none" || v = "direkte"
        return ""
    if v != ""
        return Trim(K.proxy)
    if PROXY_FUNNET = ""
        PROXY_FUNNET := ProxyFraWindows(url) || "direkte"
    return PROXY_FUNNET = "direkte" ? "" : PROXY_FUNNET
}

; Proxyen Windows ville brukt for url: PAC-skript (konfigurasjonsskript eller
; automatisk oppdaging) eller den manuelle proxyen. "" når Windows går direkte,
; eller når oppslaget ikke lot seg gjøre (da prøves kallet direkte som før).
ProxyFraWindows(url) {
    ut := ""
    cfg := Buffer(A_PtrSize = 8 ? 32 : 16, 0)
    if !DllCall("winhttp\WinHttpGetIEProxyConfigForCurrentUser", "Ptr", cfg, "Int")
        return ""
    autoDetect := NumGet(cfg, 0, "Int")
    pUrl := NumGet(cfg, A_PtrSize, "Ptr"), pProxy := NumGet(cfg, 2 * A_PtrSize, "Ptr"), pBypass := NumGet(cfg, 3 * A_PtrSize, "Ptr")
    pacUrl := pUrl ? StrGet(pUrl, "UTF-16") : ""
    manuell := pProxy ? StrGet(pProxy, "UTF-16") : ""
    try {
        if pacUrl != "" || autoDetect {
            hSession := DllCall("winhttp\WinHttpOpen", "WStr", "Skrift-AHK-dagsliste/" SKRIPT_VERSJON, "UInt", 1, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
            if hSession {
                try {
                    ; WINHTTP_AUTOPROXY_OPTIONS: dwFlags, dwAutoDetectFlags, lpszAutoConfigUrl, lpvReserved, dwReserved, fAutoLogonIfChallenged
                    opt := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
                    flagg := (pacUrl != "" ? 2 : 0) | (autoDetect ? 1 : 0)   ; CONFIG_URL = 2, AUTO_DETECT = 1
                    NumPut("UInt", flagg, opt, 0)
                    NumPut("UInt", autoDetect ? 3 : 0, opt, 4)              ; DHCP = 1, DNS_A = 2
                    if pacUrl != ""
                        NumPut("Ptr", pUrl, opt, 8)
                    NumPut("Int", 1, opt, A_PtrSize = 8 ? 28 : 20)       ; fAutoLogonIfChallenged
                    info := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
                    if DllCall("winhttp\WinHttpGetProxyForUrl", "Ptr", hSession, "WStr", url, "Ptr", opt, "Ptr", info, "Int") {
                        pListe := NumGet(info, A_PtrSize, "Ptr"), pB2 := NumGet(info, 2 * A_PtrSize, "Ptr")
                        if pListe {
                            ut := Trim(StrGet(pListe, "UTF-16"))
                            DllCall("GlobalFree", "Ptr", pListe)
                        }
                        if pB2
                            DllCall("GlobalFree", "Ptr", pB2)
                    }
                } finally
                    DllCall("winhttp\WinHttpCloseHandle", "Ptr", hSession)
            }
        }
        if ut = "" && manuell != "" && !ProxyUnntak(url, pBypass ? StrGet(pBypass, "UTF-16") : "")
            ut := ProxyForHttps(manuell)
    } finally {
        for p in [pUrl, pProxy, pBypass]
            if p
                DllCall("GlobalFree", "Ptr", p)
    }
    ; WinHTTP svarer «DIRECT» eller tom når Windows går direkte
    if ut = "" || StrLower(ut) = "direct"
        return ""
    return ut
}

; Den manuelle proxyen kan være «vert:port» eller «http=vert:port;https=vert2:port»:
; https-oppføringen gjelder, ellers den uten protokoll
ProxyForHttps(liste) {
    enkel := ""
    for del in StrSplit(liste, [";", " "]) {
        del := Trim(del)
        if del = ""
            continue
        if RegExMatch(del, "i)^https=(.+)$", &m)
            return m[1]
        if !InStr(del, "=")
            enkel := del
    }
    return enkel
}

; Står verten i unntakslisten til den manuelle proxyen («<local>;*.nhn.no;…»)?
ProxyUnntak(url, unntak) {
    if unntak = "" || !RegExMatch(url, "i)^https?://([^/:]+)", &m)
        return false
    vert := StrLower(m[1])
    for u in StrSplit(unntak, [";", " "]) {
        u := StrLower(Trim(u))
        if u = "" || u = "<local>"
            continue
        if RegExMatch(vert, "i)^" StrReplace(RegExReplace(u, "[.+?^${}()|\[\]\\]", "\$0"), "*", ".*") "$")
            return true
    }
    return false
}

; Leser tokenet fra tokenfilen ([skrift] token=skr_…, eller bare tokenet).
; Tokenet skrives aldri til logg, JSON eller hint.
LesToken() {
    fil := K.tokenfil
    if fil = ""
        throw Error("[skrift] tokenfil mangler i config.ini")
    if !FileExist(fil)
        throw Error("Fant ikke tokenfilen " fil)
    tok := Trim(IniRead(fil, "skrift", "token", ""))
    if tok = "" {
        innhold := ""
        try innhold := Trim(FileRead(fil, "UTF-8"), " `t`r`n" Chr(0xFEFF))
        if RegExMatch(innhold, "^skr_[A-Za-z0-9_-]+$")
            tok := innhold
    }
    if !RegExMatch(tok, "^skr_[A-Za-z0-9_-]{16,}$")
        throw Error("Fant ikke et gyldig token i " fil " (ventet [skrift] og token=skr_… på hver sin linje)")
    return tok
}

KallSkrift(metode, sti, kropp, tok) {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts(10000, 10000, 30000, 30000)
    ; v0.11.1: proxyen fra Windows (PAC eller manuell) eller [skrift] proxy; logges én gang
    proxy := ProxyForKall(SKRIFT_BASE sti)
    static loggetProxy := ""
    if proxy != loggetProxy {
        Logg("Nett: " (proxy = "" ? "direkte (ingen proxy)" : "proxy " proxy (Trim(K.proxy) = "" ? " (fra Windows' innstillinger)" : " (fra config.ini)")))
        loggetProxy := proxy
    }
    if proxy != ""
        http.SetProxy(2, proxy)   ; HTTPREQUEST_PROXYSETTING_PROXY
    http.Open(metode, SKRIFT_BASE sti, false)
    http.Option[6] := false   ; ingen omdirigering: token og kropp går bare til SKRIFT_BASE (3xx = stopp)
    http.SetRequestHeader("Authorization", "Bearer " tok)
    http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
    http.SetRequestHeader("Accept", "application/json")
    http.SetRequestHeader("User-Agent", "Skrift-AHK-dagsliste/" SKRIPT_VERSJON)
    if kropp = ""
        http.Send()
    else
        http.Send(Utf8Bytes(kropp))
    tekst := ""
    try
        tekst := Utf8Svar(http)
    catch {
        try tekst := http.ResponseText
    }
    vent := ""
    try vent := http.GetResponseHeader("Retry-After")
    return {status: http.Status, tekst: tekst, vent: vent}
}

; Kroppen som UTF-8-bytes (SAFEARRAY), så æøå ikke avhenger av WinHttps tegnsett
Utf8Bytes(s) {
    n := StrPut(s, "UTF-8") - 1
    buf := Buffer(n + 1)
    StrPut(s, buf, "UTF-8")
    arr := ComObjArray(0x11, n)
    loop n
        arr[A_Index - 1] := NumGet(buf, A_Index - 1, "UChar")
    return arr
}

Utf8Svar(http) {
    b := http.ResponseBody
    n := b.MaxIndex() + 1
    if n <= 0
        return ""
    p := NumGet(ComObjValue(b) + 8 + A_PtrSize, "Ptr")
    return StrGet(p, n, "UTF-8")
}

StatusTekst(svar, hva) {
    kode := "", melding := ""
    try {
        j := JsonLes(svar.tekst)
        if j.Has("error") && j["error"] is String
            kode := j["error"]
        if j.Has("message") && j["message"] is String
            melding := j["message"]
    }
    switch svar.status {
        case 401:
            return hva ": tokenet virker ikke (" kode "). Lag et nytt token i Skrift (Innstillinger → Integrasjoner) og lim det inn i tokenfilen."
        case 403:
            if kode = "SCOPE_MISSING"
                return hva ": tokenet mangler rettigheten postkasse (SCOPE_MISSING). Lag et token med postkasse i Skrift."
            return hva ": kontoen gir ikke tilgang (" kode "). Ta kontakt med Skrift."
        case 429:
            return hva ": for mange kall (429). Vent et minutt og kjør på nytt."
        default:
            return hva ": svar " svar.status (kode != "" ? " " kode : "") (melding != "" ? " – " SubStr(melding, 1, 200) : "")
    }
}

; Feilkode, melding og feltnavn fra et 400-svar (aldri verdier fra posten)
FeilDetaljer(tekst) {
    try {
        j := JsonLes(tekst)
        s := ""
        if j.Has("error") && j["error"] is String
            s .= j["error"]
        if j.Has("message") && j["message"] is String
            s .= (s = "" ? "" : " – ") SubStr(j["message"], 1, 200)
        if j.Has("details") {
            d := j["details"], felt := ""
            ; Klammene trengs: uten dem hører «else» til for-løkken (AHK v2)
            if d is Map {
                for nk in d
                    felt .= (felt = "" ? "" : ", ") nk
            } else if d is Array {
                for x in d
                    felt .= (felt = "" ? "" : ", ") DetaljFelt(x)
            }
            if felt != ""
                s .= " (felt: " SubStr(felt, 1, 200) ")"
        }
        return s
    }
    return "(svaret var ikke JSON)"
}

; Feltnavnet i ett element av details: "felt", {"path": ["felt", …]} eller {"field": "felt"}
DetaljFelt(x) {
    if x is String
        return x
    if x is Map {
        if x.Has("path") && x["path"] is Array && x["path"].Length && x["path"][1] is String
            return x["path"][1]
        if x.Has("field") && x["field"] is String
            return x["field"]
    }
    return "?"
}

; Retry-After i sekunder -> ms, mellom 20 og 65 s
VentTid(h) {
    s := 30
    if RegExMatch(h, "^\s*(\d{1,4})(?!\d)", &m)
        s := Integer(m[1])
    return Max(20, Min(65, s)) * 1000
}

VentSjekk(ms) {
    slutt := A_TickCount + ms
    while A_TickCount < slutt {
        Sjekk()
        Sleep Min(250, Max(10, slutt - A_TickCount))
    }
    Sjekk()
}

; -----------------------------------------------------------------------------
; Hjelpere
; -----------------------------------------------------------------------------
Aktiver(hwnd) {
    ; Tre forsøk: et annet program kan ta fokus et øyeblikk (sett 25.10)
    loop 3 {
        WinActivate hwnd
        if WinWaitActive(hwnd, , 1.5)
            return
    }
    throw Error("WebMed ble ikke aktivt vindu")
}

; v0.5.1: WebMed skal stå maksimert, slik det sto da skjermpunktene ble målt.
; Står vinduet ikke maksimert, eller maksimert med en annen størrelse enn mal
; (en annen skjerm), flyttes det til skjermen kalibreringen ble gjort på (pos:
; vinduets x,y da; "" = skjermen det står på) og maksimeres. mal "" = bare
; maksimer. Svar: plasseringen fra før (til VinduTilbake), eller "" når vinduet
; allerede sto riktig. Størrelsen kontrolleres etterpå av KalSjekk.
VinduForKjoring(hwnd, mal, pos := "") {
    mm := WinGetMinMax(hwnd)
    WinGetPos(&x, &y, &w, &h, hwnd)
    if mm = 1 && (mal = "" || w "x" h = mal)
        return ""
    wp := Buffer(44, 0)
    NumPut("UInt", 44, wp, 0)
    if !DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp)
        throw Error("Kunne ikke lese plasseringen til WebMed-vinduet")
    Logg("WebMed sto " (mm = -1 ? "minimert" : mm = 1 ? "maksimert med " w "x" h : "ikke maksimert (" w "x" h ")") "; maksimeres og settes tilbake etterpå")
    if mm != 0
        WinRestore hwnd
    if pos != "" && mal != "" {
        p := Punkt(pos), m := Punkt(StrReplace(mal, "x", ","))
        malSkjerm := SkjermVed(p.x + m.x // 2, p.y + m.y // 2)
        WinGetPos(&x, &y, &w, &h, hwnd)
        if malSkjerm && SkjermVed(x + w // 2, y + h // 2) != malSkjerm {
            MonitorGetWorkArea(malSkjerm, &l, &t)
            WinMove l + 50, t + 50, 800, 600, hwnd
            Logg("WebMed flyttet til skjerm " malSkjerm ", der kalibreringen ble gjort")
        }
    }
    WinMaximize hwnd
    VentPaa(() => WinGetMinMax(hwnd) = 1 && (mal = "" || VinduStr(hwnd) = mal), 3000)
    ; WebMed tegner panelene og Avtaler på nytt etter størrelsesendringen
    Sleep K.ventVindu
    Logg("WebMed maksimert: " VinduStr(hwnd))
    return wp
}

VinduStr(hwnd) {
    WinGetPos(, , &w, &h, hwnd)
    return w "x" h
}

; Setter WebMed tilbake til plasseringen fra før (også minimert eller på en
; annen skjerm). wp "" = ingenting ble endret.
VinduTilbake(hwnd, wp) {
    if !IsObject(wp)
        return
    try {
        DllCall("SetWindowPlacement", "Ptr", hwnd, "Ptr", wp)
        Logg("WebMed satt tilbake til plasseringen fra før kjøringen")
    }
}

; Skjermen (nummeret) som har punktet, 0 når ingen har det
SkjermVed(x, y) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if x >= l && x < r && y >= t && y < b
            return A_Index
    }
    return 0
}

KlikkVindu(hwnd, p) {
    Aktiver(hwnd)
    CoordMode "Mouse", "Window"
    MouseClick "Left", p.x, p.y
}

VentPaa(fn, ms, intervall := 100) {
    slutt := A_TickCount + ms
    loop {
        if r := fn()
            return r
        if A_TickCount > slutt
            return 0
        Sleep intervall
        Sjekk()
    }
}

Referanse(t) => RegExReplace(t.fra, "\.", ":") " " Initialer(t.navn)

Initialer(navn) {
    if InStr(navn, ",") {
        d := StrSplit(navn, ",", " ")
        ini := SubStr(d.Length > 1 ? d[2] : "", 1, 1) SubStr(d[1], 1, 1)
    } else {
        o := StrSplit(Trim(navn), " ")
        ini := SubStr(o[1], 1, 1) (o.Length > 1 ? SubStr(o[o.Length], 1, 1) : "")
    }
    return StrUpper(ini)
}

; fra er allerede kontrollert mot ^\d{1,2}[.:]\d{2}$ i LesDagsliste.
; dato = listedatoen (ÅÅÅÅ-MM-DD); tom = i dag. Tidssonen gjelder selve timen,
; så sommertid/vintertid blir riktig også når datoen er en annen enn i dag.
Tidspunkt(fra, dato := "") {
    RegExMatch(fra, "^(\d{1,2})[.:](\d{2})$", &m)
    if dato = ""
        dato := FormatTime(, "yyyy-MM-dd")
    ts := StrReplace(dato, "-") Format("{:02d}{:02d}00", Integer(m[1]), Integer(m[2]))
    return dato "T" Format("{:02d}:{:02d}:00", Integer(m[1]), Integer(m[2])) SoneFor(ts)
}

; Tidssoneforskyvning for et lokalt tidspunkt (ÅÅÅÅMMDDTTMMSS), etter Windows'
; tidssoneregler. Faller tilbake på forskyvningen nå hvis kallet feiler.
SoneFor(ts) {
    lok := Buffer(16, 0), utc := Buffer(16, 0)
    for i, del in [[1, 4], [5, 2], [0, 0], [7, 2], [9, 2], [11, 2], [13, 2]]
        NumPut("UShort", del[2] ? Integer(SubStr(ts, del[1], del[2])) : 0, lok, (i - 1) * 2)
    if !DllCall("TzSpecificLocalTimeToSystemTime", "Ptr", 0, "Ptr", lok, "Ptr", utc)
        return Sone()
    u := Format("{:04d}{:02d}{:02d}{:02d}{:02d}{:02d}", NumGet(utc, 0, "UShort"), NumGet(utc, 2, "UShort"),
        NumGet(utc, 6, "UShort"), NumGet(utc, 8, "UShort"), NumGet(utc, 10, "UShort"), NumGet(utc, 12, "UShort"))
    m := Round(DateDiff(SubStr(ts, 1, 14), u, "Minutes") / 15) * 15
    return (m < 0 ? "-" : "+") Format("{:02d}:{:02d}", Abs(m) // 60, Mod(Abs(m), 60))
}

; Listedatoen fra adressen i Avtaler (date=ÅÅÅÅ-MM-DD). Stopper hvis datoen
; mangler eller er passert, med mindre den er lik testdato (fiktiv testliste).
LesListedato(url, iDag, testdato := "") {
    if !RegExMatch(url, "[?&]date=(\d{4}-\d{2}-\d{2})(?:&|$)", &m) || !GyldigDato(m[1])
        throw Error("Fant ikke datoen i Avtaler. Åpne Avtaler i dagsvisning og prøv igjen.")
    dato := m[1]
    if StrCompare(dato, iDag) < 0 && dato != testdato
        throw Error("Avtaler viser " DatoNavn(dato) ", som er passert. Velg i dag eller en senere dato (testdato i config.ini tillater én passert dato for en fiktiv liste).")
    return dato
}

GyldigDato(s) => RegExMatch(s, "^\d{4}-\d{2}-\d{2}$") && IsTime(StrReplace(s, "-"))

Iso(ts) => FormatTime(ts, "yyyy-MM-dd") "T" FormatTime(ts, "HH:mm:ss") Sone()

Sone() {
    m := Round(DateDiff(A_Now, A_NowUTC, "Minutes") / 15) * 15
    return (m < 0 ? "-" : "+") Format("{:02d}:{:02d}", Abs(m) // 60, Mod(Abs(m), 60))
}

RensFnr(s) {
    s := RegExReplace(s, "(?<!\d)\d{11}(?!\d)", "[fnr fjernet]")
    s := RegExReplace(s, "(?<!\d)\d{6}[ .]\d{5}(?!\d)", "[fnr fjernet]")
    ; v0.10.4: referansen fra journalen («PB 12.03.1965») logges uten datoen
    s := RegExReplace(s, "(?<![\wæøåÆØÅ])([A-ZÆØÅ]{1,5}) \d{2}\.\d{2}\.(19|20)\d{2}(?!\d)", "$1 [fdato]")
    return s
}

Linjer(s) {
    s := StrReplace(StrReplace(s, "`r`n", "`n"), "`r", "`n")
    s := RTrim(s, " `t`n")
    return s = "" ? "" : s "`n"
}

Logg(msg) {
    static fil := ""
    if fil = "" {
        DirCreate K.logg
        fil := K.logg "\" FormatTime(, "yyyy-MM-dd") ".txt"
    }
    linje := FormatTime(, "HH:mm:ss") "." A_MSec "  " RensFnr(msg) "`r`n"
    ; Loggfilen kan være låst et øyeblikk av en annen prosess (synkronisering,
    ; antivirus, en som leser den): prøv igjen i inntil ett sekund (sett 25.10)
    loop 20 {
        try {
            FileAppend linje, fil, "UTF-8-RAW"
            return
        } catch as e {
            if A_Index = 20
                throw e
            Sleep 50
        }
    }
}

; poster: liste fra ForberedPost. «bunke» er nøyaktig kroppen til
; POST /mailbox/batch (sendes når ingen post har «KAN IKKE SENDES»); poster uten
; innhold Skrift tar imot står under «ikkeSendt».
SkrivJson(fil, wmVer, idag, poster, adv, komplett) {
    n := "`n"
    j := "{" n
    j .= '  "kilde": "webmed-ahk",' n
    j .= '  "skriptVersjon": ' JS(SKRIPT_VERSJON) "," n
    j .= '  "webmedVersjon": ' JS(wmVer) "," n
    j .= '  "generert": ' JS(Iso(A_Now)) "," n
    j .= '  "dato": ' JS(idag) "," n
    j .= '  "sending": ' JS(K.send ? "på" : "av") "," n
    j .= '  "komplett": ' (komplett ? "true" : "false") "," n
    klare := [], uten := []
    for r in poster {
        if r.innhold
            klare.Push(r)
        else
            uten.Push(r)
    }
    j .= '  "bunke": ' BunkeJson(klare, "  ") "," n
    j .= '  "ikkeSendt": ['
    for i, r in uten
        j .= (i = 1 ? "" : ",") n "    " StrReplace(r.kropp, "`n", "`n    ")
    j .= (uten.Length ? n "  " : "") "]," n
    j .= '  "advarsler": ' JSListe(adv) n
    j .= "}" n
    tmp := fil ".tmp"
    try FileDelete tmp
    FileAppend j, tmp, "UTF-8-RAW"
    FileMove tmp, fil, 1
}

JS(s) {
    s := RensFnr(String(s))
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(StrReplace(s, "`r`n", "`n"), "`r", "`n")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    if RegExMatch(s, "[\x00-\x1F]") {
        ut := ""
        loop parse s {
            c := Ord(A_LoopField)
            ut .= c < 0x20 ? Format("\u{:04x}", c) : A_LoopField
        }
        s := ut
    }
    return '"' s '"'
}

JSListe(a) {
    if !a.Length
        return "[]"
    s := "["
    for i, v in a
        s .= (i = 1 ? "" : ", ") JS(v)
    return s "]"
}

; v0.11.0: en bryter i [innhold] (standard på; bare nøyaktig 1 slår på)
InnholdBryter(nokkel) => Trim(IniRead(KONFIG, "innhold", nokkel, "1")) == "1"

; Det dagslisten henter fra journalen, som tekst til hint og logg («tidligere
; sykdommer, familie/sosialt, legemiddelliste, siste konsultasjon»; «bare
; timekommentaren» når alt er av). Ren funksjon av k, så den kan testes.
InnholdTekst(k := K) {
    deler := []
    if k.innTidl
        deler.Push("tidligere sykdommer")
    if k.innFam
        deler.Push("familie/sosialt")
    if k.innLib
        deler.Push("legemiddelliste")
    if k.jPa
        deler.Push("siste konsultasjon")
    if !deler.Length
        return "bare timekommentaren"
    s := ""
    for d in deler
        s .= (s = "" ? "" : ", ") d
    return s
}

LesKonfig() {
    k := {}
    k.vindu := IniRead(KONFIG, "webmed", "vindu", "WebMed ahk_exe TNW.Desktop.WPF.exe")
    k.eksempler := NormSti(FullSti(IniRead(KONFIG, "filer", "eksempler", "..\eksempler")))
    k.logg := NormSti(FullSti(IniRead(KONFIG, "filer", "logg", "..\logg")))
    k.jsonVedSending := Trim(IniRead(KONFIG, "filer", "json_ved_sending", "0")) == "1"
    k.hurtigtast := IniRead(KONFIG, "kjoring", "hurtigtast", "^+F6")
    k.avbryt := IniRead(KONFIG, "kjoring", "avbryt", "^!x")
    k.hurtigtastTekst := TastTekst(k.hurtigtast)
    k.avbrytTekst := TastTekst(k.avbryt)
    ; v0.5: kalibreringen (tasten som starter den, og tasten som merker et punkt)
    k.kalibrer := IniRead(KONFIG, "kjoring", "kalibrer", "^+F7")
    k.kalibrerTekst := TastTekst(k.kalibrer)
    ; v0.6.0: de nye tastene (tom verdi = tasten er av) og WebMeds tast for Avtaler
    k.tastLmg := Trim(IniRead(KONFIG, "kjoring", "legemiddelgjennomgang", "^+F9"))
    k.tastLimInn := Trim(IniRead(KONFIG, "kjoring", "lim_inn_melding", "^+F10"))
    k.tastRing := Trim(IniRead(KONFIG, "kjoring", "ring", "^+F11"))
    k.tastVideo := Trim(IniRead(KONFIG, "kjoring", "video", "^+F12"))
    k.tastNyInnsjekk := Trim(IniRead(KONFIG, "kjoring", "ny_innsjekk", "^+F8"))
    k.tastMeny := Trim(IniRead(KONFIG, "kjoring", "meny", "F11"))   ; v0.9.0: F11 (var Ctrl+Shift+F5)
    k.tastMenyMus := Trim(IniRead(KONFIG, "kjoring", "meny_mus", ""))
    for nk in ["tastLmg", "tastLimInn", "tastRing", "tastVideo", "tastNyInnsjekk", "tastMeny"]
        k.%nk "Tekst"% := k.%nk% = "" ? "(av)" : TastTekst(k.%nk%)
    k.avtalerTast := Trim(IniRead(KONFIG, "kjoring", "avtaler_tast", "{F3}"))
    k.avtalerTastTekst := TastTekst(k.avtalerTast)
    ; v0.6.0 (B2): meldingsvinduet i WebMed (AHK WinTitle), og om Notisblokk er lov under test
    k.meldingVindu := Trim(IniRead(KONFIG, "melding", "vindu", ""))
    k.meldingNotisblokk := Trim(IniRead(KONFIG, "melding", "tillat_notisblokk", "0")) == "1"
    ; v0.6.1: ring henter nummeret til pasienten fra «Send SMS» (WebMeds Ctrl+1)
    k.smsVindu := Trim(IniRead(KONFIG, "webmed", "sms_vindu", "Send SMS ahk_exe TNW.Desktop.WPF.exe"))
    k.smsTast := Trim(IniRead(KONFIG, "webmed", "sms_tast", "^1"))
    ; v0.8.0: WebMeds tast for meldingen til pasienten («Start Pasient Dialog», Ctrl+3)
    k.meldingTast := Trim(IniRead(KONFIG, "webmed", "melding_tast", "^3"))
    k.merk := IniRead(KONFIG, "kjoring", "merk", "F8")
    k.merkTekst := TastTekst(k.merk)
    k.kalVindu := Trim(IniRead(KONFIG, "kalibrering", "vindu", ""))
    dpi := Trim(IniRead(KONFIG, "kalibrering", "dpi", ""))
    k.kalDpi := dpi = "" ? 0 : Integer(dpi)
    k.kalDato := Trim(IniRead(KONFIG, "kalibrering", "dato", ""))
    k.kalPos := Trim(IniRead(KONFIG, "kalibrering", "posisjon", ""))
    k.ventVindu := Integer(IniRead(KONFIG, "tider", "vent_vindu_ms", "1500"))
    ; Høyst 60 timer: grensen for én bunke i Skrift
    k.maks := Min(60, Max(1, Integer(IniRead(KONFIG, "kjoring", "maks_timer", "40"))))
    k.kontroll := Integer(IniRead(KONFIG, "kjoring", "forhandskontroll", "1"))
    k.pAvtaler := Punkt(IniRead(KONFIG, "koordinater", "avtaler_meny", "482,67"))
    k.pNotat := Punkt(IniRead(KONFIG, "koordinater", "notatfelt", "1741,842"))
    k.pLukk := Punkt(IniRead(KONFIG, "koordinater", "lukk_forste_fane", "258,129"))
    k.lukkTast := Trim(IniRead(KONFIG, "kjoring", "lukk_tast", "!x"))
    k.lukkTastTekst := k.lukkTast = "" ? "" : TastTekst(k.lukkTast)
    k.ventJournal := Integer(IniRead(KONFIG, "tider", "vent_journal_ms", "1500"))
    k.pause := Integer(IniRead(KONFIG, "tider", "pause_mellom_timer_ms", "300"))
    k.utklipp := Integer(IniRead(KONFIG, "tider", "utklipp_timeout_ms", "2000"))
    k.ventLib := Integer(IniRead(KONFIG, "tider", "vent_legemiddelliste_ms", "8000"))
    ; v0.11.0 (Daniel 08.11): innholdet i dagslisten velges i [innhold] (og i menyen
    ; under Mer). Siste konsultasjon: [innhold] siste_konsultasjon, ellers den gamle
    ; nøkkelen [journal] siste_konsultasjon (v0.4). Bare nøyaktig 1 slår på.
    k.innTidl := InnholdBryter("tidligere_sykdommer")
    k.innFam := InnholdBryter("familie_sosialt")
    k.innLib := InnholdBryter("legemiddelliste")
    sk := Trim(IniRead(KONFIG, "innhold", "siste_konsultasjon", ""))
    k.jPa := sk != "" ? sk == "1" : Trim(IniRead(KONFIG, "journal", "siste_konsultasjon", "0")) == "1"
    k.jTyper := []
    for navn in StrSplit(IniRead(KONFIG, "journal", "typer", "Konsultasjon"), ",", " `t")
        if navn != ""
            k.jTyper.Push(StrLower(navn))
    k.jMaks := Max(1, Integer(IniRead(KONFIG, "journal", "maks_oppforinger", "30")))
    k.jRull := Max(1, Integer(IniRead(KONFIG, "journal", "rull_hakk", "10")))
    k.jFilter := Trim(IniRead(KONFIG, "journal", "kontaktfilter", "1")) == "1"
    k.jSkann := Integer(IniRead(KONFIG, "koordinater", "journal_skann_x", "2354"))
    k.jKlikk := Integer(IniRead(KONFIG, "koordinater", "journal_klikk_x", "2860"))
    jy := Punkt(IniRead(KONFIG, "koordinater", "journal_y", "358,1393"))
    k.jTopp := jy.x, k.jBunn := jy.y
    k.pKontakt := Punkt(IniRead(KONFIG, "koordinater", "journal_kontaktfilter", "2691,367"))
    k.jFarge := Integer("0x" Trim(IniRead(KONFIG, "koordinater", "journal_farge", "E3E3E3")))
    LesSending(k)
    return k
}

; Leses på nytt ved hver kjøring: [skrift] send og tokenfil, [kjoring] testdato.
; [skrift]: bare nøyaktig 1 slår sending på; alt annet (også tom/manglende) er av.
; sendUkjent = lengden på en verdi som verken er 0 eller 1 (verdien logges ikke).
LesSending(kfg := "") {
    ; (AHK skiller ikke store og små bokstaver i navn: k og K er samme variabel)
    if !IsObject(kfg)
        kfg := K
    sendVerdi := Trim(IniRead(KONFIG, "skrift", "send", "0"))
    kfg.send := sendVerdi == "1"
    kfg.sendUkjent := (sendVerdi == "0" || sendVerdi == "1") ? 0 : Max(1, StrLen(sendVerdi))
    tf := Trim(IniRead(KONFIG, "skrift", "tokenfil", ""))
    kfg.tokenfil := tf = "" ? "" : FullSti(tf)
    ; v0.11.1: proxyen for kallene (tom = Windows' innstillinger, «ingen» = direkte, «vert:port»)
    kfg.proxy := Trim(IniRead(KONFIG, "skrift", "proxy", ""))
    kfg.testdato := Trim(IniRead(KONFIG, "kjoring", "testdato", ""))
    ; v0.6.0: egne brytere for de nye funksjonene; send gjelder bare dagslisten
    kfg.sendLmg := Trim(IniRead(KONFIG, "skrift", "send_lmg", "0")) == "1"
    kfg.sendKommando := Trim(IniRead(KONFIG, "skrift", "send_kommando", "0")) == "1"
}

FullSti(p) => RegExMatch(p, "^[A-Za-z]:\\|^\\\\") ? p : A_ScriptDir "\" p

; «C:\x\skript\..\eksempler» -> «C:\x\eksempler» (v0.10.2, så stiene i hintene er lesbare)
NormSti(p) {
    buf := Buffer(2 * 32768)
    n := DllCall("GetFullPathNameW", "Str", p, "UInt", 32768, "Ptr", buf, "Ptr", 0, "UInt")
    return n ? StrGet(buf, n, "UTF-16") : p
}

Punkt(s) {
    a := StrSplit(s, ",", " ")
    return {x: Integer(a[1]), y: Integer(a[2])}
}

TastTekst(t) {
    s := ""
    ; {F3} og liknende: navnet på tasten uten klammer
    if RegExMatch(t, "^([\^!+#]*)\{(\w+)\}$", &m)
        t := m[1] m[2]
    loop parse t {
        switch A_LoopField {
            case "^": s .= "Ctrl+"
            case "!": s .= "Alt+"
            case "+": s .= "Shift+"
            case "#": s .= "Win+"
            default: s .= StrUpper(A_LoopField)
        }
    }
    return s
}
