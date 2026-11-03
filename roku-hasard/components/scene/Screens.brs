' ============================================================================
' Écrans : fiche d'un titre, liste d'une catégorie, filtres/paramètres,
' historique, statistiques + chargement des détails depuis Internet
' ============================================================================

' ---------- Fiche d'un titre ----------
' mode : "pick" (tirage 1 titre), "choice" (venu des 3 choix), "view" (consultation)

sub showFiche(entry as Object, mode as String, returnTo as String)
    m.cur = entry
    m.ficheMode = mode
    m.ficheReturn = returnTo
    m.btnIdx = 0
    showScreen("result")
    m.resTitle.color = "0xFFFFFFFF"
    fillFiche()
end sub

sub fillFiche()
    if m.cur = invalid then return
    it = m.cur.item
    det = invalid
    if IsStr(it.s) then
        det = m.details[it.s]
        if det = invalid then requestDetails(it.s)
    end if

    head = UCase(m.cur.cat)
    if IsStr(it.y) then head = head + "   " + it.y
    m.resCat.text = head
    m.resTitle.text = it.t

    ' Genres, durée, note publique, infos
    meta = []
    g = GenreNames(it.g)
    if g = "" and det <> invalid then g = det.genres
    if g <> "" then meta.Push(g)
    d = ToInt(it.d)
    if d = 0 and det <> invalid then d = ToInt(det.runtime)
    if d > 0 then meta.Push(FormatDuration(d))
    if det <> invalid and det.score <> "" then meta.Push("Note " + det.score)
    if det <> invalid and det.extra <> "" then meta.Push(det.extra)
    m.resMeta.text = joinParts(meta, "   -   ")

    ' Mes infos perso
    mine = []
    if IsWatched(it) then mine.Push("Déjà vu")
    if IsFav(it) then mine.Push("Favori")
    if Rating(it) > 0 then mine.Push("Ma note : " + starText(Rating(it)))
    m.resMine.text = joinParts(mine, "   -   ")

    ' Résumé
    if not m.settings.synopsis then
        m.resSyn.text = ""
    else if det <> invalid then
        m.resSyn.text = det.synopsis
    else if IsStr(it.s) then
        m.resSyn.text = "Chargement du résumé..."
    else
        m.resSyn.text = "Pas de résumé : titre ajouté à la main. Ajoute-le depuis l'onglet Rechercher de la page web pour avoir l'affiche et le résumé."
    end if

    url = posterFor(it)
    m.resPoster.uri = url
    if url <> "" then m.resPh.text = "" else m.resPh.text = "?"

    updateButtons()
    if m.ficheMode = "pick" then
        m.resHint.text = "Gauche/Droite + OK     * : vu     Lecture : relancer     Retour : menu"
    else
        m.resHint.text = "Gauche/Droite + OK     * : vu     Retour"
    end if
end sub

function starText(r as Integer) as String
    return r.ToStr() + "/5"
end function

function joinParts(parts as Object, sep as String) as String
    out = ""
    for each p in parts
        if p <> "" then
            if out <> "" then out = out + sep
            out = out + p
        end if
    end for
    return out
end function

' ---------- Boutons de la fiche ----------

sub updateButtons()
    if m.btnL = invalid then return
    if m.ficheMode = "empty" then
        setButtons(["Retour", "", "", ""])
        return
    end if
    if m.cur = invalid then return
    it = m.cur.item
    first = "Retour"
    if m.ficheMode = "pick" then first = "Relancer"
    if m.ficheMode = "choice" then first = "Autres choix"
    vu = "Marquer vu"
    if IsWatched(it) then vu = "Pas encore vu"
    fav = "Favori"
    if IsFav(it) then fav = "Retirer favori"
    note = "Noter"
    if Rating(it) > 0 then note = "Note : " + starText(Rating(it))
    setButtons([first, vu, fav, note])
end sub

sub setButtons(labels as Object)
    m.btnLabels = labels
    m.btnCount = 0
    for i = 0 to 3
        m.btnL[i].text = labels[i]
        m.btnR[i].getParent().visible = (labels[i] <> "")
        if labels[i] <> "" then m.btnCount = i + 1
    end for
    if m.btnIdx >= m.btnCount then m.btnIdx = 0
    paintButtons()
end sub

sub paintButtons()
    for i = 0 to 3
        if i = m.btnIdx then
            m.btnR[i].color = m.accent
            m.btnL[i].color = "0x14141FFF"
        else
            m.btnR[i].color = "0x2C2C44FF"
            m.btnL[i].color = "0xEEEEF6FF"
        end if
    end for
end sub

sub moveButton(dir as Integer)
    if m.btnCount <= 1 then return
    m.btnIdx = m.btnIdx + dir
    if m.btnIdx < 0 then m.btnIdx = m.btnCount - 1
    if m.btnIdx >= m.btnCount then m.btnIdx = 0
    paintButtons()
end sub

sub pressButton(i as Integer)
    if i = 0 then
        if m.ficheMode = "pick" then
            startPick()
        else
            ficheBack()
        end if
    else if i = 1 then
        toggleWatched()
    else if i = 2 then
        toggleFav()
    else if i = 3 then
        cycleRating()
    end if
end sub

sub ficheBack()
    if m.ficheReturn = "choices" then
        showScreen("choices")
        refreshChoicePosters()
    else if m.ficheReturn = "listView" then
        showScreen("listView")
        buildList(false)
    else if m.ficheReturn = "histView" then
        showScreen("histView")
    else
        goMenu()
    end if
end sub

sub toggleWatched()
    if m.cur = invalid then return
    it = m.cur.item
    if IsWatched(it) then
        it.Delete("w")
        showToast("Remis dans « à voir »")
    else
        it.w = 1
        showToast("Marqué comme vu : il ne sortira plus au hasard")
    end if
    persist()
    fillFiche()
end sub

sub toggleFav()
    if m.cur = invalid then return
    it = m.cur.item
    if IsFav(it) then
        it.Delete("f")
    else
        it.f = 1
        showToast("Ajouté aux favoris : il sortira plus souvent")
    end if
    persist()
    fillFiche()
end sub

sub cycleRating()
    if m.cur = invalid then return
    it = m.cur.item
    r = Rating(it) + 1
    if r > 5 then
        it.Delete("r")
    else
        it.r = r
    end if
    persist()
    fillFiche()
end sub

' ---------- Détails depuis Internet (affiche, résumé...) ----------

function posterFor(it as Object) as String
    if IsStr(it.p) and it.p <> "" then return PosterUrl(it.p)
    if IsStr(it.s) then
        det = m.details[it.s]
        if det <> invalid then return det.poster
        requestDetails(it.s)
    end if
    return ""
end function

sub requestDetails(ref as String)
    if m.details.DoesExist(ref) or m.tasks.DoesExist(ref) then return
    t = CreateObject("roSGNode", "DetailsTask")
    t.ref = ref
    t.country = m.settings.country
    t.observeField("result", "onDetails")
    m.tasks[ref] = t
    t.control = "RUN"
end sub

sub onDetails(event as Object)
    res = event.getData()
    if res = invalid or not IsStr(res.ref) then return
    m.tasks.Delete(res.ref)
    if not res.ok then
        res.synopsis = "Résumé indisponible (pas d'Internet ?)"
    end if
    m.details[res.ref] = res

    if m.screen = "result" and m.cur <> invalid and IsStr(m.cur.item.s) and m.cur.item.s = res.ref then
        fillFiche()
    else if m.screen = "choices" then
        refreshChoicePosters()
    else if m.screen = "listView" then
        it = listItemAt(m.itemList.itemFocused)
        if it <> invalid and IsStr(it.s) and it.s = res.ref then showListItem(it)
    end if
end sub

' ---------- Liste d'une catégorie ----------

sub openList(k as Integer)
    m.listKey = k
    showScreen("listView")
    buildList(true)
end sub

function sortName(s as String) as String
    if s = "az" then return "A à Z"
    if s = "year" then return "année"
    if s = "rating" then return "ma note"
    return "ordre d'ajout"
end function

sub buildList(resetFocus as Boolean)
    cats = m.data.c
    if m.listKey > cats.Count() then m.listKey = 0
    rows = []
    order = 0
    for i = 0 to cats.Count() - 1
        if m.listKey = 0 or m.listKey - 1 = i then
            for j = 0 to cats[i].i.Count() - 1
                it = cats[i].i[j]
                rows.Push({ ci: i, ii: j, k: LCase(it.t), y: ToInt(it.y), r: Rating(it), o: order })
                order = order + 1
            end for
        end if
    end for
    s = m.settings.sort
    if s = "az" then
        rows.SortBy("k")
    else if s = "year" then
        rows.SortBy("y", "r")
    else if s = "rating" then
        rows.SortBy("r", "r")
    end if

    content = CreateObject("roSGNode", "ContentNode")
    states = []
    m.listMap = []
    seen = 0
    for each row in rows
        it = cats[row.ci].i[row.ii]
        node = content.createChild("ContentNode")
        label = it.t
        if IsStr(it.y) then label = label + " (" + it.y + ")"
        if m.listKey = 0 then label = cats[row.ci].n + "  -  " + label
        if Rating(it) > 0 then label = label + "   " + starText(Rating(it))
        if IsFav(it) then label = label + "   [fav]"
        node.title = label
        states.Push(IsWatched(it))
        if IsWatched(it) then seen = seen + 1
        m.listMap.Push([row.ci, row.ii])
    end for

    if m.listKey = 0 then
        m.listTitle.text = "Tous les titres"
    else
        m.listTitle.text = cats[m.listKey - 1].n
    end if
    if m.listMap.Count() = 0 then
        m.listSub.text = "Liste vide. Ajoute des titres sur " + m.url
    else
        m.listSub.text = (m.listMap.Count() - seen).ToStr() + " à voir  -  " + seen.ToStr() + " vus  -  tri : " + sortName(s)
    end if

    focus = m.itemList.itemFocused
    m.itemList.content = content
    m.itemList.checkedState = states
    if not resetFocus and focus <> invalid and focus >= 0 and focus < m.listMap.Count() then
        m.itemList.jumpToItem = focus
    end if
    onListFocusSettled()
end sub

function listItemAt(idx as Integer) as Dynamic
    if idx < 0 or idx >= m.listMap.Count() then return invalid
    ref = m.listMap[idx]
    return m.data.c[ref[0]].i[ref[1]]
end function

sub onListFocused()
    ' Attend que le défilement se calme avant de charger l'affiche
    it = listItemAt(m.itemList.itemFocused)
    if it <> invalid then showListText(it)
    m.focusTimer.control = "stop"
    m.focusTimer.control = "start"
end sub

sub onListFocusSettled()
    it = listItemAt(m.itemList.itemFocused)
    if it = invalid then
        m.listPoster.uri = ""
        m.listInfo.text = ""
        return
    end if
    showListItem(it)
end sub

sub showListItem(it as Object)
    m.listPoster.uri = posterFor(it)
    showListText(it)
end sub

sub showListText(it as Object)
    parts = []
    g = GenreNames(it.g)
    if g <> "" then parts.Push(g)
    d = ToInt(it.d)
    if d > 0 then parts.Push(FormatDuration(d))
    mine = []
    if IsWatched(it) then mine.Push("Vu")
    if IsFav(it) then mine.Push("Favori")
    if Rating(it) > 0 then mine.Push("Ma note " + starText(Rating(it)))
    txt = joinParts(parts, "  -  ")
    if mine.Count() > 0 then txt = txt + Chr(10) + joinParts(mine, "  -  ")
    m.listInfo.text = txt
end sub

sub onListSelected()
    idx = m.itemList.itemSelected
    if idx < 0 or idx >= m.listMap.Count() then return
    ref = m.listMap[idx]
    showFiche({ item: m.data.c[ref[0]].i[ref[1]], cat: m.data.c[ref[0]].n }, "view", "listView")
end sub

sub toggleListWatched()
    idx = m.itemList.itemFocused
    it = listItemAt(idx)
    if it = invalid then return
    if IsWatched(it) then
        it.Delete("w")
    else
        it.w = 1
    end if
    states = m.itemList.checkedState
    states[idx] = IsWatched(it)
    m.itemList.checkedState = states
    persist()
    showListText(it)
    buildListSubOnly()
end sub

sub buildListSubOnly()
    seen = 0
    for i = 0 to m.listMap.Count() - 1
        if IsWatched(listItemAt(i)) then seen = seen + 1
    end for
    m.listSub.text = (m.listMap.Count() - seen).ToStr() + " à voir  -  " + seen.ToStr() + " vus  -  tri : " + sortName(m.settings.sort)
end sub

sub cycleSort()
    order = ["added", "az", "year", "rating"]
    idx = 0
    for i = 0 to order.Count() - 1
        if order[i] = m.settings.sort then idx = i
    end for
    m.settings.sort = order[(idx + 1) mod order.Count()]
    persistSettings()
    buildList(true)
    showToast("Tri : " + sortName(m.settings.sort))
end sub

' ---------- Filtres et paramètres ----------

function yesNo() as Object
    return [{ v: false, l: "Non" }, { v: true, l: "Oui" }]
end function

function filterDefs() as Object
    genres = [{ v: "", l: "Tous" }]
    for each g in GenreList()
        genres.Push({ v: g.k, l: g.n })
    end for
    return [
        { key: "fgenre", label: "Genre", values: genres }
        { key: "fdur", label: "Durée max (film ou épisode)", values: [{ v: 0, l: "Peu importe" }, { v: 30, l: "30 min" }, { v: 60, l: "1 h" }, { v: 90, l: "1 h 30" }, { v: 120, l: "2 h" }, { v: 150, l: "2 h 30" }] }
        { key: "fdec", label: "Époque", values: [{ v: "", l: "Toutes" }, { v: "old", l: "Avant 1980" }, { v: "1980", l: "Années 80" }, { v: "1990", l: "Années 90" }, { v: "2000", l: "Années 2000" }, { v: "2010", l: "Années 2010" }, { v: "2020", l: "Années 2020" }] }
        { key: "ffav", label: "Seulement les favoris", values: yesNo() }
        { key: "fwatched", label: "Inclure les déjà vus", values: yesNo() }
        { key: "", label: "Effacer tous les filtres", action: "resetFilters" }
    ]
end function

function settingsDefs() as Object
    return [
        { key: "mode", label: "Mode de tirage", values: [{ v: "one", l: "1 titre" }, { v: "three", l: "3 choix proposés" }] }
        { key: "anim", label: "Animation", values: [{ v: "normal", l: "Normale" }, { v: "fast", l: "Rapide" }, { v: "off", l: "Aucune" }] }
        { key: "avoid", label: "Éviter les derniers tirages", values: [{ v: 0, l: "Non" }, { v: 1, l: "Le dernier" }, { v: 3, l: "Les 3 derniers" }, { v: 5, l: "Les 5 derniers" }, { v: 10, l: "Les 10 derniers" }] }
        { key: "favw", label: "Chances des favoris", values: [{ v: 1, l: "Normales" }, { v: 2, l: "x2" }, { v: 3, l: "x3" }, { v: 5, l: "x5" }] }
        { key: "synopsis", label: "Afficher le résumé", values: yesNo() }
        { key: "sound", label: "Sons", values: yesNo() }
        { key: "accent", label: "Couleur", values: [{ v: "gold", l: "Or" }, { v: "blue", l: "Bleu" }, { v: "pink", l: "Rose" }, { v: "green", l: "Vert" }, { v: "orange", l: "Orange" }, { v: "purple", l: "Violet" }] }
        { key: "sort", label: "Tri des listes", values: [{ v: "added", l: "Ordre d'ajout" }, { v: "az", l: "A à Z" }, { v: "year", l: "Année" }, { v: "rating", l: "Ma note" }] }
        { key: "country", label: "Boutique iTunes (films)", values: [{ v: "us", l: "États-Unis" }, { v: "ca", l: "Canada" }, { v: "fr", l: "France (titres en français)" }] }
        { key: "", label: "Effacer l'historique des tirages", action: "clearHistory" }
        { key: "", label: "Version " + AppVersion() + "  -  page web : " + m.url, action: "none" }
    ]
end function

sub openOptions(kind as String)
    m.optKind = kind
    if kind = "filters" then
        m.optTitle.text = "Filtres du tirage"
        m.optSub.text = "Ils s'appliquent à tous les tirages, sur la télé comme sur la page web."
    else
        m.optTitle.text = "Paramètres"
        m.optSub.text = "Prénoms des joueurs, sauvegarde et le reste : onglet « Réglages » de la page web."
    end if
    showScreen("optView")
    buildOptions(true)
end sub

sub buildOptions(resetFocus as Boolean)
    if m.optKind = "filters" then
        m.optDefs = filterDefs()
    else
        m.optDefs = settingsDefs()
    end if
    content = CreateObject("roSGNode", "ContentNode")
    for each d in m.optDefs
        node = content.createChild("ContentNode")
        if d.values = invalid then
            node.title = d.label
        else
            node.title = d.label + " :   " + d.values[optIndex(d)].l
        end if
    end for
    focus = m.optList.itemFocused
    m.optList.content = content
    if not resetFocus and focus <> invalid and focus >= 0 and focus < content.getChildCount() then m.optList.jumpToItem = focus
end sub

function optIndex(d as Object) as Integer
    cur = FormatJson(m.settings[d.key])
    for i = 0 to d.values.Count() - 1
        if FormatJson(d.values[i].v) = cur then return i
    end for
    return 0
end function

sub onOptSelected()
    cycleOption(m.optList.itemSelected, 1)
end sub

sub cycleOption(idx as Integer, dir as Integer)
    if idx < 0 or idx >= m.optDefs.Count() then return
    d = m.optDefs[idx]
    if d.values = invalid then
        if dir <> 1 then return
        if d.action = "resetFilters" then
            def = DefaultSettings()
            for each k in ["fgenre", "fdur", "fdec", "ffav", "fwatched"]
                m.settings[k] = def[k]
            end for
            persistSettings()
            showToast("Filtres effacés")
        else if d.action = "clearHistory" then
            m.history = []
            SaveHistory(m.history)
            showToast("Historique effacé")
        end if
    else
        n = d.values.Count()
        i = (optIndex(d) + dir + n) mod n
        m.settings[d.key] = d.values[i].v
        persistSettings()
        if d.key = "accent" then applyTheme()
    end if
    buildOptions(false)
end sub

' ---------- Historique ----------

sub showHistory()
    showScreen("histView")
    content = CreateObject("roSGNode", "ContentNode")
    for each e in m.history
        node = content.createChild("ContentNode")
        label = formatDate(e.ts) + "     " + e.t
        if e.c <> "" then label = label + "   (" + e.c + ")"
        node.title = label
    end for
    m.histList.content = content
    if m.history.Count() = 0 then
        m.histSub.text = "Aucun tirage pour l'instant."
    else
        if m.history.Count() = 1 then
            m.histSub.text = "1 tirage"
        else
            m.histSub.text = "Les " + m.history.Count().ToStr() + " derniers tirages (le plus récent en haut)"
        end if
    end if
end sub

function formatDate(ts as Integer) as String
    if ts <= 0 then return "--/--"
    dt = CreateObject("roDateTime")
    dt.FromSeconds(ts)
    dt.ToLocalTime()
    return pad2(dt.GetDayOfMonth()) + "/" + pad2(dt.GetMonth()) + "  " + pad2(dt.GetHours()) + "h" + pad2(dt.GetMinutes())
end function

function pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

sub onHistSelected()
    idx = m.histList.itemSelected
    if idx < 0 or idx >= m.history.Count() then return
    e = m.history[idx]
    found = findEntry(e.c, e.t)
    if found = invalid then
        showToast("Ce titre n'est plus dans la liste")
        return
    end if
    showFiche(found, "view", "histView")
end sub

' ---------- Statistiques ----------

sub showStats()
    showScreen("statsView")
    nl = Chr(10)
    total = 0
    seen = 0
    favs = 0
    rated = 0
    sumR = 0
    mins = 0
    genreCount = {}
    txtL = ""
    for each c in m.data.c
        cs = 0
        for each it in c.i
            total = total + 1
            if IsWatched(it) then
                seen = seen + 1
                cs = cs + 1
                mins = mins + ToInt(it.d)
            end if
            if IsFav(it) then favs = favs + 1
            if Rating(it) > 0 then
                rated = rated + 1
                sumR = sumR + Rating(it)
            end if
            if IsStr(it.g) then
                for i = 1 to Len(it.g)
                    k = Mid(it.g, i, 1)
                    if genreCount.DoesExist(k) then genreCount[k] = genreCount[k] + 1 else genreCount[k] = 1
                end for
            end if
        end for
        pct = 0
        if c.i.Count() > 0 then pct = Int(cs * 100 / c.i.Count())
        txtL = txtL + c.n + " : " + cs.ToStr() + " / " + c.i.Count().ToStr() + " vus (" + pct.ToStr() + " %)" + nl
    end for

    head = "Titres : " + total.ToStr() + nl
    head = head + "Déjà vus : " + seen.ToStr() + nl
    head = head + "À voir : " + (total - seen).ToStr() + nl
    head = head + "Favoris : " + favs.ToStr() + nl
    if rated > 0 then
        avg = Int(sumR * 10 / rated)
        head = head + "Note moyenne : " + Int(avg / 10).ToStr() + "," + (avg mod 10).ToStr() + "/5 (" + rated.ToStr() + " notés)" + nl
    end if
    if mins > 0 then head = head + "Temps devant l'écran (approx.) : " + FormatDuration(mins) + nl
    head = head + "Tirages enregistrés : " + m.history.Count().ToStr() + nl
    m.statsLeft.text = head + nl + txtL

    ' Top genres
    tops = []
    for each k in genreCount
        tops.Push({ k: UCase(k), n: genreCount[k] })
    end for
    tops.SortBy("n", "r")
    txtR = "Genres les plus présents :" + nl
    i = 0
    for each g in tops
        if i >= 6 then exit for
        txtR = txtR + "  " + GenreName(g.k) + " : " + g.n.ToStr() + nl
        i = i + 1
    end for
    if tops.Count() = 0 then txtR = txtR + "  (aucun genre connu)" + nl

    ' Meilleures notes
    best = []
    for each c in m.data.c
        for each it in c.i
            if Rating(it) > 0 then best.Push({ t: it.t, r: Rating(it) })
        end for
    end for
    best.SortBy("r", "r")
    if best.Count() > 0 then
        txtR = txtR + nl + "Mes mieux notés :" + nl
        i = 0
        for each b in best
            if i >= 5 then exit for
            txtR = txtR + "  " + starText(b.r) + "  " + b.t + nl
            i = i + 1
        end for
    end if
    m.statsRight.text = txtR
end sub
