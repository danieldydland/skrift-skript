# Eksemplene

Tre små AutoHotkey v2-skript som virker mot et hvilket som helst Windows-program. De leser tokenet
fra `%LOCALAPPDATA%\Skrift\skrift-token.ini` (to linjer: `[skrift]` og `token=skr_…`), den samme
filen som WebMed-skriptet lager i veiviseren. `Lib\skrift.ahk` er felles: tokenet, kallet til Skrift
og litt JSON.

| Skript | Tast | Rettighet | Hva |
|---|---|---|---|
| `ny-innsjekk-lim-inn.ahk` | Ctrl+Shift+F8 | innsjekk | Spør om en referanse, lager innsjekken og legger meldingen til pasienten (lenke og PIN-kode) på utklippstavlen. Du limer inn med Ctrl+V, én gang, i meldingen til pasienten |
| `videorom-lim-inn.ahk` | Ctrl+Shift+F12 | kommando | Lager et videorom og legger pasientlenken på utklippstavlen. Rommet står i Skrift under Video |
| `ring-markert-nummer.ahk` | Ctrl+Shift+F11 | kommando | Kopierer det markerte nummeret, viser det og spør, og ber Skrift-fanen ringe. Du klikker Ring i Skrift |

Hurtigtastene er valgt fordi Ctrl+Shift+F5 til F12 er ledige i de fleste journalsystemer. Bytt dem
øverst i filen om de kolliderer. Ingenting limes inn av seg selv, og ingenting ringes uten at du
bekrefter.
