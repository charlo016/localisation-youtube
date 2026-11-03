sub init()
    m.menu = m.top.findNode("menu")
    m.catList = m.top.findNode("catList")
    m.result = m.top.findNode("result")
    m.resCat = m.top.findNode("resCat")
    m.resTitle = m.top.findNode("resTitle")
    m.resHint = m.top.findNode("resHint")
    m.resPh = m.top.findNode("resPh")
    m.resPoster = m.top.findNode("resPoster")
    m.listView = m.top.findNode("listView")
    m.listTitle = m.top.findNode("listTitle")
    m.listSub = m.top.findNode("listSub")
    m.itemList = m.top.findNode("itemList")
    m.listPoster = m.top.findNode("listPoster")
    m.footer = m.top.findNode("footer")
    m.toast = m.top.findNode("toast")
    m.rollTimer = m.top.findNode("rollTimer")
    m.toastTimer = m.top.findNode("toastTimer")

    m.rolling = false
    m.lastPick = ""
    m.currentIdx = 0
    m.listIdx = 0
    m.listMap = []
    m.final = invalid

    m.catList.observeField("itemSelected", "onCatSelected")
    m.itemList.observeField("itemSelected", "onItemToggled")
    m.itemList.observeField("itemFocused", "onItemFocused")
    m.rollTimer.observeField("fire", "onRollTick")
    m.toastTimer.observeField("fire", "onToastDone")

    ' Serveur web pour éditer la liste
    m.port = 8888
    m.url = "http://" + getIp() + ":" + m.port.ToStr()
    m.footer.text = "Modifier la liste : " + m.url
    m.server = m.top.findNode("server")
    m.server.port = m.port
    m.server.observeField("dataJson", "onDataUpdated")
    m.server.observeField("error", "onServerError")
    m.server.control = "RUN"

    m.data = LoadData()
    refreshMenu()
    showMenu()
end sub

function getIp() as String
    ips = CreateObject("roDeviceInfo").GetIPAddrs()
    for each k in ips
        return ips[k]
    end for
    return "IP-de-la-Roku"
end function

function itemLabel(it as Object) as String
    s = it.t
    if IsStr(it.y) then s = s + " (" + it.y + ")"
    return s
end function

' ---------- Données ----------

sub onDataUpdated()
    d = SanitizeData(ParseJson(m.server.dataJson))
    if d = invalid then return
    m.data = d
    refreshMenu()
    if m.listView.visible then buildListView(false)
    showToast("Liste mise à jour !")
end sub

sub persist()
    err = SaveDataJson(FormatJson(m.data))
    if err <> "" then showToast(err)
    refreshMenu()
end sub

sub onServerError()
    m.footer.text = m.server.error
end sub

' ---------- Menu des catégories ----------

sub refreshMenu()
    total = 0
    todo = 0
    for each c in m.data.c
        for each it in c.i
            total = total + 1
            if not IsWatched(it) then todo = todo + 1
        end for
    end for

    content = CreateObject("roSGNode", "ContentNode")
    all = content.createChild("ContentNode")
    all.title = "Surprise ! (tout mélangé)   " + todo.ToStr() + " à voir"
    for each c in m.data.c
        n = 0
        for each it in c.i
            if not IsWatched(it) then n = n + 1
        end for
        item = content.createChild("ContentNode")
        item.title = c.n + "   " + n.ToStr() + " à voir / " + c.i.Count().ToStr()
    end for

    focus = m.catList.itemFocused
    m.catList.content = content
    if focus <> invalid and focus >= 0 and focus < content.getChildCount() then m.catList.jumpToItem = focus
end sub

sub showMenu()
    m.rollTimer.control = "stop"
    m.rolling = false
    m.result.visible = false
    m.listView.visible = false
    m.menu.visible = true
    m.catList.setFocus(true)
end sub

sub onCatSelected()
    m.currentIdx = m.catList.itemSelected
    startPick()
end sub

' ---------- Tirage au hasard ----------

' Liste des titres pas encore vus : { item, cat }
function buildPool(idx as Integer) as Object
    pool = []
    cats = m.data.c
    for i = 0 to cats.Count() - 1
        if idx = 0 or idx - 1 = i then
            for each it in cats[i].i
                if not IsWatched(it) then pool.Push({ item: it, cat: cats[i].n })
            end for
        end if
    end for
    return pool
end function

function countItems(idx as Integer) as Integer
    n = 0
    cats = m.data.c
    for i = 0 to cats.Count() - 1
        if idx = 0 or idx - 1 = i then n = n + cats[i].i.Count()
    end for
    return n
end function

sub startPick()
    m.menu.visible = false
    m.listView.visible = false
    m.result.visible = true
    m.result.setFocus(true)
    m.resPoster.uri = ""
    m.resPh.text = "?"
    m.final = invalid

    m.pool = buildPool(m.currentIdx)
    n = m.pool.Count()
    if n = 0 then
        m.resCat.text = ""
        m.resTitle.color = "0xFFFFFFFF"
        if countItems(m.currentIdx) > 0 then
            m.resTitle.text = "Tout a été vu !"
            m.resHint.text = "Décoche des titres dans la liste (Droite sur le menu) ou ajoute-en sur " + m.url + Chr(10) + "Retour : catégories"
        else
            m.resTitle.text = "Rien ici pour l'instant !"
            m.resHint.text = "Ajoute des titres sur " + m.url + Chr(10) + "Retour : catégories"
        end if
        return
    end if

    ' Tirage final (évite de retomber sur le même titre deux fois de suite)
    pick = Rnd(n) - 1
    tries = 0
    while n > 1 and m.pool[pick].item.t = m.lastPick and tries < 20
        pick = Rnd(n) - 1
        tries = tries + 1
    end while
    m.final = m.pool[pick]

    m.ticks = 0
    m.rolling = true
    m.resHint.text = ""
    m.resTitle.color = "0x8A8AA0FF"
    m.rollTimer.control = "start"
end sub

sub onRollTick()
    m.ticks = m.ticks + 1
    if m.ticks < 20 then
        r = m.pool[Rnd(m.pool.Count()) - 1]
        m.resCat.text = UCase(r.cat)
        m.resTitle.text = r.item.t
        return
    end if
    m.rollTimer.control = "stop"
    m.rolling = false
    it = m.final.item
    m.lastPick = it.t
    cat = UCase(m.final.cat)
    if IsStr(it.y) then cat = cat + "   " + it.y
    m.resCat.text = cat
    m.resTitle.color = "0xFFFFFFFF"
    m.resTitle.text = it.t
    m.resPoster.uri = PosterUrl(it.p)
    if m.resPoster.uri <> "" then m.resPh.text = "" else m.resPh.text = "?"
    updateResultHint()
end sub

sub updateResultHint()
    if m.final <> invalid and IsWatched(m.final.item) then
        m.resHint.text = "Marqué comme vu  -  ne sortira plus au hasard" + Chr(10) + "OK : relancer     * : annuler « vu »     Retour : catégories"
    else
        m.resHint.text = "OK : relancer     * : marquer comme vu     Retour : catégories"
    end if
end sub

sub toggleFinalWatched()
    if m.final = invalid then return
    it = m.final.item
    if IsWatched(it) then
        it.Delete("w")
    else
        it.w = 1
    end if
    persist()
    updateResultHint()
end sub

' ---------- Liste d'une catégorie (cases « vu ») ----------

sub openList(idx as Integer)
    m.listIdx = idx
    m.menu.visible = false
    m.result.visible = false
    m.listView.visible = true
    buildListView(true)
    m.itemList.setFocus(true)
end sub

sub buildListView(resetFocus as Boolean)
    cats = m.data.c
    if m.listIdx > cats.Count() then m.listIdx = 0
    if m.listIdx = 0 then
        m.listTitle.text = "Tout"
    else
        m.listTitle.text = cats[m.listIdx - 1].n
    end if

    content = CreateObject("roSGNode", "ContentNode")
    states = []
    m.listMap = []
    for i = 0 to cats.Count() - 1
        if m.listIdx = 0 or m.listIdx - 1 = i then
            for j = 0 to cats[i].i.Count() - 1
                it = cats[i].i[j]
                node = content.createChild("ContentNode")
                if m.listIdx = 0 then
                    node.title = cats[i].n + "  -  " + itemLabel(it)
                else
                    node.title = itemLabel(it)
                end if
                states.Push(IsWatched(it))
                m.listMap.Push([i, j])
            end for
        end if
    end for

    if m.listMap.Count() = 0 then
        m.listSub.text = "Liste vide. Ajoute des titres sur " + m.url
    else
        m.listSub.text = "Coche ce que t'as déjà vu : ça ne sortira plus au hasard."
    end if

    focus = m.itemList.itemFocused
    m.itemList.content = content
    m.itemList.checkedState = states
    if not resetFocus and focus <> invalid and focus >= 0 and focus < m.listMap.Count() then
        m.itemList.jumpToItem = focus
    end if
    onItemFocused()
end sub

function listItemAt(idx as Integer) as Dynamic
    if idx < 0 or idx >= m.listMap.Count() then return invalid
    ref = m.listMap[idx]
    return m.data.c[ref[0]].i[ref[1]]
end function

sub onItemFocused()
    it = listItemAt(m.itemList.itemFocused)
    if it = invalid then
        m.listPoster.uri = ""
    else
        m.listPoster.uri = PosterUrl(it.p)
    end if
end sub

sub onItemToggled()
    idx = m.itemList.itemSelected
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
end sub

' ---------- Petits messages ----------

sub showToast(text as String)
    m.toast.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.visible = false
end sub

' ---------- Télécommande ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.result.visible then
        if key = "OK" or key = "play" then
            if not m.rolling then startPick()
            return true
        else if key = "options" then
            if not m.rolling then toggleFinalWatched()
            return true
        else if key = "back" then
            showMenu()
            return true
        end if
    else if m.listView.visible then
        if key = "back" or key = "left" then
            showMenu()
            return true
        end if
    else if m.menu.visible then
        if key = "right" or key = "options" then
            openList(m.catList.itemFocused)
            return true
        end if
    end if
    return false
end function
