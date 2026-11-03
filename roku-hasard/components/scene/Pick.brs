' ============================================================================
' Tirage au hasard : pool filtré, poids des favoris, anti-répétition,
' animation, mode 3 choix et « Qui choisit ce soir ? »
' ============================================================================

' Titres qui passent les filtres pour la clé k (0 = tout, i+1 = catégorie i)
function buildPool(k as Integer) as Object
    pool = []
    cats = m.data.c
    for i = 0 to cats.Count() - 1
        if k = 0 or k - 1 = i then
            for each it in cats[i].i
                if PassesFilters(it, m.settings) then pool.Push({ item: it, cat: cats[i].n })
            end for
        end if
    end for
    return pool
end function

function countAvailable(k as Integer) as Integer
    return buildPool(k).Count()
end function

function countAll(k as Integer) as Integer
    n = 0
    cats = m.data.c
    for i = 0 to cats.Count() - 1
        if k = 0 or k - 1 = i then n = n + cats[i].i.Count()
    end for
    return n
end function

' Choisit un élément au hasard (favoris plus probables, évite les derniers tirages)
function weightedPick(pool as Object, exclude as Object) as Dynamic
    if pool.Count() = 0 then return invalid
    recent = {}
    n = m.settings.avoid
    for i = 0 to m.history.Count() - 1
        if i >= n then exit for
        recent[m.history[i].t] = true
    end for

    cands = []
    for each e in pool
        if not exclude.DoesExist(e.item.t) and not recent.DoesExist(e.item.t) then cands.Push(e)
    end for
    if cands.Count() = 0 then
        ' Pas assez de titres : on ignore l'anti-répétition
        for each e in pool
            if not exclude.DoesExist(e.item.t) then cands.Push(e)
        end for
    end if
    if cands.Count() = 0 then return invalid

    total = 0
    for each e in cands
        total = total + itemWeight(e.item)
    end for
    r = Rnd(total)
    for each e in cands
        r = r - itemWeight(e.item)
        if r <= 0 then return e
    end for
    return cands[cands.Count() - 1]
end function

function itemWeight(it as Object) as Integer
    if IsFav(it) then return m.settings.favw
    return 1
end function

function keyName(k as Integer) as String
    if k = 0 then return "Toutes les catégories"
    if k - 1 < m.data.c.Count() then return m.data.c[k - 1].n
    return ""
end function

' ---------- Lancer un tirage ----------

sub startPick()
    stopRoll()
    m.pool = buildPool(m.pickKey)
    if m.pool.Count() = 0 then
        showEmptyResult()
        return
    end if
    if m.settings.mode = "three" and m.pool.Count() > 1 then
        startChoices()
    else
        startOne()
    end if
end sub

sub showEmptyResult()
    m.cur = invalid
    m.ficheMode = "empty"
    m.ficheReturn = "menu"
    showScreen("result")
    m.resPoster.uri = ""
    m.resPh.text = "?"
    m.resCat.text = UCase(keyName(m.pickKey))
    m.resMeta.text = ""
    m.resMine.text = ""
    if countAll(m.pickKey) = 0 then
        m.resTitle.text = "Rien ici pour l'instant !"
        m.resSyn.text = "Ajoute des titres depuis ton téléphone ou ton ordi : " + m.url
    else if FiltersActive(m.settings) then
        m.resTitle.text = "Aucun titre ne correspond aux filtres"
        m.resSyn.text = "Filtres actifs : " + FiltersSummary(m.settings) + Chr(10) + "Change-les dans « Filtres » au menu."
    else
        m.resTitle.text = "Tout a été vu !"
        m.resSyn.text = "Décoche des titres dans la liste (Droite sur le menu) ou ajoute-en sur " + m.url
    end if
    setButtons(["Retour", "", "", ""])
    m.resHint.text = "Retour : menu"
end sub

sub startOne()
    m.final = weightedPick(m.pool, {})
    m.cur = invalid
    m.ficheMode = "pick"
    m.ficheReturn = "menu"
    showScreen("result")
    m.resPoster.uri = ""
    m.resPh.text = "?"
    m.resMeta.text = ""
    m.resMine.text = ""
    m.resSyn.text = ""
    m.resHint.text = ""
    setButtons(["", "", "", ""])
    m.resTitle.color = "0x8A8AA0FF"
    m.rollMode = "one"
    beginRoll()
end sub

sub startChoices()
    picks = []
    used = {}
    for i = 0 to 2
        e = weightedPick(m.pool, used)
        if e = invalid then exit for
        used[e.item.t] = true
        picks.Push(e)
    end for
    m.choicesList = picks
    m.chTitle.text = "Ce soir, ce sera... (" + keyName(m.pickKey) + ")"
    showScreen("choices")
    for i = 0 to 2
        m.chPo[i].uri = ""
        m.chPh[i].text = "?"
        m.chT[i].text = ""
        m.chHi[i].visible = false
        m.chPo[i].getParent().visible = (i < picks.Count())
    end for
    m.rollMode = "three"
    beginRoll()
end sub

' ---------- Animation ----------

sub beginRoll()
    m.ticks = 0
    if m.settings.anim = "off" then
        m.maxTicks = 0
        finishRoll()
        return
    else if m.settings.anim = "fast" then
        m.maxTicks = 7
    else
        m.maxTicks = 18
    end if
    m.rolling = true
    m.rollTimer.duration = 0.05
    m.rollTimer.control = "start"
end sub

sub stopRoll()
    m.rollTimer.control = "stop"
    m.rolling = false
end sub

sub onRollTick()
    if not m.rolling then return
    m.ticks = m.ticks + 1
    if m.ticks >= m.maxTicks then
        finishRoll()
        return
    end if
    if m.ticks mod 2 = 0 then playSound(m.sndTick)
    rollFrame()
    ' Ralentit petit à petit, comme une roue qui tourne
    if m.settings.anim = "fast" then
        m.rollTimer.duration = 0.05
    else
        m.rollTimer.duration = 0.05 + m.ticks * 0.012
    end if
    m.rollTimer.control = "start"
end sub

sub rollFrame()
    if m.rollMode = "one" then
        r = m.pool[Rnd(m.pool.Count()) - 1]
        m.resCat.text = UCase(r.cat)
        m.resTitle.text = r.item.t
    else if m.rollMode = "three" then
        for i = 0 to m.choicesList.Count() - 1
            r = m.pool[Rnd(m.pool.Count()) - 1]
            m.chT[i].text = r.item.t
        end for
    else if m.rollMode = "players" then
        p = m.settings.players
        m.playerName.text = p[Rnd(p.Count()) - 1]
    end if
end sub

sub finishRoll()
    m.rolling = false
    m.rollTimer.control = "stop"
    playSound(m.sndDing)
    if m.rollMode = "one" then
        m.resTitle.color = "0xFFFFFFFF"
        addHistory(m.final.item.t, m.final.cat)
        showFiche(m.final, "pick", "menu")
    else if m.rollMode = "three" then
        for i = 0 to m.choicesList.Count() - 1
            e = m.choicesList[i]
            m.chT[i].text = e.item.t
        end for
        refreshChoicePosters()
        setChoiceFocus(1)
        if m.choicesList.Count() < 2 then setChoiceFocus(0)
    else if m.rollMode = "players" then
        p = m.settings.players
        m.playerName.text = p[m.playerPick]
        m.playerHint.text = "C'est " + p[m.playerPick] + " qui choisit !" + Chr(10) + Chr(10) + "OK : relancer     Retour : menu"
    end if
end sub

' ---------- Mode 3 choix ----------

sub refreshChoicePosters()
    for i = 0 to m.choicesList.Count() - 1
        url = posterFor(m.choicesList[i].item)
        m.chPo[i].uri = url
        if url <> "" then m.chPh[i].text = "" else m.chPh[i].text = "?"
    end for
end sub

sub setChoiceFocus(i as Integer)
    n = m.choicesList.Count()
    if n = 0 then return
    if i < 0 then i = n - 1
    if i >= n then i = 0
    m.chIdx = i
    for j = 0 to 2
        m.chHi[j].visible = (j = i)
    end for
end sub

sub openChoice()
    if m.chIdx < 0 or m.chIdx >= m.choicesList.Count() then return
    e = m.choicesList[m.chIdx]
    addHistory(e.item.t, e.cat)
    showFiche(e, "choice", "choices")
end sub

' ---------- Qui choisit ce soir ? ----------

sub startPlayers()
    showScreen("playersView")
    p = m.settings.players
    if p.Count() = 0 then
        m.playerName.text = "?"
        m.playerHint.text = "Ajoute les prénoms des joueurs dans l'onglet « Réglages » de la page web :" + Chr(10) + m.url + Chr(10) + Chr(10) + "Retour : menu"
        return
    end if
    m.playerPick = Rnd(p.Count()) - 1
    m.playerHint.text = ""
    m.rollMode = "players"
    beginRoll()
end sub

' ---------- Historique ----------

sub addHistory(title as String, catName as String)
    ts = CreateObject("roDateTime").AsSeconds()
    m.history.Unshift({ t: title, c: catName, ts: ts })
    SaveHistory(m.history)
end sub
