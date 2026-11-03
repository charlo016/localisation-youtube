' Gestion de la liste (partagée entre l'écran et le serveur web)
' Format compact (le registre Roku est limité à ~16 Ko) :
' { "c": [ { "n": "Films", "i": [ { "t": "Inception", "y": "2010", "p": "i:1/...", "w": 1 } ] } ] }
'   n = nom de catégorie, i = titres, t = titre, y = année, p = affiche (code court ou URL), w = 1 si déjà vu

function DefaultData() as Object
    return {
        c: [
            MakeCat("Films", ["Inception", "Interstellar", "Le Fabuleux Destin d'Amélie Poulain", "Intouchables", "Retour vers le futur"]),
            MakeCat("Séries", ["Breaking Bad", "Stranger Things", "The Office", "Dark"]),
            MakeCat("Animés", ["Fullmetal Alchemist: Brotherhood", "One Piece", "Death Note", "Le Voyage de Chihiro"])
        ]
    }
end function

function MakeCat(name as String, titles as Object) as Object
    items = []
    for each t in titles
        items.Push({ t: t })
    end for
    return { n: name, i: items }
end function

function IsStr(v as Dynamic) as Boolean
    return v <> invalid and GetInterface(v, "ifString") <> invalid
end function

function IsTrue(v as Dynamic) as Boolean
    t = type(v)
    if t = "Invalid" or t = "roInvalid" or t = "<uninitialized>" then return false
    if GetInterface(v, "ifBoolean") <> invalid then return v
    if GetInterface(v, "ifInt") <> invalid then return v <> 0
    return false
end function

function IsWatched(item as Object) as Boolean
    return IsTrue(item.w)
end function

' Nettoie/valide des données reçues (accepte aussi l'ancien format v1).
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
                            src = invalid
                            if IsStr(it) then
                                src = { t: it }
                            else if type(it) = "roAssociativeArray" and IsStr(it.t) then
                                src = it
                            end if
                            if src <> invalid then
                                t = Left(src.t.Trim(), 120)
                                if t <> "" then
                                    n = { t: t }
                                    if IsStr(src.y) and src.y <> "" then n.y = Left(src.y, 4)
                                    if IsStr(src.p) and src.p <> "" then n.p = Left(src.p, 300)
                                    if IsTrue(src.w) then n.w = 1
                                    items.Push(n)
                                end if
                            end if
                        end for
                    end if
                    out.Push({ n: name, i: items })
                end if
            end if
        end if
    end for
    return { c: out }
end function

' Transforme le code court d'affiche en vraie URL.
function PosterUrl(p as Dynamic) as String
    if not IsStr(p) or p = "" then return ""
    pre = Left(p, 2)
    rest = Mid(p, 3)
    if pre = "m:" then return "https://cdn.myanimelist.net/images/anime/" + rest + "l.jpg"
    if pre = "t:" then return "https://static.tvmaze.com/uploads/images/original_untouched/" + rest
    if pre = "i:" then
        slash = Instr(1, rest, "/")
        if slash > 0 then return "https://is" + Left(rest, slash - 1) + "-ssl.mzstatic.com/image/thumb/" + Mid(rest, slash + 1) + "/400x600bb.jpg"
    end if
    return p
end function

function ByteLen(s as String) as Integer
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(s)
    return ba.Count()
end function

' Le registre Roku est limité à 16 Ko par app : on garde une marge.
function MaxDataBytes() as Integer
    return 15000
end function

function LoadData() as Object
    sec = CreateObject("roRegistrySection", "hasard")
    if sec.Exists("data") then
        d = SanitizeData(ParseJson(sec.Read("data")))
        if d <> invalid then return d
    end if
    return DefaultData()
end function

function LoadDataJson() as String
    return FormatJson(LoadData())
end function

' Retourne "" si OK, sinon un message d'erreur.
function SaveDataJson(json as String) as String
    if ByteLen(json) > MaxDataBytes() then return "Liste pleine (max " + MaxDataBytes().ToStr() + " octets)"
    sec = CreateObject("roRegistrySection", "hasard")
    if not sec.Write("data", json) then return "Erreur d'écriture"
    sec.Flush()
    return ""
end function
