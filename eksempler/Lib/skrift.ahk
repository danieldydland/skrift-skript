; =============================================================================
; Lib\skrift.ahk  -  felles for eksemplene: tokenet, kallet til Skrift, JSON
; Versjon: 1.1.0  Journalsystem: alle  Testet: 2026-11-09 (syntaks, ikke mot WebMed)
; Ikke en del av Skrift.md som medisinsk utstyr.
; =============================================================================
; Tokenet ligger i %LOCALAPPDATA%\Skrift\skrift-token.ini (to linjer: [skrift] og
; token=skr_…), samme fil som WebMed-skriptet lager i veiviseren. Aldri i skriptet.

global SKRIFT_BASE := "https://api.skrift.md/api/integrations/v1"

SkriftTokenfil() => EnvGet("LOCALAPPDATA") "\Skrift\skrift-token.ini"

; Tokenet fra filen. Stopper med en forklaring når det mangler.
SkriftToken() {
    fil := SkriftTokenfil()
    tok := ""
    if FileExist(fil)
        tok := Trim(IniRead(fil, "skrift", "token", ""))
    if !RegExMatch(tok, "^skr_[A-Za-z0-9_-]{16,}$") {
        MsgBox "Fant ikke et token i " fil "`n`nLag tokenet under Innstillinger, Integrasjoner i Skrift, og legg det i filen med to linjer:`n[skrift]`ntoken=skr_…", "Skrift", "Icon!"
        ExitApp
    }
    return tok
}

; Ett kall til Skrift. Svar: {status, tekst}. Omdirigeringer følges aldri, så
; tokenet går bare til api.skrift.md. Proxyen følger Windows' innstillinger (PAC
; eller manuell, for eksempel på NHN-nett); [skrift] proxy=vert:port i tokenfilen
; overstyrer, «ingen» går alltid direkte.
SkriftKall(metode, sti, kropp := "") {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts(10000, 10000, 30000, 30000)
    proxy := SkriftProxy(SKRIFT_BASE sti)
    if proxy != ""
        http.SetProxy(2, proxy)
    http.Open(metode, SKRIFT_BASE sti, false)
    http.Option[6] := false
    http.SetRequestHeader("Authorization", "Bearer " SkriftToken())
    http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
    http.SetRequestHeader("Accept", "application/json")
    http.SetRequestHeader("User-Agent", "Skrift-eksempel/1.0")
    if kropp = ""
        http.Send()
    else
        http.Send(Utf8Bytes(kropp))
    tekst := ""
    try tekst := Utf8Svar(http)
    catch {
        try tekst := http.ResponseText
    }
    return {status: http.Status, tekst: tekst}
}

; Kroppen som UTF-8-bytes, så æøå kommer riktig fram
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

; JSON-streng med anførselstegn (RFC 8259)
JsonStreng(s) {
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(StrReplace(s, "`r`n", "`n"), "`r", "`n")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return '"' s '"'
}

; Verdien til et strengfelt i et enkelt JSON-svar (ett nivå), "" når det mangler.
; Nok for svarene fra Skrift; et fullt JSON-bibliotek er ikke nødvendig her.
JsonFelt(tekst, navn) {
    if !RegExMatch(tekst, '"' navn '"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
        return ""
    s := m[1]
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\t", "`t")
    s := StrReplace(s, '\"', '"')
    s := StrReplace(s, "\/", "/")
    s := StrReplace(s, "\\", "\")
    return s
}

; Feilmeldingen fra et svar som ikke gikk: koden og meldingen fra Skrift, ellers statusen
SkriftFeil(svar) {
    kode := JsonFelt(svar.tekst, "error"), melding := JsonFelt(svar.tekst, "message")
    if svar.status = 409 && kode = "SKRIFT_IKKE_APEN"
        return "Skrift er ikke åpent i nettleseren. Åpne Skrift og prøv igjen."
    if svar.status = 409 && kode = "KOMMANDO_VENTER"
        return "En kommando venter allerede på et klikk i Skrift."
    if svar.status = 401
        return "Tokenet virker ikke lenger (" kode "). Lag et nytt under Innstillinger, Integrasjoner."
    if svar.status = 403
        return "Tokenet mangler rettigheten dette krever (" kode ")."
    return "Skrift svarte " svar.status (kode != "" ? " " kode : "") (melding != "" ? ": " melding : "")
}

; Proxyen for kallet: [skrift] proxy i tokenfilen («ingen», «vert:port» eller tom =
; slik Windows er satt opp). "" = direkte.
SkriftProxy(url) {
    static funnet := ""
    v := ""
    try v := StrLower(Trim(IniRead(SkriftTokenfil(), "skrift", "proxy", "")))
    if v = "ingen" || v = "none"
        return ""
    if v != ""
        return v
    if funnet = ""
        funnet := ProxyFraWindows(url) || "direkte"
    return funnet = "direkte" ? "" : funnet
}

; Proxyen Windows ville brukt for url (PAC-skript, automatisk oppdaging eller manuell
; proxy). "" når Windows går direkte eller oppslaget ikke lot seg gjøre.
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
            hSession := DllCall("winhttp\WinHttpOpen", "WStr", "Skrift-eksempel/1.1", "UInt", 1, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
            if hSession {
                try {
                    opt := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
                    NumPut("UInt", (pacUrl != "" ? 2 : 0) | (autoDetect ? 1 : 0), opt, 0)
                    NumPut("UInt", autoDetect ? 3 : 0, opt, 4)
                    if pacUrl != ""
                        NumPut("Ptr", pUrl, opt, 8)
                    NumPut("Int", 1, opt, A_PtrSize = 8 ? 28 : 20)
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
        if ut = "" && manuell != "" {
            for del in StrSplit(manuell, [";", " "]) {
                del := Trim(del)
                if RegExMatch(del, "i)^https=(.+)$", &m)
                    ut := m[1]
                else if del != "" && !InStr(del, "=") && ut = ""
                    ut := del
            }
        }
    } finally {
        for p in [pUrl, pProxy, pBypass]
            if p
                DllCall("GlobalFree", "Ptr", p)
    }
    return (ut = "" || StrLower(ut) = "direct") ? "" : ut
}
