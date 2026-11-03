sub init()
    m.top.functionName = "fetchDetails"
end sub

' ref = "t:<id TVmaze>" | "m:<id MyAnimeList>" | "i:<id iTunes>"
' result = { ref, ok, poster, synopsis, genres, runtime, score, extra }
sub fetchDetails()
    ref = m.top.ref
    kind = Left(ref, 2)
    id = Mid(ref, 3)
    res = { ref: ref, ok: false, poster: "", synopsis: "", genres: "", runtime: 0, score: "", extra: "" }

    if kind = "t:" then
        j = getJson("https://api.tvmaze.com/shows/" + id + "?embed=seasons")
        if type(j) = "roAssociativeArray" then
            res.ok = true
            res.synopsis = cleanText(AnyToStr(j.summary))
            if type(j.image) = "roAssociativeArray" then
                res.poster = AnyToStr(j.image.original)
                if res.poster = "" then res.poster = AnyToStr(j.image.medium)
            end if
            res.genres = joinStrings(j.genres)
            res.runtime = ToInt(j.runtime)
            if res.runtime = 0 then res.runtime = ToInt(j.averageRuntime)
            if type(j.rating) = "roAssociativeArray" then res.score = formatScore(j.rating.average, 10)
            extra = []
            emb = j["_embedded"]
            if type(emb) = "roAssociativeArray" and type(emb.seasons) = "roArray" then
                n = emb.seasons.Count()
                if n = 1 then
                    extra.Push("1 saison")
                else if n > 1 then
                    extra.Push(n.ToStr() + " saisons")
                end if
            end if
            st = AnyToStr(j.status)
            if st = "Ended" then
                extra.Push("terminée")
            else if st = "Running" then
                extra.Push("en cours")
            end if
            if type(j.network) = "roAssociativeArray" then
                extra.Push(AnyToStr(j.network.name))
            else if type(j.webChannel) = "roAssociativeArray" then
                extra.Push(AnyToStr(j.webChannel.name))
            end if
            res.extra = joinStrings(extra)
        end if

    else if kind = "m:" then
        j = getJson("https://api.jikan.moe/v4/anime/" + id)
        if type(j) = "roAssociativeArray" and type(j.data) = "roAssociativeArray" then
            a = j.data
            res.ok = true
            syn = AnyToStr(a.synopsis)
            cut = Instr(1, syn, "[Written by")
            if cut > 0 then syn = Left(syn, cut - 1)
            res.synopsis = cleanText(syn)
            if type(a.images) = "roAssociativeArray" and type(a.images.jpg) = "roAssociativeArray" then
                res.poster = AnyToStr(a.images.jpg.large_image_url)
                if res.poster = "" then res.poster = AnyToStr(a.images.jpg.image_url)
            end if
            names = []
            if type(a.genres) = "roArray" then
                for each g in a.genres
                    if type(g) = "roAssociativeArray" then names.Push(AnyToStr(g.name))
                end for
            end if
            res.genres = joinStrings(names)
            res.runtime = parseJikanDuration(AnyToStr(a.duration))
            res.score = formatScore(a.score, 10)
            extra = []
            if IsStr(a.type) then extra.Push(a.type)
            eps = ToInt(a.episodes)
            if eps = 1 then
                extra.Push("1 épisode")
            else if eps > 1 then
                extra.Push(eps.ToStr() + " épisodes")
            end if
            if type(a.studios) = "roArray" and a.studios.Count() > 0 then
                if type(a.studios[0]) = "roAssociativeArray" then extra.Push(AnyToStr(a.studios[0].name))
            end if
            res.extra = joinStrings(extra)
        end if

    else if kind = "i:" then
        r = itunesLookup(id, m.top.country)
        if r = invalid and m.top.country <> "us" then r = itunesLookup(id, "us")
        if r <> invalid then
            res.ok = true
            syn = AnyToStr(r.longDescription)
            if syn = "" then syn = AnyToStr(r.shortDescription)
            res.synopsis = cleanText(syn)
            art = AnyToStr(r.artworkUrl100)
            if art <> "" then
                slash = lastSlash(art)
                if slash > 0 then res.poster = Left(art, slash) + "400x600bb.jpg" else res.poster = art
            end if
            res.genres = AnyToStr(r.primaryGenreName)
            ms = ToInt(r.trackTimeMillis)
            if ms > 0 then res.runtime = Int(ms / 60000)
            extra = []
            if IsStr(r.contentAdvisoryRating) then extra.Push(r.contentAdvisoryRating)
            if IsStr(r.artistName) then extra.Push("de " + r.artistName)
            res.extra = joinStrings(extra)
        end if
    end if

    m.top.result = res
end sub

function itunesLookup(id as String, country as String) as Dynamic
    j = getJson("https://itunes.apple.com/lookup?id=" + id + "&country=" + country)
    if type(j) = "roAssociativeArray" and type(j.results) = "roArray" and j.results.Count() > 0 then
        if type(j.results[0]) = "roAssociativeArray" then return j.results[0]
    end if
    return invalid
end function

function getJson(url as String) as Dynamic
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.EnableEncodings(true)
    ut.AddHeader("Accept", "application/json")
    port = CreateObject("roMessagePort")
    ut.SetMessagePort(port)
    if not ut.AsyncGetToString() then return invalid
    msg = wait(10000, port)
    if type(msg) <> "roUrlEvent" then
        ut.AsyncCancel()
        return invalid
    end if
    if msg.GetResponseCode() <> 200 then return invalid
    return ParseJson(msg.GetString())
end function

function cleanText(s as String) as String
    s = CreateObject("roRegex", "<[^>]*>", "").ReplaceAll(s, "")
    s = s.Replace("&amp;", "&").Replace("&quot;", Chr(34)).Replace("&#39;", "'").Replace("&nbsp;", " ").Replace("&lt;", "<").Replace("&gt;", ">")
    s = CreateObject("roRegex", "\s+", "").ReplaceAll(s, " ")
    s = s.Trim()
    if Len(s) > 900 then s = Left(s, 897) + "..."
    return s
end function

function joinStrings(list as Dynamic) as String
    out = ""
    if type(list) <> "roArray" then return out
    for each x in list
        v = AnyToStr(x)
        if v <> "" then
            if out <> "" then out = out + "  -  "
            out = out + v
        end if
    end for
    return out
end function

function formatScore(v as Dynamic, outOf as Integer) as String
    if not IsNum(v) then return ""
    x = Int(v * 10 + 0.5)
    if x <= 0 then return ""
    whole = Int(x / 10)
    dec = x - whole * 10
    return whole.ToStr() + "," + dec.ToStr() + "/" + outOf.ToStr()
end function

' "24 min per ep" -> 24 ; "1 hr 50 min" -> 110
function parseJikanDuration(s as String) as Integer
    total = 0
    re = CreateObject("roRegex", "(\d+)\s*hr", "i")
    mm = re.Match(s)
    if mm.Count() > 1 then total = mm[1].ToInt() * 60
    re = CreateObject("roRegex", "(\d+)\s*min", "i")
    mm = re.Match(s)
    if mm.Count() > 1 then total = total + mm[1].ToInt()
    return total
end function

function lastSlash(s as String) as Integer
    lastPos = 0
    i = Instr(1, s, "/")
    while i > 0
        lastPos = i
        i = Instr(i + 1, s, "/")
    end while
    return lastPos
end function
