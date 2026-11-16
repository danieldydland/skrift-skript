#!/usr/bin/env python3
"""Skriver index.json fra listen under: SHA-256 regnes ut for hovedfilen i hvert skript.

Kjør fra roten av repoet: python3 verktoy/lag-index.py
Rediger listen SKRIPT når et skript kommer til eller får ny versjon.
"""
import hashlib, json, pathlib, datetime, re

ROT = pathlib.Path(__file__).resolve().parent.parent
GITHUB = "https://github.com/danieldydland/skrift-skript"

SKRIPT = [
    {
        "id": "webmed-skrift",
        "navn": "Skrift for WebMed",
        "beskrivelse": "Dagslisten til innboksen, innsjekk og legemiddelgjennomgang fra timeboka eller journalen, ring og videorom. Meny på F11, veiviser ved første kjøring, kalibrering av skjermpunktene.",
        "journalsystem": "WebMed",
        "mappe": "webmed/skrift-webmed",
        "hovedfil": "webmed/skrift-webmed/dagsliste.ahk",
        "rettigheter": ["innsjekk", "postkasse", "sms", "kommando"],
        "krav": "Windows 10 eller 11, AutoHotkey v2.0.18, WebMed 55",
    },
    {
        "id": "eksempel-ny-innsjekk",
        "navn": "Ny innsjekk, lenke og PIN til utklippstavlen",
        "beskrivelse": "Ctrl+Shift+F8: spør om en referanse, lager innsjekken og legger meldingen til pasienten på utklippstavlen.",
        "journalsystem": "Alle",
        "mappe": "eksempler",
        "hovedfil": "eksempler/ny-innsjekk-lim-inn.ahk",
        "rettigheter": ["innsjekk"],
        "krav": "Windows, AutoHotkey v2",
    },
    {
        "id": "eksempel-videorom",
        "navn": "Videorom, lenken til utklippstavlen",
        "beskrivelse": "Ctrl+Shift+F12: lager et videorom i Skrift og legger pasientlenken på utklippstavlen.",
        "journalsystem": "Alle",
        "mappe": "eksempler",
        "hovedfil": "eksempler/videorom-lim-inn.ahk",
        "rettigheter": ["kommando"],
        "krav": "Windows, AutoHotkey v2",
    },
    {
        "id": "eksempel-ring",
        "navn": "Ring opp et markert nummer",
        "beskrivelse": "Ctrl+Shift+F11: kopierer det markerte nummeret, viser det og ber Skrift-fanen ringe når du bekrefter.",
        "journalsystem": "Alle",
        "mappe": "eksempler",
        "hovedfil": "eksempler/ring-markert-nummer.ahk",
        "rettigheter": ["kommando"],
        "krav": "Windows, AutoHotkey v2",
    },
]


def hode(sti: pathlib.Path) -> dict:
    """Versjon og dato testet fra toppteksten i skriptet."""
    tekst = sti.read_text(encoding="utf-8", errors="replace")[:4000]
    versjon = re.search(r"Versjon:\s*([0-9][0-9.]*)", tekst) or re.search(r'SKRIPT_VERSJON\s*:=\s*"([0-9.]+)"', tekst)
    testet = re.search(r"Testet:\s*(\d{4}-\d{2}-\d{2})", tekst)
    return {"versjon": versjon.group(1) if versjon else "", "datoTestet": testet.group(1) if testet else ""}


def main() -> None:
    ut = []
    for s in SKRIPT:
        fil = ROT / s["hovedfil"]
        sha = hashlib.sha256(fil.read_bytes()).hexdigest()
        h = hode(fil)
        ut.append({
            **s,
            "versjon": h["versjon"],
            "datoTestet": h["datoTestet"],
            "sha256": sha,
            "lenke": f"{GITHUB}/tree/main/{s['mappe']}",
            "fil": f"{GITHUB}/blob/main/{s['hovedfil']}",
        })
    data = {"versjon": 1, "oppdatert": datetime.date.today().isoformat(), "nedlasting": f"{GITHUB}/archive/refs/heads/main.zip", "skript": ut}
    (ROT / "index.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"index.json: {len(ut)} skript")


if __name__ == "__main__":
    main()
