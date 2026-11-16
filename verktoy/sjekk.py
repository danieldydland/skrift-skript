#!/usr/bin/env python3
"""Sjekken som kjører i GitHub Actions: index.json, tokenverdier, nettadresser og topptekst.

Kjør fra roten av repoet: python3 verktoy/sjekk.py  (avslutter med 1 ved feil)
"""
import hashlib, json, pathlib, re, sys

ROT = pathlib.Path(__file__).resolve().parent.parent
TOKEN = re.compile(r"skr_[A-Za-z0-9_-]{16,}")
URL = re.compile(r"https?://([A-Za-z0-9.-]+)")
TILLATTE_VERTER = {"api.skrift.md", "app.skrift.md", "skrift.md", "www.skrift.md", "localhost", "github.com", "www.autohotkey.com", "autohotkey.com", "raw.githubusercontent.com", "opensource.org"}
TOPPTEKST = ("Versjon:", "Journalsystem:", "Testet:", "Ikke en del av Skrift.md som medisinsk utstyr")
# Biblioteker fra andre (egen lisens, egen topptekst; lenkene i kommentarene er dokumentasjon, ikke kall)
UNNTAK = {"webmed/skrift-webmed/Lib/UIA.ahk"}
# Filer som ikke er skript med egen topptekst (hjelpefiler i WebMed-pakken har sin egen form)
SKRIPT_MED_TOPPTEKST = re.compile(r"^(eksempler/[^/]+\.ahk|eksempler/Lib/skrift\.ahk|webmed/skrift-webmed/dagsliste\.ahk)$")


def feil(liste, melding):
    liste.append(melding)
    print("FEIL  " + melding)


def main() -> int:
    feilene = []
    tekstfiler = [p for p in ROT.rglob("*") if p.is_file() and p.suffix.lower() in {".ahk", ".ini", ".md", ".json", ".py", ".yml", ".txt"} and ".git" not in p.parts]
    for p in tekstfiler:
        rel = p.relative_to(ROT).as_posix()
        tekst = p.read_text(encoding="utf-8", errors="replace")
        if TOKEN.search(tekst):
            feil(feilene, f"{rel}: ser ut til å inneholde et token (skr_…)")
        for m in (URL.finditer(tekst) if rel not in UNNTAK else []):
            vert = m.group(1).lower()
            if vert not in TILLATTE_VERTER:
                feil(feilene, f"{rel}: nettadresse utenfor de tillatte vertene: {vert}")
        if SKRIPT_MED_TOPPTEKST.match(rel) and rel not in UNNTAK:
            hode = tekst[:4000]
            for krav in TOPPTEKST:
                if krav not in hode and not (krav == "Versjon:" and "SKRIPT_VERSJON" in hode):
                    feil(feilene, f"{rel}: toppteksten mangler «{krav}»")
    try:
        data = json.loads((ROT / "index.json").read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        feil(feilene, f"index.json kan ikke leses: {e}")
        data = {"skript": []}
    for s in data.get("skript", []):
        for felt in ("id", "navn", "beskrivelse", "journalsystem", "versjon", "datoTestet", "hovedfil", "sha256", "lenke"):
            if not s.get(felt):
                feil(feilene, f"index.json {s.get('id', '?')}: feltet «{felt}» mangler")
        fil = ROT / s.get("hovedfil", "")
        if not fil.is_file():
            feil(feilene, f"index.json {s.get('id', '?')}: hovedfilen finnes ikke: {s.get('hovedfil')}")
        elif hashlib.sha256(fil.read_bytes()).hexdigest() != s.get("sha256"):
            feil(feilene, f"index.json {s.get('id', '?')}: SHA-256 stemmer ikke med {s.get('hovedfil')} (kjør verktoy/lag-index.py)")
        for tegn in ("–", "—"):
            if tegn in (s.get("navn", "") + s.get("beskrivelse", "")):
                feil(feilene, f"index.json {s.get('id', '?')}: tankestrek i navn eller beskrivelse")
    print("ALT OK" if not feilene else f"{len(feilene)} feil")
    return 1 if feilene else 0


if __name__ == "__main__":
    sys.exit(main())
