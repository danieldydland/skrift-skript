# skrift-skript

Skript og eksempler som bruker [integrasjons-API-et i Skrift.md](https://app.skrift.md/docs/integrasjoner):
små programmer på din egen PC som lager innsjekk med lenke og PIN-kode, legger bakgrunn fra
journalsystemet i innboksen, ber den åpne Skrift-fanen ringe opp, eller lager et videorom. Alt
skjer med ditt eget personlige token, som aldri kan lese pasientdata.

**Skriptene her er ikke en del av Skrift.md som medisinsk utstyr.** De er fellesskapets verktøy,
under MIT-lisens, uten garanti. Skrift.md feilsøker dem ikke for deg, men vi hører gjerne hva du
får til og hva som mangler: kontakt@skrift.md.

## Innholdet

| Mappe | Hva | Journalsystem |
|---|---|---|
| `webmed/skrift-webmed/` | Det fulle skriptet for WebMed: dagslisten til innboksen, innsjekk og legemiddelgjennomgang fra timeboka og journalen, ring, videorom, meny på F11. Les `START-HER.md` der | WebMed (skrivebordsprogram) |
| `eksempler/` | Tre små AutoHotkey v2-skript som virker mot et hvilket som helst Windows-program: ny innsjekk med lenke og PIN til utklippstavlen, videorom til utklippstavlen, ring opp et markert nummer | Alle |
| `index.json` | Listen Skrift viser på utviklersiden: navn, journalsystem, versjon, dato testet, SHA-256 og lenke | |
| `verktoy/sjekk.py` | Sjekken som kjører i GitHub Actions ved hver endring (se under) | |

Last ned alt som zip: **Code → Download ZIP** på GitHub, eller
<https://github.com/danieldydland/skrift-skript/archive/refs/heads/main.zip>. Pakk ut, og bruk mappen
du trenger.

## Slik kommer du i gang

1. Be om tilgang til integrasjons-API-et (kontakt@skrift.md), så dukker **Integrasjoner** opp under
   Innstillinger, Konto og sikkerhet i Skrift. Lag et token der med rettighetene skriptet trenger.
2. Installer [AutoHotkey v2](https://www.autohotkey.com/) (versjon 2.0.18 eller nyere).
3. Legg tokenet i filen `%LOCALAPPDATA%\Skrift\skrift-token.ini` med to linjer:

   ```ini
   [skrift]
   token=skr_… (bare tokenet på linjen)
   ```

   WebMed-skriptet lager filen for deg i veiviseren ved første kjøring. Eksemplene leser den samme
   filen. Tokenet skal aldri ligge i selve skriptet eller i noe du deler.
4. Dobbeltklikk skriptet. Hurtigtastene står i hodet på hver fil.

## Regler for skript i dette repoet

Reglene gjelder alle bidrag og sjekkes så langt det går automatisk:

- Tokenet leses fra en egen fil eller miljøvariabel, aldri fra skriptet. Ingen `skr_`-verdier i repoet.
- Pasientopplysninger sendes ikke andre steder enn til journalsystemet og Skrift. Ingen nettverkskall
  til andre verter enn `api.skrift.md` (og `localhost` for testing), og omdirigeringer følges aldri.
- Ingen skriving i journalsystemet uten brukerens tastetrykk. Innliming skjer bare når brukeren selv
  trykker, én gang, i meldingen innsjekken ble laget for.
- Tekst skrives med `SendText`, aldri tolket `Send` (bare hurtigtaster går med `Send`).
- Bekreftelse før noe sendes eller limes inn; nummeret vises før `ring` sendes.
- Navn sendes ikke, verken pasientens eller helsepersonells. Initialer, fødselsdato, kjønn og alder
  holder til kontrollen i innboksen.
- Skriptet stopper ved ukjent vindu, og har en egen tast som avbryter.
- Hvert skript har en topptekst med versjon, journalsystem, dato testet, og setningen «Ikke en del
  av Skrift.md som medisinsk utstyr».
- Ingen tankestreker i tekst brukeren ser.

## Bidra

Åpne en pull request, eller send filen til kontakt@skrift.md så legger vi den inn. Alt som blir synlig i
Skrift er sett gjennom og prøvd i et fiktivt miljø først, og står i `index.json` med SHA-256. Med
bidraget gir du det under MIT-lisensen.

Sjekken i `verktoy/sjekk.py` kjører ved hver push og pull request (`python3 verktoy/sjekk.py`):
`index.json` er gyldig og hver SHA-256 stemmer med filen, ingen tokenverdier, ingen nettadresser utenfor
skrift.md, localhost, github.com og autohotkey.com, og toppteksten står i hvert skript. Oppdater
`index.json` med `python3 verktoy/lag-index.py` etter at du har endret en fil.

## Lisens

MIT, se `LICENSE`. UIA-biblioteket i `webmed/skrift-webmed/Lib/UIA.ahk` er Descolada sin
UIA-v2 under egen lisens (`Lib/UIA-LICENSE.txt`).
