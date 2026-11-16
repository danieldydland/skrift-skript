; =============================================================================
; PatientText.ahk  –  Skrift.md / Eirskrift AS
; Leser WebMeds utklippsformat «PatientText» og en liten, streng JSON-leser.
; Brukes av dagsliste.ahk og ..\verktoy\patienttext-sjekk.ahk.
;
; Funn 19.10.2026 (tredje vurdering §2.4): Ctrl+C i journalen legger formatet
; PatientText ved teksten, med JSON {"Text": "<det som ble kopiert>",
; "PatientId": "<WebMeds pasient-GUID>"}.
;
; Målt 22.10.2026 (patienttext-sjekk.ahk, fiktiv pasient: Alt+S, Alt+F og
; notatet etter Ctrl+Alt+L): JSON-en ligger som en .NET-serialisert streng.
; Bytene er .NETs merke for serialiserte objekter (GUID FD9EA796-3B13-4370-
; A679-56106BB288FB, 16 byte), deretter en NRBF-strøm (MS-NRBF): topptekst
; (17 byte), BinaryObjectString (type 6, objekt-ID, lengde som 7-biters tall,
; JSON i UTF-8) og MessageEnd (type 11). Størrelsene 223, 125 og 170 byte
; stemmer nøyaktig med det for de tre kopiene. Ren JSON i UTF-8 eller UTF-16
; godtas også. Alt annet stopper.
;
; Feilmeldinger herfra inneholder aldri tekst fra utklippstavlen, bare
; lengder, tegnkoding, byteposisjoner og nøkkelnavn.
; =============================================================================

PatientTextFormat() {
    static cf := 0
    if !cf {
        cf := DllCall("RegisterClipboardFormat", "Str", "PatientText", "UInt")
        if !cf
            throw OSError(A_LastError, -1, "RegisterClipboardFormat(PatientText)")
    }
    return cf
}

; Leser PatientText fra utklippstavlen akkurat nå og kontrollerer den mot
; teksten som nettopp ble kopiert (A_Clipboard etter Ctrl+C). Svar:
;   funnet       formatet finnes (eller utklippstavlen kunne ikke leses)
;   id           pasient-GUID med små bokstaver når alt stemmer, ellers ""
;   tekst        Text fra PatientText når alt stemmer, ellers ""
;   feil         "" eller kort beskrivelse uten journaltekst
;   koding, bytes, tekstLengde, nokler   til feilsøking (verktøyet)
LesPatientText(kopiert) {
    r := {funnet: false, id: "", tekst: "", feil: "", koding: "", bytes: 0, tekstLengde: -1, nokler: ""}
    cb := 0
    loop 3 {
        try {
            cb := ClipboardAll()
            break
        }
        Sleep 50
    }
    if !IsObject(cb) {
        ; Ukjent om formatet finnes: regnes som feil, ikke som «mangler»
        r.funnet := true, r.feil := "utklippstavlen kunne ikke leses"
        return r
    }
    try formater := UtklippFormater(cb)
    catch as e {
        r.funnet := true, r.feil := e.Message
        return r
    }
    cf := PatientTextFormat()
    if !formater.Has(cf)
        return r
    r.funnet := true
    d := formater[cf]
    r.bytes := d.size
    ; Samme kopi? UnicodeText i øyeblikksbildet må være teksten som ble lest.
    if formater.Has(13) {
        u := formater[13]
        if !(StrGet(u.ptr, u.size // 2, "UTF-16") == kopiert) {
            r.feil := "utklippstavlen endret seg mens den ble lest"
            return r
        }
    }
    try obj := DekodPatientText(d.ptr, d.size, &koding)
    catch as e {
        r.feil := e.Message
        return r
    }
    r.koding := koding
    r.nokler := Nokler(obj)
    r.tekstLengde := StrLen(obj["Text"])
    if !SammeTekst(obj["Text"], kopiert) {
        r.feil := "Text i PatientText (" StrLen(obj["Text"]) " tegn) er ikke lik den kopierte teksten (" StrLen(kopiert) " tegn)"
        return r
    }
    r.id := StrLower(obj["PatientId"])
    r.tekst := obj["Text"]
    return r
}

; ClipboardAll-data: gjentatt UInt format, UInt størrelse, data; avsluttes med UInt 0.
; Svar: Map format -> {ptr, size}. cb må leve så lenge pekerne brukes.
UtklippFormater(cb) {
    m := Map()
    p := cb.Ptr, n := cb.Size, off := 0
    while off + 4 <= n {
        fmt := NumGet(p, off, "UInt")
        if fmt = 0
            break
        if off + 8 > n
            throw Error("ClipboardAll har ukjent oppbygning")
        sz := NumGet(p, off + 4, "UInt")
        if off + 8 + sz > n
            throw Error("ClipboardAll har ukjent oppbygning")
        m[fmt] := {ptr: p + off + 8, size: sz}
        off += 8 + sz
    }
    return m
}

; Rå PatientText-bytes -> Map med minst Text (streng) og PatientId (GUID).
DekodPatientText(ptr, size, &koding := "") {
    if size < 2
        throw Error("PatientText er tom")
    if NetMerke(ptr, size) {
        koding := ".NET-serialisert streng (NRBF, UTF-8)"
        s := LesNrbfStreng(ptr, size)
    } else {
        b0 := NumGet(ptr, 0, "UChar"), b1 := NumGet(ptr, 1, "UChar")
        start := 0, koding := "UTF-8"
        if size >= 3 && b0 = 0xEF && b1 = 0xBB && NumGet(ptr, 2, "UChar") = 0xBF
            start := 3, koding := "UTF-8 med BOM"
        else if b0 = 0xFF && b1 = 0xFE
            start := 2, koding := "UTF-16 med BOM"
        else if size >= 4 && b0 != 0 && b1 = 0 && NumGet(ptr, 3, "UChar") = 0
            koding := "UTF-16"
        ; StrGet stopper ved første nullbyte, så utfylling bak JSON-en forsvinner
        if InStr(koding, "UTF-16")
            s := StrGet(ptr + start, (size - start) // 2, "UTF-16")
        else
            s := StrGet(ptr + start, size - start, "UTF-8")
        if SubStr(Trim(s, " `t`r`n"), 1, 1) != "{"
            throw Error("PatientText har ukjent format (" size " byte, første byte 0x" Format("{:02X}", NumGet(ptr, 0, "UChar")) ")")
    }
    s := Trim(s, " `t`r`n")
    if SubStr(s, 1, 1) != "{"
        throw Error("PatientText inneholder ikke et JSON-objekt (" koding ")")
    obj := JsonLes(s)
    if !(obj is Map)
        throw Error("PatientText er ikke et JSON-objekt")
    if !obj.Has("Text") || !(obj["Text"] is String)
        throw Error("PatientText mangler Text (nøkler: " Nokler(obj) ")")
    if !obj.Has("PatientId") || !(obj["PatientId"] is String)
        throw Error("PatientText mangler PatientId (nøkler: " Nokler(obj) ")")
    if !ErGuid(obj["PatientId"])
        throw Error("PatientId i PatientText er ikke en gyldig GUID (" StrLen(obj["PatientId"]) " tegn)")
    return obj
}

; .NETs merke for serialiserte objekter i utklippstavlen (Guid.ToByteArray())
NetMerke(ptr, size) {
    static merke := [0x96, 0xA7, 0x9E, 0xFD, 0x13, 0x3B, 0x70, 0x43, 0xA6, 0x79, 0x56, 0x10, 0x6B, 0xB2, 0x88, 0xFB]
    if size < 16
        return false
    for i, b in merke
        if NumGet(ptr, i - 1, "UChar") != b
            return false
    return true
}

; NRBF etter merket: SerializationHeader, BinaryObjectString, MessageEnd.
; Bare akkurat denne oppbygningen godtas; bak MessageEnd bare nullbyte.
LesNrbfStreng(ptr, size) {
    feil := (hva) => Error("PatientText har ukjent .NET-format (" hva ", " size " byte)")
    off := 16
    if size < off + 17 + 1 + 4 + 1 + 1
        throw feil("for kort")
    if NumGet(ptr, off, "UChar") != 0
        throw feil("ventet topptekst ved byte " off)
    rot := NumGet(ptr, off + 1, "Int")
    if NumGet(ptr, off + 9, "Int") != 1 || NumGet(ptr, off + 13, "Int") != 0
        throw feil("ukjent NRBF-versjon")
    off += 17
    if NumGet(ptr, off, "UChar") != 6
        throw feil("ventet en streng (type 6) ved byte " off ", fant type " NumGet(ptr, off, "UChar"))
    id := NumGet(ptr, off + 1, "Int")
    if id <= 0 || id != rot
        throw feil("objekt-ID stemmer ikke med topptekst")
    off += 5
    ; Lengden er et 7-biters tall over 1–5 byte
    lengde := 0, skift := 0
    loop 5 {
        if off >= size
            throw feil("lengden går forbi slutten")
        b := NumGet(ptr, off, "UChar"), off++
        lengde |= (b & 0x7F) << skift, skift += 7
        if !(b & 0x80)
            break
        if A_Index = 5
            throw feil("ugyldig lengde")
    }
    if lengde < 2 || off + lengde + 1 > size
        throw feil("lengden " lengde " passer ikke")
    if NumGet(ptr, off + lengde, "UChar") != 11
        throw feil("ventet MessageEnd (type 11) ved byte " (off + lengde))
    loop size - (off + lengde + 1)
        if NumGet(ptr, off + lengde + A_Index, "UChar") != 0
            throw feil("data etter MessageEnd")
    ; Ingen nullbyte inni strengen (StrGet ville stoppet der)
    loop lengde
        if !NumGet(ptr, off + A_Index - 1, "UChar")
            throw feil("nullbyte i strengen")
    return StrGet(ptr + off, lengde, "UTF-8")
}

ErGuid(s) => s is String
    && RegExMatch(s, "i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
    && s != "00000000-0000-0000-0000-000000000000"

; Lik tekst, eller lik når bare linjeskiftene (CRLF/CR/LF) eller mellomrom og
; linjeskift helt til slutt er ulike (en kopi kan få en avsluttende CRLF)
SammeTekst(a, b) => a == b || RTrim(NormLinjer(a), " `t`n") == RTrim(NormLinjer(b), " `t`n")

NormLinjer(s) => StrReplace(StrReplace(s, "`r`n", "`n"), "`r", "`n")

Nokler(obj) {
    s := ""
    for k in obj
        s .= (s = "" ? "" : ", ") SubStr(k, 1, 40)
    return SubStr(s, 1, 200)
}

; -----------------------------------------------------------------------------
; JSON-leser (RFC 8259). Objekt -> Map (skiller store/små bokstaver), liste ->
; Array, streng -> String, tall -> Number, true/false -> 1/0, null -> JsonNull.
; Doble nøkler og tekst etter siste tegn gir feil.
; -----------------------------------------------------------------------------
class JsonNull {
}

JsonLes(s) {
    pos := 1
    v := _JsonVerdi(s, &pos, 0)
    _JsonHopp(s, &pos)
    if pos <= StrLen(s)
        throw Error("ugyldig JSON: tegn etter slutten (posisjon " pos ")")
    return v
}

_JsonHopp(s, &pos) {
    n := StrLen(s)
    while pos <= n {
        c := SubStr(s, pos, 1)
        if !(c = " " || c = "`t" || c = "`r" || c = "`n")
            break
        pos++
    }
}

_JsonVerdi(s, &pos, dybde) {
    if dybde > 32
        throw Error("ugyldig JSON: for dyp nesting")
    _JsonHopp(s, &pos)
    c := SubStr(s, pos, 1)
    if c == "{" {
        obj := Map()
        pos++
        _JsonHopp(s, &pos)
        if SubStr(s, pos, 1) == "}" {
            pos++
            return obj
        }
        loop {
            _JsonHopp(s, &pos)
            if SubStr(s, pos, 1) != '"'
                throw Error("ugyldig JSON: ventet nøkkel (posisjon " pos ")")
            k := _JsonStreng(s, &pos)
            if obj.Has(k)
                throw Error("ugyldig JSON: nøkkelen «" SubStr(k, 1, 40) "» står to ganger")
            _JsonHopp(s, &pos)
            if SubStr(s, pos, 1) != ":"
                throw Error("ugyldig JSON: ventet kolon (posisjon " pos ")")
            pos++
            obj[k] := _JsonVerdi(s, &pos, dybde + 1)
            _JsonHopp(s, &pos)
            c := SubStr(s, pos, 1), pos++
            if c == "}"
                return obj
            if c != ","
                throw Error("ugyldig JSON: ventet komma eller } (posisjon " (pos - 1) ")")
        }
    }
    if c == "[" {
        arr := []
        pos++
        _JsonHopp(s, &pos)
        if SubStr(s, pos, 1) == "]" {
            pos++
            return arr
        }
        loop {
            arr.Push(_JsonVerdi(s, &pos, dybde + 1))
            _JsonHopp(s, &pos)
            c := SubStr(s, pos, 1), pos++
            if c == "]"
                return arr
            if c != ","
                throw Error("ugyldig JSON: ventet komma eller ] (posisjon " (pos - 1) ")")
        }
    }
    if c == '"'
        return _JsonStreng(s, &pos)
    if SubStr(s, pos, 4) == "true" {
        pos += 4
        return true
    }
    if SubStr(s, pos, 5) == "false" {
        pos += 5
        return false
    }
    if SubStr(s, pos, 4) == "null" {
        pos += 4
        return JsonNull
    }
    if RegExMatch(s, "-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?", &m, pos) && m.Pos = pos {
        pos += m.Len
        return Number(m[0])
    }
    throw Error("ugyldig JSON: ukjent verdi (posisjon " pos ")")
}

; pos står på åpnende anførselstegn; returnerer strengen og flytter pos forbi slutten
_JsonStreng(s, &pos) {
    pos++
    ut := ""
    loop {
        if !RegExMatch(s, '["\\]', &m, pos)
            throw Error("ugyldig JSON: streng uten slutt")
        ut .= SubStr(s, pos, m.Pos - pos)
        pos := m.Pos
        if m[0] == '"' {
            pos++
            return ut
        }
        e := SubStr(s, pos + 1, 1)
        switch e, true {
            case '"': ut .= '"'
            case "\": ut .= "\"
            case "/": ut .= "/"
            case "b": ut .= "`b"
            case "f": ut .= "`f"
            case "n": ut .= "`n"
            case "r": ut .= "`r"
            case "t": ut .= "`t"
            case "u":
                cp := _JsonHex(s, pos + 2)
                pos += 6
                if cp >= 0xD800 && cp <= 0xDBFF {
                    if SubStr(s, pos, 2) !== "\u"
                        throw Error("ugyldig JSON: halvt surrogatpar")
                    lav := _JsonHex(s, pos + 2)
                    if lav < 0xDC00 || lav > 0xDFFF
                        throw Error("ugyldig JSON: halvt surrogatpar")
                    cp := 0x10000 + ((cp - 0xD800) << 10) + (lav - 0xDC00)
                    pos += 6
                } else if cp >= 0xDC00 && cp <= 0xDFFF
                    throw Error("ugyldig JSON: halvt surrogatpar")
                if cp = 0
                    throw Error("ugyldig JSON: nulltegn i streng")
                ut .= Chr(cp)
                continue
            default:
                throw Error("ugyldig JSON: ukjent escape (posisjon " pos ")")
        }
        pos += 2
    }
}

_JsonHex(s, pos) {
    h := SubStr(s, pos, 4)
    if !RegExMatch(h, "^[0-9A-Fa-f]{4}$")
        throw Error("ugyldig JSON: ugyldig \u-escape")
    return Integer("0x" h)
}
