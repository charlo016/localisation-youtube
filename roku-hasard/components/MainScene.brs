sub init()
    m.menu = m.top.findNode("menu")
    m.catList = m.top.findNode("catList")
    m.result = m.top.findNode("result")
    m.resCat = m.top.findNode("resCat")
    m.resTitle = m.top.findNode("resTitle")
    m.resHint = m.top.findNode("resHint")
    m.footer = m.top.findNode("footer")
    m.toast = m.top.findNode("toast")
    m.rollTimer = m.top.findNode("rollTimer")
    m.toastTimer = m.top.findNode("toastTimer")

    m.rolling = false
    m.lastPick = ""
    m.currentIdx = 0

    m.catList.observeField("itemSelected", "onCatSelected")
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

    applyData(ParseJson(LoadDataJson()))
    showMenu()
end sub

function getIp() as String
    ips = CreateObject("roDeviceInfo").GetIPAddrs()
    for each k in ips
        return ips[k]
    end for
    return "IP-de-la-Roku"
end function

sub applyData(d as Dynamic)
    d = SanitizeData(d)
    if d = invalid then d = DefaultData()
    m.data = d

    total = 0
    for each c in d.categories
        total = total + c.items.Count()
    end for

    content = CreateObject("roSGNode", "ContentNode")
    all = content.createChild("ContentNode")
    all.title = "Surprise ! (toutes les catégories)  -  " + total.ToStr()
    for each c in d.categories
        item = content.createChild("ContentNode")
        item.title = c.name + "  -  " + c.items.Count().ToStr()
    end for

    focus = m.catList.itemFocused
    m.catList.content = content
    if focus <> invalid and focus >= 0 and focus < content.getChildCount() then m.catList.jumpToItem = focus
end sub

sub onDataUpdated()
    applyData(ParseJson(m.server.dataJson))
    showToast("Liste mise à jour !")
end sub

sub onServerError()
    m.footer.text = m.server.error
end sub

sub showToast(text as String)
    m.toast.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.visible = false
end sub

sub showMenu()
    m.rollTimer.control = "stop"
    m.rolling = false
    m.result.visible = false
    m.menu.visible = true
    m.catList.setFocus(true)
end sub

sub showResult()
    m.menu.visible = false
    m.result.visible = true
    m.result.setFocus(true)
end sub

sub onCatSelected()
    m.currentIdx = m.catList.itemSelected
    startPick()
end sub

' Liste de { title, cat } pour la catégorie choisie (0 = toutes)
function buildPool(idx as Integer) as Object
    pool = []
    cats = m.data.categories
    for i = 0 to cats.Count() - 1
        if idx = 0 or idx - 1 = i then
            for each t in cats[i].items
                pool.Push({ title: t, cat: cats[i].name })
            end for
        end if
    end for
    return pool
end function

sub startPick()
    showResult()
    m.pool = buildPool(m.currentIdx)
    n = m.pool.Count()
    if n = 0 then
        m.resCat.text = ""
        m.resTitle.color = "0xFFFFFFFF"
        m.resTitle.text = "Rien ici pour l'instant !"
        m.resHint.text = "Ajoute des titres sur " + m.url + Chr(10) + "Retour : catégories"
        return
    end if

    ' Tirage final (évite de retomber sur le même titre deux fois de suite)
    pick = Rnd(n) - 1
    tries = 0
    while n > 1 and m.pool[pick].title = m.lastPick and tries < 20
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
        m.resTitle.text = r.title
        return
    end if
    m.rollTimer.control = "stop"
    m.rolling = false
    m.lastPick = m.final.title
    m.resCat.text = UCase(m.final.cat)
    m.resTitle.color = "0xFFFFFFFF"
    m.resTitle.text = m.final.title
    m.resHint.text = "OK : relancer     Retour : catégories"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.result.visible then
        if key = "OK" or key = "play" then
            if not m.rolling then startPick()
            return true
        else if key = "back" then
            showMenu()
            return true
        end if
    end if
    return false
end function
