' ============================================================================
' Écran principal : navigation, menu, synchro avec la page web
' (voir aussi scene/Pick.brs et scene/Screens.brs)
' ============================================================================

sub init()
    m.screens = {}
    for each id in ["menu", "result", "choices", "listView", "optView", "histView", "statsView", "playersView"]
        m.screens[id] = m.top.findNode(id)
    end for
    for each id in ["accentBar", "brand", "catList", "menuInfo", "menuInfoTitle", "resCat", "resTitle", "resMeta", "resMine", "resSyn", "resPh", "resPoster", "resHint", "chTitle", "listTitle", "listSub", "itemList", "listPoster", "listInfo", "optTitle", "optSub", "optList", "histSub", "histList", "statsLeft", "statsRight", "playerName", "playerHint", "footer", "toast", "rollTimer", "toastTimer", "focusTimer", "sndTick", "sndDing"]
        m[id] = m.top.findNode(id)
    end for
    m.btnR = []
    m.btnL = []
    m.chHi = []
    m.chPh = []
    m.chPo = []
    m.chT = []
    for i = 0 to 3
        m.btnR.Push(m.top.findNode("btnR" + i.ToStr()))
        m.btnL.Push(m.top.findNode("btnL" + i.ToStr()))
    end for
    for i = 0 to 2
        m.chHi.Push(m.top.findNode("chHi" + i.ToStr()))
        m.chPh.Push(m.top.findNode("chPh" + i.ToStr()))
        m.chPo.Push(m.top.findNode("chPo" + i.ToStr()))
        m.chT.Push(m.top.findNode("chT" + i.ToStr()))
    end for

    m.screen = "menu"
    m.rolling = false
    m.rollMode = ""
    m.pickKey = 0
    m.cur = invalid
    m.ficheMode = "view"
    m.ficheReturn = "menu"
    m.btnIdx = 0
    m.choicesList = []
    m.chIdx = 0
    m.listKey = 0
    m.listMap = []
    m.optKind = ""
    m.optDefs = []
    m.menuMap = []
    m.details = {}
    m.tasks = {}

    m.catList.observeField("itemSelected", "onMenuSelected")
    m.catList.observeField("itemFocused", "onMenuFocused")
    m.itemList.observeField("itemSelected", "onListSelected")
    m.itemList.observeField("itemFocused", "onListFocused")
    m.optList.observeField("itemSelected", "onOptSelected")
    m.histList.observeField("itemSelected", "onHistSelected")
    m.rollTimer.observeField("fire", "onRollTick")
    m.toastTimer.observeField("fire", "onToastDone")
    m.focusTimer.observeField("fire", "onListFocusSettled")

    m.data = LoadData()
    m.settings = LoadSettings()
    m.history = LoadHistory()

    ' Serveur web pour éditer la liste depuis un téléphone / PC
    m.port = 8888
    m.url = "http://" + getIp() + ":" + m.port.ToStr()
    m.footer.text = "Modifier la liste : " + m.url
    m.server = m.top.findNode("server")
    m.server.port = m.port
    m.server.url = m.url
    m.server.observeField("dataJson", "onDataUpdated")
    m.server.observeField("settingsJson", "onSettingsUpdated")
    m.server.observeField("command", "onCommand")
    m.server.observeField("error", "onServerError")
    m.server.control = "RUN"

    applyTheme()
    refreshMenu()
    showScreen("menu")
end sub

function getIp() as String
    ips = CreateObject("roDeviceInfo").GetIPAddrs()
    for each k in ips
        return ips[k]
    end for
    return "IP-de-la-Roku"
end function

' ---------- Navigation ----------

sub showScreen(name as String)
    for each k in m.screens
        m.screens[k].visible = (LCase(k) = LCase(name))
    end for
    m.screen = name
    if name = "menu" then
        m.catList.setFocus(true)
    else if name = "listView" then
        m.itemList.setFocus(true)
    else if name = "optView" then
        m.optList.setFocus(true)
    else if name = "histView" then
        m.histList.setFocus(true)
    else
        m.screens[name].setFocus(true)
    end if
end sub

sub goMenu()
    stopRoll()
    refreshMenu()
    showScreen("menu")
end sub

' ---------- Thème ----------

sub applyTheme()
    m.accent = AccentColor(m.settings.accent)
    m.accentBar.color = m.accent
    for each lst in [m.catList, m.itemList, m.optList, m.histList]
        lst.focusBitmapBlendColor = m.accent
    end for
    for each lbl in [m.brand, m.menuInfoTitle, m.resCat, m.resPh, m.playerName]
        lbl.color = m.accent
    end for
    for each hi in m.chHi
        hi.color = m.accent
    end for
    updateButtons()
end sub

sub playSound(node as Object)
    if m.settings.sound then node.control = "play"
end sub

' ---------- Données ----------

sub persist()
    err = SaveDataJson(FormatJson(m.data))
    if err <> "" then showToast(err)
end sub

sub persistSettings()
    SaveSettings(m.settings)
end sub

sub onDataUpdated()
    d = SanitizeData(ParseJson(m.server.dataJson))
    if d = invalid then return
    m.data = d
    ' Retrouver le titre affiché dans la nouvelle liste
    if m.cur <> invalid then
        found = findEntry(m.cur.cat, m.cur.item.t)
        if found <> invalid then m.cur = found
    end if
    if m.screen = "menu" then
        refreshMenu()
    else if m.screen = "listView" then
        buildList(false)
    else if m.screen = "result" and not m.rolling and m.cur <> invalid then
        fillFiche()
    else if m.screen = "statsView" then
        showStats()
    end if
    showToast("Liste mise à jour !")
end sub

sub onSettingsUpdated()
    m.settings = SanitizeSettings(ParseJson(m.server.settingsJson))
    applyTheme()
    if m.screen = "menu" then
        refreshMenu()
    else if m.screen = "optView" then
        buildOptions(false)
    else if m.screen = "listView" then
        buildList(false)
    end if
    showToast("Réglages mis à jour !")
end sub

sub onServerError()
    m.footer.text = m.server.error
end sub

' Commandes envoyées depuis la page web
sub onCommand()
    cmd = m.server.command
    if cmd = invalid then return
    action = AnyToStr(cmd.action)
    if action = "pick" then
        k = ToInt(cmd.k)
        if k < 0 or k > m.data.c.Count() then k = 0
        stopRoll()
        m.pickKey = k
        startPick()
    else if action = "show" then
        ci = ToInt(cmd.c)
        ii = ToInt(cmd.i)
        if ci >= 0 and ci < m.data.c.Count() then
            if ii >= 0 and ii < m.data.c[ci].i.Count() then
                stopRoll()
                showFiche({ item: m.data.c[ci].i[ii], cat: m.data.c[ci].n }, "view", "menu")
            end if
        end if
    else if action = "players" then
        stopRoll()
        startPlayers()
    else if action = "clearHistory" then
        m.history = []
        SaveHistory(m.history)
        if m.screen = "histView" then showHistory()
        showToast("Historique effacé")
    else if action = "addHistory" then
        if IsStr(cmd.t) then addHistory(cmd.t, AnyToStr(cmd.c))
    end if
end sub

function findEntry(catName as String, title as String) as Dynamic
    for each c in m.data.c
        if c.n = catName then
            for each it in c.i
                if it.t = title then return { item: it, cat: c.n }
            end for
        end if
    end for
    ' Pas trouvé dans la catégorie : on cherche partout
    for each c in m.data.c
        for each it in c.i
            if it.t = title then return { item: it, cat: c.n }
        end for
    end for
    return invalid
end function

' ---------- Menu principal ----------

sub refreshMenu()
    content = CreateObject("roSGNode", "ContentNode")
    m.menuMap = []
    f = FiltersActive(m.settings)
    word = " à voir"
    if f then word = " dispo"

    addMenu(content, "Surprise ! (tout mélangé)     " + countAvailable(0).ToStr() + word, { kind: "pick", k: 0 })
    for i = 0 to m.data.c.Count() - 1
        c = m.data.c[i]
        addMenu(content, c.n + "     " + countAvailable(i + 1).ToStr() + word + " / " + c.i.Count().ToStr(), { kind: "pick", k: i + 1 })
    end for
    addMenu(content, "Filtres : " + FiltersSummary(m.settings), { kind: "filters" })
    addMenu(content, "Qui choisit ce soir ?", { kind: "players" })
    addMenu(content, "Historique des tirages", { kind: "history" })
    addMenu(content, "Statistiques", { kind: "stats" })
    addMenu(content, "Paramètres", { kind: "settings" })

    focus = m.catList.itemFocused
    m.catList.content = content
    if focus <> invalid and focus >= 0 and focus < content.getChildCount() then m.catList.jumpToItem = focus
    updateMenuInfo()
end sub

sub addMenu(content as Object, title as String, entry as Object)
    node = content.createChild("ContentNode")
    node.title = title
    m.menuMap.Push(entry)
end sub

sub onMenuFocused()
    updateMenuInfo()
end sub

sub updateMenuInfo()
    total = 0
    seen = 0
    favs = 0
    for each c in m.data.c
        for each it in c.i
            total = total + 1
            if IsWatched(it) then seen = seen + 1
            if IsFav(it) then favs = favs + 1
        end for
    end for
    modeTxt = "1 titre"
    if m.settings.mode = "three" then modeTxt = "3 choix"
    nl = Chr(10)
    txt = "Filtres : " + FiltersSummary(m.settings) + nl
    txt = txt + "Mode : " + modeTxt + nl + nl
    txt = txt + plural(total - seen, "titre à voir", "titres à voir") + nl
    txt = txt + plural(seen, "déjà vu", "déjà vus") + nl
    txt = txt + plural(favs, "favori", "favoris") + nl
    if m.history.Count() > 0 then txt = txt + nl + "Dernier tirage :" + nl + m.history[0].t
    m.menuInfo.text = txt
end sub

sub onMenuSelected()
    idx = m.catList.itemSelected
    if idx < 0 or idx >= m.menuMap.Count() then return
    e = m.menuMap[idx]
    if e.kind = "pick" then
        m.pickKey = e.k
        startPick()
    else if e.kind = "filters" then
        openOptions("filters")
    else if e.kind = "settings" then
        openOptions("settings")
    else if e.kind = "players" then
        startPlayers()
    else if e.kind = "history" then
        showHistory()
    else if e.kind = "stats" then
        showStats()
    end if
end sub

function plural(n as Integer, one as String, many as String) as String
    if n <= 1 then return n.ToStr() + " " + one
    return n.ToStr() + " " + many
end function

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
    s = m.screen

    if m.rolling then
        if key = "back" then
            goMenu()
        end if
        return true
    end if

    if s = "menu" then
        if key = "right" or key = "options" then
            idx = m.catList.itemFocused
            if idx >= 0 and idx < m.menuMap.Count() and m.menuMap[idx].kind = "pick" then
                openList(m.menuMap[idx].k)
                return true
            end if
        end if
        return false

    else if s = "result" then
        if key = "left" then
            moveButton(-1)
        else if key = "right" then
            moveButton(1)
        else if key = "OK" then
            pressButton(m.btnIdx)
        else if key = "options" then
            toggleWatched()
        else if key = "play" then
            if m.ficheMode = "pick" then startPick()
        else if key = "back" then
            ficheBack()
        else
            return false
        end if
        return true

    else if s = "choices" then
        if key = "left" then
            setChoiceFocus(m.chIdx - 1)
        else if key = "right" then
            setChoiceFocus(m.chIdx + 1)
        else if key = "OK" then
            openChoice()
        else if key = "play" or key = "options" then
            startPick()
        else if key = "back" then
            goMenu()
        else
            return false
        end if
        return true

    else if s = "listView" then
        if key = "back" or key = "left" then
            goMenu()
        else if key = "play" then
            toggleListWatched()
        else if key = "options" then
            cycleSort()
        else
            return false
        end if
        return true

    else if s = "optView" then
        if key = "right" then
            cycleOption(m.optList.itemFocused, 1)
        else if key = "left" then
            cycleOption(m.optList.itemFocused, -1)
        else if key = "back" then
            goMenu()
        else
            return false
        end if
        return true

    else if s = "histView" or s = "statsView" then
        if key = "back" or key = "left" then
            goMenu()
            return true
        end if
        return false

    else if s = "playersView" then
        if key = "OK" or key = "play" then
            startPlayers()
        else if key = "back" then
            goMenu()
        else
            return false
        end if
        return true
    end if
    return false
end function
