' ============================================================================
' Données partagées entre l'écran (MainScene) et le serveur web (WebServerTask)
' ============================================================================
' Liste (registre "hasard"/"data"), format compact car le registre Roku est
' limité à ~16 Ko par app :
' { "c": [ { "n": "Films", "i": [ ITEM, ... ] } ] }
' ITEM = {
'   t: titre (obligatoire)      y: année "2010"
'   s: source "i:123" (iTunes) "t:82" (TVmaze) "m:1535" (MyAnimeList)
'   p: affiche (code court "m:..", "t:..", "i:.." ou URL complète)
'   g: genres (codes d'une lettre, ex. "ACS")   d: durée en minutes
'   w: 1 = déjà vu   f: 1 = favori   r: ma note 1..5
' }

function AppVersion() as String
    return "2.1"
end function

function DefaultData() as Object
    return {
        c: [
            MakeCat("Films", [
                { t: "Inception", y: "2010", g: "ASM", d: 148 },
                { t: "Interstellar", y: "2014", g: "VDS", d: 169 },
                { t: "Le Fabuleux Destin d'Amélie Poulain", y: "2001", g: "CR", d: 122 },
                { t: "Intouchables", y: "2011", g: "CD", d: 112 },
                { t: "Retour vers le futur", y: "1985", g: "VCS", d: 116 }
            ]),
            MakeCat("Séries", [
                { t: "Breaking Bad", y: "2008", g: "DPT", d: 47, s: "t:169" },
                { t: "Stranger Things", y: "2016", g: "DHS", d: 60, s: "t:2993" },
                { t: "The Office", y: "2005", g: "C", d: 22, s: "t:526" },
                { t: "Dark", y: "2017", g: "DMS", d: 60, s: "t:17861" }
            ]),
            MakeCat("Animés", [
                { t: "Fullmetal Alchemist: Brotherhood", y: "2009", g: "AVDF", d: 24, s: "m:5114" },
                { t: "One Piece", y: "1999", g: "AVF", d: 24, s: "m:21" },
                { t: "Death Note", y: "2006", g: "FT", d: 23, s: "m:1535" },
                { t: "Le Voyage de Chihiro", y: "2001", g: "VF", d: 125, s: "m:199" }
            ])
        ]
    }
end function

function MakeCat(name as String, items as Object) as Object
    return { n: name, i: items }
end function

' ---------- Petits utilitaires de type ----------

function IsNil(v as Dynamic) as Boolean
    t = type(v)
    return t = "Invalid" or t = "roInvalid" or t = "<uninitialized>"
end function

function IsStr(v as Dynamic) as Boolean
    if IsNil(v) then return false
    return GetInterface(v, "ifString") <> invalid
end function

function IsNum(v as Dynamic) as Boolean
    if IsNil(v) then return false
    return GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid
end function

function IsBool(v as Dynamic) as Boolean
    if IsNil(v) then return false
    return GetInterface(v, "ifBoolean") <> invalid
end function

function IsTrue(v as Dynamic) as Boolean
    if IsBool(v) then return v
    if IsNum(v) then return v <> 0
    return false
end function

' Convertit un nombre ou un texte en entier (0 si impossible)
function ToInt(v as Dynamic) as Integer
    if IsStr(v) then return v.Trim().ToInt()
    if IsNum(v) then return Int(v)
    return 0
end function

function AnyToStr(v as Dynamic) as String
    if IsStr(v) then return v
    if IsNum(v) then return Str(v).Trim()
    if IsBool(v) then
        if v then return "true"
        return "false"
    end if
    return ""
end function

function IsWatched(item as Object) as Boolean
    return IsTrue(item.w)
end function

function IsFav(item as Object) as Boolean
    return IsTrue(item.f)
end function

function Rating(item as Object) as Integer
    r = ToInt(item.r)
    if r < 0 or r > 5 then return 0
    return r
end function

' ---------- Genres ----------

function GenreList() as Object
    return [
        { k: "A", n: "Action" }
        { k: "V", n: "Aventure" }
        { k: "C", n: "Comédie" }
        { k: "D", n: "Drame" }
        { k: "H", n: "Horreur" }
        { k: "T", n: "Thriller" }
        { k: "S", n: "Science-fiction" }
        { k: "F", n: "Fantastique" }
        { k: "R", n: "Romance" }
        { k: "P", n: "Policier" }
        { k: "M", n: "Mystère" }
        { k: "N", n: "Animation" }
        { k: "O", n: "Documentaire" }
        { k: "Y", n: "Famille" }
        { k: "U", n: "Musique" }
        { k: "G", n: "Histoire / Guerre" }
        { k: "W", n: "Western" }
        { k: "L", n: "Sport" }
        { k: "K", n: "Tranche de vie" }
    ]
end function

function GenreName(code as String) as String
    for each g in GenreList()
        if g.k = code then return g.n
    end for
    return ""
end function

function GenreNames(codes as Dynamic) as String
    if not IsStr(codes) then return ""
    out = ""
    for i = 1 to Len(codes)
        n = GenreName(Mid(codes, i, 1))
        if n <> "" then
            if out <> "" then out = out + ", "
            out = out + n
        end if
    end for
    return out
end function

function FormatDuration(mins as Integer) as String
    if mins <= 0 then return ""
    if mins < 60 then return mins.ToStr() + " min"
    h = Int(mins / 60)
    r = mins - h * 60
    if r = 0 then return h.ToStr() + " h"
    if r < 10 then return h.ToStr() + " h 0" + r.ToStr()
    return h.ToStr() + " h " + r.ToStr()
end function

' ---------- Nettoyage / validation de la liste ----------

function SanitizeItem(src as Dynamic) as Dynamic
    if IsStr(src) then src = { t: src }
    if type(src) <> "roAssociativeArray" or not IsStr(src.t) then return invalid
    t = Left(src.t.Trim(), 120)
    if t = "" then return invalid
    n = { t: t }
    y = AnyToStr(src.y)
    if Len(y) >= 4 then n.y = Left(y, 4)
    if IsStr(src.s) and Len(src.s) > 2 then n.s = Left(src.s, 24)
    if IsStr(src.p) and src.p <> "" then n.p = Left(src.p, 300)
    if IsStr(src.g) then
        g = ""
        for i = 1 to Len(src.g)
            ch = UCase(Mid(src.g, i, 1))
            if GenreName(ch) <> "" and Instr(1, g, ch) = 0 then g = g + ch
        end for
        if g <> "" then n.g = Left(g, 8)
    end if
    d = ToInt(src.d)
    if d > 0 and d < 1000 then n.d = d
    if IsTrue(src.w) then n.w = 1
    if IsTrue(src.f) then n.f = 1
    r = ToInt(src.r)
    if r >= 1 and r <= 5 then n.r = r
    return n
end function

' Accepte aussi l'ancien format v1 ({categories:[{name, items:[...]}]}).
' Retourne invalid si le format est mauvais.
function SanitizeData(d as Dynamic) as Dynamic
    if type(d) <> "roAssociativeArray" then return invalid
    cats = d.c
    if type(cats) <> "roArray" then cats = d.categories
    if type(cats) <> "roArray" then return invalid
    out = []
    for each c in cats
        if type(c) = "roAssociativeArray" then
            name = c.n
            if not IsStr(name) then name = c.name
            list = c.i
            if type(list) <> "roArray" then list = c.items
            if IsStr(name) then
                name = Left(name.Trim(), 40)
                if name <> "" then
                    items = []
                    if type(list) = "roArray" then
                        for each it in list
                            n = SanitizeItem(it)
                            if n <> invalid then items.Push(n)
                        end for
                    end if
                    out.Push({ n: name, i: items })
                end if
            end if
        end if
        if out.Count() >= 20 then exit for
    end for
    return { c: out }
end function

' Transforme le code court d'affiche en vraie URL.
function PosterUrl(p as Dynamic) as String
    if not IsStr(p) or p = "" then return ""
    pre = Left(p, 2)
    rest = Mid(p, 3)
    if pre = "m:" then return "https://cdn.myanimelist.net/images/anime/" + rest + "l.jpg"
    if pre = "a:" then return "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/" + rest
    if pre = "b:" then return "https://m.media-amazon.com/images/M/" + rest + "._V1_SX400.jpg"
    if pre = "t:" then return "https://static.tvmaze.com/uploads/images/original_untouched/" + rest
    if pre = "i:" then
        slash = Instr(1, rest, "/")
        if slash > 0 then return "https://is" + Left(rest, slash - 1) + "-ssl.mzstatic.com/image/thumb/" + Mid(rest, slash + 1) + "/400x600bb.jpg"
    end if
    return p
end function

' ---------- Réglages (registre "hasard"/"settings") ----------

function DefaultSettings() as Object
    return {
        mode: "one"        ' one = 1 titre, three = 3 choix
        anim: "normal"     ' normal / fast / off
        avoid: 5           ' ne pas retomber sur les N derniers tirages
        favw: 2            ' poids des favoris
        sound: true
        synopsis: true
        accent: "gold"
        sort: "added"      ' tri des listes : added / az / year / rating
        country: "us"      ' boutique iTunes pour les films
        fgenre: ""         ' filtres du tirage
        fdur: 0
        fdec: ""
        ffav: false
        fwatched: false
        players: []        ' prénoms pour « Qui choisit ce soir ? »
    }
end function

function OptVal(v as Dynamic, allowed as Object, def as Dynamic) as Dynamic
    for each a in allowed
        if FormatJson(a) = FormatJson(v) then return a
    end for
    return def
end function

function SanitizeSettings(s as Dynamic) as Object
    d = DefaultSettings()
    if type(s) <> "roAssociativeArray" then return d
    d.mode = OptVal(s.mode, ["one", "three"], d.mode)
    d.anim = OptVal(s.anim, ["normal", "fast", "off"], d.anim)
    if not IsNil(s.avoid) then d.avoid = OptVal(ToInt(s.avoid), [0, 1, 3, 5, 10], d.avoid)
    if not IsNil(s.favw) then d.favw = OptVal(ToInt(s.favw), [1, 2, 3, 5], d.favw)
    if IsBool(s.sound) then d.sound = s.sound
    if IsBool(s.synopsis) then d.synopsis = s.synopsis
    d.accent = OptVal(s.accent, ["gold", "blue", "pink", "green", "orange", "purple"], d.accent)
    d.sort = OptVal(s.sort, ["added", "az", "year", "rating"], d.sort)
    d.country = OptVal(s.country, ["us", "ca", "fr"], d.country)
    if IsStr(s.fgenre) and (s.fgenre = "" or GenreName(s.fgenre) <> "") then d.fgenre = s.fgenre
    if not IsNil(s.fdur) then d.fdur = OptVal(ToInt(s.fdur), [0, 30, 60, 90, 120, 150], d.fdur)
    d.fdec = OptVal(s.fdec, ["", "old", "1980", "1990", "2000", "2010", "2020"], d.fdec)
    if IsBool(s.ffav) then d.ffav = s.ffav
    if IsBool(s.fwatched) then d.fwatched = s.fwatched
    if type(s.players) = "roArray" then
        for each p in s.players
            if IsStr(p) and p.Trim() <> "" and d.players.Count() < 12 then d.players.Push(Left(p.Trim(), 20))
        end for
    end if
    return d
end function

function AccentColor(name as String) as String
    colors = { gold: "0xFFC94DFF", blue: "0x5AB8FFFF", pink: "0xFF6FB5FF", green: "0x5CE08AFF", orange: "0xFF8A3DFF", purple: "0xB38CFFFF" }
    c = colors[name]
    if c = invalid then c = colors.gold
    return c
end function

' Le titre passe-t-il les filtres du tirage ?
function PassesFilters(it as Object, s as Object) as Boolean
    if not s.fwatched and IsWatched(it) then return false
    if s.ffav and not IsFav(it) then return false
    if s.fgenre <> "" then
        if not IsStr(it.g) then return false
        if Instr(1, it.g, s.fgenre) = 0 then return false
    end if
    if s.fdur > 0 then
        d = ToInt(it.d)
        if d > s.fdur then return false
    end if
    if s.fdec <> "" then
        y = ToInt(it.y)
        if y = 0 then return false
        if s.fdec = "old" then
            if y >= 1980 then return false
        else
            dec = s.fdec.ToInt()
            if y < dec or y >= dec + 10 then return false
        end if
    end if
    return true
end function

function FiltersActive(s as Object) as Boolean
    return s.fgenre <> "" or s.fdur > 0 or s.fdec <> "" or s.ffav or s.fwatched
end function

function FiltersSummary(s as Object) as String
    parts = []
    if s.fgenre <> "" then parts.Push(GenreName(s.fgenre))
    if s.fdur > 0 then parts.Push("max " + FormatDuration(s.fdur))
    if s.fdec = "old" then
        parts.Push("avant 1980")
    else if s.fdec <> "" then
        parts.Push("années " + Right(s.fdec, 2))
    end if
    if s.ffav then parts.Push("favoris")
    if s.fwatched then parts.Push("vus inclus")
    if parts.Count() = 0 then return "aucun"
    out = ""
    for each p in parts
        if out <> "" then out = out + ", "
        out = out + p
    end for
    return out
end function

' ---------- Registre ----------

function ByteLen(s as String) as Integer
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(s)
    return ba.Count()
end function

' Le registre Roku est limité à 16 Ko pour TOUTE l'app (liste + réglages + historique).
function MaxDataBytes() as Integer
    return 13000
end function

function RegRead(key as String) as Dynamic
    sec = CreateObject("roRegistrySection", "hasard")
    if sec.Exists(key) then return ParseJson(sec.Read(key))
    return invalid
end function

function RegWrite(key as String, json as String) as Boolean
    sec = CreateObject("roRegistrySection", "hasard")
    ok = sec.Write(key, json)
    sec.Flush()
    return ok
end function

function LoadData() as Object
    d = SanitizeData(RegRead("data"))
    if d <> invalid then return d
    return DefaultData()
end function

function LoadDataJson() as String
    return FormatJson(LoadData())
end function

' Retourne "" si OK, sinon un message d'erreur.
function SaveDataJson(json as String) as String
    if ByteLen(json) > MaxDataBytes() then return "Liste pleine (max " + MaxDataBytes().ToStr() + " octets)"
    if not RegWrite("data", json) then return "Erreur d'écriture"
    return ""
end function

function LoadSettings() as Object
    return SanitizeSettings(RegRead("settings"))
end function

sub SaveSettings(s as Object)
    RegWrite("settings", FormatJson(s))
end sub

' Historique des tirages : [ { t: titre, c: catégorie, ts: secondes } ] (récent d'abord)
function LoadHistory() as Object
    h = RegRead("hist")
    out = []
    if type(h) = "roArray" then
        for each e in h
            if type(e) = "roAssociativeArray" and IsStr(e.t) then
                out.Push({ t: Left(e.t, 120), c: AnyToStr(e.c), ts: ToInt(e.ts) })
            end if
        end for
    end if
    return out
end function

sub SaveHistory(h as Object)
    while h.Count() > 25
        h.Pop()
    end while
    RegWrite("hist", FormatJson(h))
end sub
