# Skrift for WebMed (v0.11.2)

AutoHotkey v2-skript som kobler WebMed (skrivebordsprogrammet) til Skrift.md gjennom ditt eget
integrasjonstoken: dagens timeliste med bakgrunn fra journalen til innboksen i Skrift, innsjekk og
legemiddelgjennomgang for en time eller for pasienten du står på, oppringing og videorom. Alt skjer med
tastatur og mus slik du selv ville gjort det, og ingenting lagres i WebMed.

**Ikke en del av Skrift.md som medisinsk utstyr.** Skriptet er fellesskapets verktøy under MIT-lisens,
uten garanti. Skrift feilsøker det ikke for deg, men hører gjerne hva du får til: kontakt@skrift.md.

Nytt på en PC: les `START-HER.md` først. Oppdatering: pakk ut over mappen; `config.ini`, tokenfilen
og loggen røres ikke.

## Forutsetninger

| Krav | Prøvd med |
|---|---|
| Windows 10 eller 11, ulåst, ingen andre bruker mus eller tastatur under en kjøring | Windows 10 og 11 |
| AutoHotkey v2 | 2.0.18 |
| WebMed (skrivebordsprogrammet), innlogget | 55.0.7 og 55.0.8 |
| Avtaler i dagsvisning som liste, egen avtalebok, for dagslisten | |
| Skjerm: kalibreres hos deg (se «Kalibrering»). Flere skjermer og 125 % skalering virker etter kalibrering | 3440 x 1440 ved 100 % og 125 % |
| Et integrasjonstoken fra Skrift (Innstillinger, Integrasjoner) med rettighetene du vil bruke | innsjekk, postkasse, sms, kommando |

Ingen administratorrettigheter trengs. UIA-biblioteket i `Lib\UIA.ahk` er Descolada sin UIA-v2
(MIT, `Lib\UIA-LICENSE.txt`).

## Oppsett

1. Dobbeltklikk `dagsliste.ahk`. Første gang lages `config.ini` fra malen i `Lib\`, og veiviseren
   starter: den forklarer tokenet, tar det imot i et skjult felt, legger det i
   `%LOCALAPPDATA%\Skrift\skrift-token.ini` (utenfor skriptmappen, så det aldri havner i en kopi av
   mappen) og prøver det mot Skrift.
2. Velg bryterne: normal bruk (dagslisten, innsjekk og kommandoer sendes) eller tørrkjøring
   (ingenting sendes; dagslisten skrives til en fil du kan se på).
3. Kalibrer skjermpunktene (se under) med en fiktiv testpasient åpen.
4. Veiviseren slutter med en oversikt over hva skriptet kan, og menytasten (F11; velg en annen om
   F11 er opptatt hos deg). Alt kan endres senere i `config.ini` eller fra menyen (Mer, Oppsett).

Bryterne i `config.ini` under `[skrift]`: `send` (dagslisten), `send_lmg` (innsjekk og
legemiddelgjennomgang) og `send_kommando` (ring, videorom). Bare nøyaktig `1` slår på; en kommentar på
samme linje som verdien gjør den ugyldig.

## Menyen og tastene

Trykk **F11** der du står. Menyen kommer ved musepekeren, lik overalt, og tallet velger linjen:

| Tall | Hva | Hvor |
|---|---|---|
| 1 | Legemiddelgjennomgang for en time, eller for pasienten du står på | Avtaler, journalen |
| 2 | Innsjekk (time eller skjema) for en time, eller for pasienten du står på | Avtaler, journalen |
| 3 | Videorom: lenken til utklippstavlen, og inn i meldingen til pasienten | journalen, meldingen |
| 4 | Ring pasienten via Skrift (nummeret fra «Send SMS»), eller et markert nummer | journalen, meldingen, utenfor WebMed |
| 5 | Lim inn meldingen til pasienten (lenke og PIN-kode) | meldingen, journalen (åpner den) |
| 6 | Dagslisten til Skrift | Avtaler, journalen |
| 7 | Kalibrer skjermpunktene | WebMed |
| 8 | Avbryt kjøringen | alltid |

Grå linje betyr at valget ikke passer der du står; grunnen står bak linjen. «Mer» har loggen for
i dag, `config.ini`, hjelp, oppsettet og avslutt; ikonet nede til høyre har det samme. Hurtigtastene
Ctrl+Shift+F6 til F12 og Ctrl+Alt+X (avbryt) virker også, og står i menyen; de kan endres eller tømmes i
`config.ini` under `[kjoring]`.

## Dagslisten (6)

Skriptet leser timene for datoen Avtaler viser (i dag eller senere, for eksempel morgendagens liste
kvelden før), åpner hver pasient, henter tidligere sykdommer, familie/sosialt, legemiddellisten og
siste konsultasjon fra Løpende journal, lukker pasienten igjen, og sender alt til innboksen i Skrift i én
bunke. Postene vises under «I dag» i Skrift på timedagen og lever til kl. 02:00 natten etter.

- Boksen «Dagslisten til Skrift» viser datoen før noe leses. Ikke rør mus eller tastatur under
  kjøringen; Ctrl+Alt+X avbryter mellom to steg. Omtrent 8 sekunder per pasient.
- Navn sendes ikke: referansen er klokkeslett og initialer, og fødselsdato, kjønn og alder følger
  med til kontrollen i Skrift. Fødselsnummer fjernes. Pasientens navn i fritekst byttes med
  «[pasient]».
- Ved sending lagres ingenting på PC-en. Ved tørrkjøring skrives listen til `eksempler\`
  (`dagsliste-ÅÅÅÅ-MM-DD.json`), så du kan se hva som ville blitt sendt.
- En ny kjøring samme dag oppdaterer postene i Skrift (ingen dobbeltposter); en time som alt er
  startet i Skrift, røres ikke. Skrift tar imot høyst fem dagslister i timen.

### Velg hva dagslisten henter

Under **Mer, Innhold i dagslisten** (også i ikonmenyen) krysser du av hva skriptet skal hente fra
journalen for hver time: tidligere sykdommer, familie/sosialt, legemiddellisten og siste konsultasjon
fra Løpende journal. Timekommentaren fra Avtaler er alltid med. Jo mindre som hentes, jo raskere går
det; siste konsultasjon er det som tar lengst tid og det eneste som klikker i Løpende journal. Valget
lagres i `config.ini` under `[innhold]` og gjelder fra neste kjøring. Legemiddelgjennomgangen fra
menyen henter alltid legemiddellisten, uansett valget her.

## Innsjekk og legemiddelgjennomgang (1 og 2)

Fra Avtaler velger du timen i en liste; fra journalen gjelder det pasienten som er åpen, med
referansen «initialer fødselsdato». Legemiddelgjennomgangen henter legemiddellisten fra journalen
(LIB) og sender den med innsjekken, så pasienten svarer rad for rad; listen leses bare når Skrift
kjenner den igjen, ellers får du beskjed og lager innsjekken i Skrift. Skriptet viser så meldingen til
pasienten med lenke og PIN-kode; 5 limer den inn i meldingsvinduet i WebMed (Ctrl+3), bare der, bare
én gang, og trykker aldri «Send».

## Ring og videorom (3 og 4)

Ring sender nummeret til den åpne Skrift-fanen; du ser nummeret og kilden før noe sendes, og
oppringingen skjer først når du klikker Ring i Skrift. Videorom lager rommet i Skrift og legger
pasientlenken på utklippstavlen; fra journalen tilbyr skriptet å åpne meldingen til pasienten med
lenken limt inn. Du sender selv.

## Kalibrering (7)

Skriptet klikker noen få steder i WebMed der tilgjengelighetslaget ikke hjelper (menyvalget
«Avtaler», notatfeltet, overskriftene og boksen «Kontakt» i Løpende journal). Hvor de står, avhenger av
skjermen, skaleringen og panelbreddene, så de måles hos deg: åpne en fiktiv testpasient med minst én
oppføring i Løpende journal, trykk 7 (eller Ctrl+Shift+F7), pek med musen på det hintet ber om og trykk
F8 (eller Ctrl+Shift+M, som ikke trenger Fn på en bærbar PC), fem ganger. Esc avbryter uten å endre
noe. Skriptet prøver punktene før de skrives til `config.ini`. Kalibrer på nytt når skjermen,
skaleringen eller WebMed-vinduet endres; skriptet stopper selv og sier fra når det ser at noe er endret.

Kalibreringen er ferdig først når hintet sier «kalibrert for WebMed …». Stopper den underveis, kommer
en boks som sier hvorfor, med «Prøv igjen» og «Åpne loggen», og ingenting er endret. De vanligste
grunnene: merketasten kom ikke fram innen to minutter (hold Fn sammen med F8, eller bruk Ctrl+Shift+M),
Esc ble trykket, eller pekeren sto ikke på det hintet ba om.

## Når skriptet stopper

Meldingen står i hintet nede til venstre (rød stripe) og i loggen (`logg\ÅÅÅÅ-MM-DD.txt`). Står en
pasient åpen når det stopper, sier hintet hvilken time; sjekk alltid notatfeltet før du lukker den
pasienten selv. Vanlige stopp:

| Melding | Hva du gjør |
|---|---|
| Tokenet virker ikke, eller mangler en rettighet | Lag et nytt token i Skrift (Innstillinger, Integrasjoner) og legg det inn fra menyen (Mer, Oppsett) |
| Skriptet er ikke kalibrert for denne skjermen | Kalibreringen er ikke gjort, eller den stoppet før den var ferdig. Stoppet den, står grunnen på linjen under meldingen («Siste kalibrering stoppet kl. …») og i loggen. Åpne en fiktiv testpasient og kalibrer (7) |
| WebMed har en annen størrelse eller skalering enn ved kalibreringen | Flytt WebMed til skjermen du kalibrerte på, eller kalibrer på nytt. Er Windows-skaleringen endret: start WebMed på nytt først |
| Avtaler viser en dato som er passert | Velg i dag eller en senere dato |
| «Lukk pasienter» viser flere pasienter | Ha bare én pasient framme, og kjør på nytt |
| Notatfeltet har tekst fra før (kladd) | Pasienten står åpen med kladden urørt. Avslutt kladden selv |
| Legemiddellisten kom ikke | Pasienten står åpen. Sjekk notatet, tøm det om listen har kommet, og lukk selv |
| Ukjent vindu eller uventet meldingsboks | Les dialogen i WebMed og håndter den selv |
| Skrift er ikke åpent (ring, videorom) | Åpne Skrift i nettleseren og prøv igjen |

## Personvern

- Nettverk bare til `https://api.skrift.md`, og bare når bryterne er på og du har trykket en tast.
  Omdirigeringer følges aldri, så tokenet og postene går ikke andre steder. Går nettet ditt via en
  proxy, brukes den slik Windows er satt opp (eller `[skrift] proxy` i `config.ini`).
- Loggen har referanse (klokkeslett og initialer, eller initialer med «[fdato]»), tegnlengder, tider og
  statuskoder, aldri journaltekst, navn, fødselsdato, pasient-ID eller token.
- PIN-koden, lenken, meldingen og pasientens ID står bare i minnet. Navnet og fødselsnummeret i tittelen
  på meldingsvinduet brukes bare til kontrollen av at det er riktig pasient.
- Kopieringen går via utklippstavlen og settes tilbake etterpå. Slå av utklippshistorikk (Win+V) og
  synkronisering av utklippstavlen i Windows på PC-er som kjører skriptet.
- Skriptet lagrer aldri noe i WebMed, og limer inn bare når du trykker tasten.

## Vanlige spørsmål

**To skjermer, WebMed på skjerm 2.** Det går. Kalibrer med WebMed på den skjermen du bruker det på
(skriptet maksimerer WebMed der det står), og la det stå der når du kjører. Står WebMed på en annen
skjerm ved en kjøring, flytter skriptet det til skjermen du kalibrerte på og setter det tilbake etterpå.
Meldingen «Skriptet er ikke kalibrert for denne skjermen» ved oppstart betyr bare at kalibreringen
ikke er gjort ennå; den forsvinner når den er gjort. Hintet nede til venstre står på skjermen WebMed
står på. Loggen viser skjermene skriptet ser («Skjermer: …»), så send den om noe ikke stemmer.

**Jeg har kalibrert, men får fortsatt «Skriptet er ikke kalibrert for denne skjermen».** Da ble
kalibreringen ikke fullført: punktene lagres først når alle fem er merket og skriptet har prøvd dem.
Før v0.11.2 kunne dette skje uten at du så det, når kalibreringen ble startet fra oppsettet første gang:
boksen «Ferdig» kom opp samtidig, og grunnen til stoppet ble borte. Oppdater til v0.11.2, åpne en fiktiv
testpasient og kalibrer på nytt fra menyen (7). Stopper den, sier boksen hvorfor.

**Funksjonstastene krever Fn på laptopen.** Hold Fn sammen med F8 når du merker et punkt, og med F11
for menyen. Under kalibreringen kan du også merke med Ctrl+Shift+M, uten å endre noe. Eller bytt tastene i `config.ini` under `[kjoring]`: `merk=F8` kan for eksempel bli
`merk=^+m` (Ctrl+Shift+M), og `meny=F11` kan bli `meny=^+k` (Ctrl+Shift+K). Tastene skrives slik
AutoHotkey skriver dem: `^` er Ctrl, `+` er Shift, `!` er Alt. Menytasten kan også velges fra menyen
(Mer, Oppsett). Ikke bruk Ctrl+Alt sammen med en bokstav: det er AltGr på norsk tastatur.

**Bare dagslisten og legemiddelgjennomgang, uten klikkene i Løpende journal.** Fjern krysset for
siste konsultasjon under **Mer, Innhold i dagslisten** (eller sett `siste_konsultasjon=0` under
`[innhold]` i `config.ini`). Da klikker skriptet ikke i Løpende journal. Kalibreringen trengs likevel
for menyvalget «Avtaler» og notatfeltet; pek på de fem punktene som før, de tre siste brukes bare når
siste konsultasjon er på.

**«Skrift godtok ikke tokenet: (0x80072F0D) Sertifiseringsinstansen er ugyldig», eller tidsavbrudd,
på et nett med proxy (for eksempel NHN-nett).** Skriptet følger Windows' proxyinnstillinger (PAC-skript
eller manuell proxy) fra v0.11.1, og loggen viser «Nett: proxy …» eller «direkte». Virker det likevel
ikke, finn proxyen nettet ditt bruker (IT, eller åpne PAC-adressen fra Innstillinger, Proxy i en
nettleser) og sett `proxy=vert:port` under `[skrift]` i `config.ini`. Tokenet er ikke problemet når
meldingen handler om sertifikat eller nett.

**Legemiddellisten ble avvist med 422 LISTE_IKKE_GJENKJENT.** Skrift leser listen bare når den kjenner
formatet igjen, for å aldri gjette på et legemiddel. Et bruksområde skrevet som fritekst med små
bokstaver i WebMed ble ikke gjenkjent før 8. november 2026; nå leses det. Ellers står radnummeret i
meldingen, og du kan lage innsjekken i Skrift i stedet.

## Filene

| Fil | Hva |
|---|---|
| `dagsliste.ahk` | Skriptet. Start det; ikonet nede til høyre viser at det kjører |
| `config.ini` | Dine innstillinger: brytere, taster, innholdet i dagslisten, mapper, kalibreringen. Lages fra `Lib\config-standard.ini` ved første kjøring |
| `Lib\` | Delene av skriptet (dialoger, meny, oppsett, innsjekk, kommandoer, journal, kalibrering, PatientText) og UIA-biblioteket |
| `logg\` | Én loggfil per dag |
| `eksempler\` | Dagslisten som fil, bare ved tørrkjøring |
| `verktoy\` | Sjekkverktøy for den som feilsøker (bare lesing): `patienttext-sjekk.ahk`, `uia-kartlegg.ahk`, `uia-punkt.ahk`, `kal-sjekk.ahk`, `avslutt-skript.ahk` |
