' Gestion de la liste (partagée entre l'écran et le serveur web)
' Format : { "categories": [ { "name": "Films", "items": ["Titre 1", "Titre 2"] } ] }

function DefaultData() as Object
    return {
        categories: [
            { name: "Films", items: ["Inception", "Interstellar", "Le Fabuleux Destin d'Amélie Poulain", "Intouchables", "Le Seigneur des Anneaux", "Retour vers le futur"] },
            { name: "Séries", items: ["Breaking Bad", "Stranger Things", "The Office", "Dark", "Game of Thrones"] },
            { name: "Animés", items: ["Fullmetal Alchemist: Brotherhood", "One Piece", "L'Attaque des Titans", "Death Note", "Demon Slayer", "Le Voyage de Chihiro"] }
        ]
    }
end function

function IsStr(v as Dynamic) as Boolean
    return v <> invalid and GetInterface(v, "ifString") <> invalid
end function

' Nettoie/valide des données reçues. Retourne invalid si le format est mauvais.
function SanitizeData(d as Dynamic) as Dynamic
    if type(d) <> "roAssociativeArray" then return invalid
    cats = d.categories
    if type(cats) <> "roArray" then return invalid
    out = []
    for each c in cats
        if type(c) = "roAssociativeArray" and IsStr(c.name) then
            name = Left(c.name.Trim(), 40)
            if name <> "" then
                items = []
                if type(c.items) = "roArray" then
                    for each it in c.items
                        if IsStr(it) then
                            t = Left(it.Trim(), 120)
                            if t <> "" then items.Push(t)
                        end if
                    end for
                end if
                out.Push({ name: name, items: items })
            end if
        end if
    end for
    return { categories: out }
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

function LoadDataJson() as String
    sec = CreateObject("roRegistrySection", "hasard")
    if sec.Exists("data") then
        s = sec.Read("data")
        d = SanitizeData(ParseJson(s))
        if d <> invalid then return FormatJson(d)
    end if
    return FormatJson(DefaultData())
end function

' Retourne "" si OK, sinon un message d'erreur.
function SaveDataJson(json as String) as String
    if ByteLen(json) > MaxDataBytes() then return "Liste trop grande (max " + MaxDataBytes().ToStr() + " octets)"
    sec = CreateObject("roRegistrySection", "hasard")
    if not sec.Write("data", json) then return "Erreur d'écriture"
    sec.Flush()
    return ""
end function
