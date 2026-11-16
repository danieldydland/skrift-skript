# Skrift-skriptet for WebMed (v0.10.4): oppsett på en ny PC

Skriptet er Eirskrifts eget verktøy for WebMed, ikke en del av Skrift.md som medisinsk utstyr. Det
leser i WebMed med tastatur, mus og utklippstavlen slik du selv gjør, lagrer aldri noe i journalen,
og trykker aldri Send i en melding.

## 1. Installer AutoHotkey v2

Last ned AutoHotkey v2 (testet med 2.0.18) fra autohotkey.com og installer som vanlig bruker.

## 2. Pakk ut

Pakk ut mappen `skrift-webmed` et sted uten synkronisering (for eksempel `C:\Skrift\skrift-webmed`).
Slå av utklippshistorikk (Win+V) og synkronisering av utklippstavlen i Windows-innstillingene.

Mappen inneholder `dagsliste.ahk` (skriptet), `Lib\` (bibliotekene og malen `config-standard.ini`), `logg\` og `eksempler\`
(fylles av skriptet), `verktoy\` (sjekkverktøy, bare lesing) og `LES-MEG.md` (alt om skriptet).
`config.ini` lages av skriptet ved første kjøring (fra malen i `Lib\`). En senere oppdatering pakkes ut
rett over mappen: `config.ini`, tokenfilen og loggen røres ikke.

## 3. Start skriptet: veiviseren gjør resten

Start WebMed og logg inn. Dobbeltklikk `dagsliste.ahk`. Første gang kommer en veiviser:

1. **Tokenet.** Veiviseren forklarer hvor det lages (Skrift → Innstillinger → Integrasjoner → Nytt token
   med rettighetene innsjekk, postkasse, sms og kommando) og tar det imot i et skjult felt. Det lagres i
   `%LOCALAPPDATA%\Skrift\skrift-token.ini`, utenfor skriptmappen, og prøves mot Skrift med en gang.
2. **Sending.** «Normal bruk» (alt går til Skrift) eller «Tørrkjøring først» (ingenting sendes; du slår på
   senere i `config.ini` under `[skrift]`).
3. **Kalibreringen.** Skriptet måler fem punkter i WebMed på din skjerm. Ha en fiktiv testpasient framme
   i journalen og pek der veiviseren ber om det (F8 for hvert punkt). Endrer du skjerm eller skalering,
   ber skriptet om ny kalibrering.
4. **Oversikten.** Til slutt viser veiviseren hva skriptet kan fra hver flate og tasten som åpner menyen
   (F11). Vil du ha en annen tast, velger du den der; F1 til F10 og F12 er WebMeds egne, så en av dem
   tar over WebMeds funksjon mens skriptet kjører.

Veiviseren finnes også senere: F11 → Mer → Oppsett.

## 4. Bruk

**F11** åpner menyen der du står (tallet velger): 1 legemiddelgjennomgang, 2 innsjekk, 3 videorom,
4 ring, 5 lim inn meldingen, 6 dagslisten, 7 kalibrer, 8 avbryt. Linjer som ikke passer der du står, er
grå med grunnen. Ctrl+Alt+X avbryter en kjøring. Alt står i `LES-MEG.md`.

- Dagslisten kjøres når du er ferdig for dagen og PC-en står i ro; ikke rør mus eller tastatur mens den
  går. Med sending på lagres ingenting på PC-en: listen holdes i minnet og sendes. Bare en tørrkjøring
  skriver `eksempler\dagsliste-<dato>.json`, så du kan se hva som ville blitt sendt.
- Kontroller nummeret før du sier ja til ring: «Send SMS» i WebMed kan vise nummeret fra timen når
  pasienten mangler eget nummer.
- Ha ikke andre vinduer over Løpende journal når skriptet kjører.

## Hjelp

`verktoy\patienttext-sjekk.ahk` viser om en kopi fra WebMed har pasient-ID, `verktoy\kal-sjekk.ahk` viser
hva kalibreringen ser, `verktoy\avslutt-skript.ahk` avslutter skriptet. Alt er bare lesing, og det de
skriver, havner i `logg\`. Loggen har aldri navn, journaltekst eller token.
