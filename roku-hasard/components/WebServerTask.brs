' Mini serveur HTTP qui tourne dans l'app Roku.
' GET  /               -> page d'édition (web/index.html)
' GET  /api/state      -> { data, settings, history, info }
' POST /api/data       -> remplace la liste
' POST /api/settings   -> remplace les réglages
' POST /api/cmd        -> commande pour la télé : {action:"pick", k} | {action:"show", c, i}
'                         | {action:"clearHistory"} | {action:"addHistory", t, c} | {action:"players"}

sub init()
    m.top.functionName = "runServer"
end sub

sub runServer()
    port = CreateObject("roMessagePort")
    addr = CreateObject("roSocketAddress")
    addr.setPort(m.top.port)

    server = CreateObject("roStreamSocket")
    server.setMessagePort(port)
    server.setAddress(addr)
    server.notifyReadable(true)
    server.listen(8)
    if not server.eOK() then
        m.top.error = "Impossible d'ouvrir le port " + m.top.port.ToStr()
        return
    end if

    m.html = CreateObject("roByteArray")
    m.html.ReadFile("pkg:/web/index.html")
    conns = {}

    while true
        msg = wait(0, port)
        if type(msg) = "roSocketEvent" then
            sid = msg.getSocketID()
            if sid = server.getID() then
                if server.isReadable() then
                    sock = server.accept()
                    if sock <> invalid then
                        sock.setMessagePort(port)
                        sock.notifyReadable(true)
                        conns[sock.getID().ToStr()] = { sock: sock, buf: CreateObject("roByteArray"), headerEnd: -1, clen: 0, method: "", path: "" }
                    end if
                end if
            else
                key = sid.ToStr()
                c = conns[key]
                if c <> invalid and c.sock.isReadable() then
                    n = c.sock.getCountRcvBuf()
                    done = false
                    if n <= 0 then
                        done = true ' le client a fermé la connexion
                    else
                        tmp = CreateObject("roByteArray")
                        tmp[n - 1] = 0
                        got = c.sock.receive(tmp, 0, n)
                        for i = 0 to got - 1
                            c.buf.Push(tmp[i])
                        end for
                        done = processConn(c)
                    end if
                    if done then
                        c.sock.close()
                        conns.Delete(key)
                    end if
                end if
            end if
        end if
    end while
end sub

' Retourne true quand la requête est complète et qu'une réponse a été envoyée.
function processConn(c as Object) as Boolean
    if c.headerEnd < 0 then
        he = findHeaderEnd(c.buf)
        if he < 0 then
            if c.buf.Count() > 16384 then
                sendText(c.sock, "431 Request Header Fields Too Large", "text/plain; charset=utf-8", "En-têtes trop grands")
                return true
            end if
            return false
        end if
        c.headerEnd = he
        lines = bytesToStr(c.buf, 0, he).Split(Chr(10))
        first = lines[0].Trim().Split(" ")
        c.method = UCase(first[0])
        if first.Count() > 1 then c.path = first[1] else c.path = "/"
        c.query = ""
        q = Instr(1, c.path, "?")
        if q > 0 then
            c.query = Mid(c.path, q + 1)
            c.path = Left(c.path, q - 1)
        end if
        for each l in lines
            idx = Instr(1, l, ":")
            if idx > 0 and LCase(Left(l, idx - 1).Trim()) = "content-length" then
                c.clen = Mid(l, idx + 1).Trim().ToInt()
            end if
        end for
        if c.clen > 65536 then
            sendJson(c.sock, "413 Payload Too Large", { error: "Trop gros" })
            return true
        end if
    end if

    bodyStart = c.headerEnd + 4
    if c.buf.Count() - bodyStart < c.clen then return false

    handleRequest(c.sock, c.method, c.path, c.query, bytesToStr(c.buf, bodyStart, c.clen))
    return true
end function

sub handleRequest(sock as Object, method as String, path as String, query as String, body as String)
    if method = "GET" and (path = "/" or path = "/index.html") then
        sendBytes(sock, "200 OK", "text/html; charset=utf-8", m.html)

    else if method = "GET" and path = "/api/state" then
        state = {
            data: LoadData()
            settings: LoadSettings()
            history: LoadHistory()
            info: { version: AppVersion(), max: MaxDataBytes(), url: m.top.url }
        }
        sendJson(sock, "200 OK", state)

    else if method = "GET" and path = "/api/fetch" then
        ' Relais pour les sites qui refusent les appels directs depuis une page web
        ' (IMDb) ou qui limitent fortement (iTunes). Seuls ces sites sont autorisés.
        url = ""
        for each part in query.Split("&")
            if Left(part, 2) = "u=" then url = CreateObject("roUrlTransfer").Unescape(Mid(part, 3))
        end for
        allowed = false
        for each prefix in ["https://v3.sg.media-imdb.com/", "https://itunes.apple.com/"]
            if Left(url, Len(prefix)) = prefix then allowed = true
        end for
        if not allowed then
            sendJson(sock, "403 Forbidden", { error: "Site non autorisé" })
            return
        end if
        res = proxyGet(url)
        if res.code = 200 then
            sendText(sock, "200 OK", "application/json; charset=utf-8", res.body)
        else
            sendJson(sock, "502 Bad Gateway", { error: "Erreur " + res.code.ToStr() })
        end if

    else if method = "GET" and path = "/api/data" then
        sendJson(sock, "200 OK", LoadData())

    else if method = "POST" and path = "/api/data" then
        d = SanitizeData(ParseJson(body))
        if d = invalid then
            sendJson(sock, "400 Bad Request", { error: "Format invalide" })
            return
        end if
        json = FormatJson(d)
        err = SaveDataJson(json)
        if err <> "" then
            sendJson(sock, "400 Bad Request", { error: err })
            return
        end if
        m.top.dataJson = json ' prévient l'écran
        sendJson(sock, "200 OK", d)

    else if method = "POST" and path = "/api/settings" then
        ' Mise à jour partielle : on part des réglages actuels
        s = LoadSettings()
        incoming = ParseJson(body)
        if type(incoming) = "roAssociativeArray" then
            for each k in incoming
                s[k] = incoming[k]
            end for
        end if
        s = SanitizeSettings(s)
        SaveSettings(s)
        m.top.settingsJson = FormatJson(s)
        sendJson(sock, "200 OK", s)

    else if method = "POST" and path = "/api/cmd" then
        cmd = ParseJson(body)
        if type(cmd) <> "roAssociativeArray" or not IsStr(cmd.action) then
            sendJson(sock, "400 Bad Request", { error: "Commande invalide" })
            return
        end if
        m.top.command = cmd
        sendJson(sock, "200 OK", { ok: true })

    else
        sendText(sock, "404 Not Found", "text/plain; charset=utf-8", "Introuvable")
    end if
end sub

function proxyGet(url as String) as Object
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.EnableEncodings(true)
    ut.RetainBodyOnError(true)
    port = CreateObject("roMessagePort")
    ut.SetMessagePort(port)
    if not ut.AsyncGetToString() then return { code: 0, body: "" }
    msg = wait(10000, port)
    if type(msg) <> "roUrlEvent" then
        ut.AsyncCancel()
        return { code: 0, body: "" }
    end if
    return { code: msg.GetResponseCode(), body: msg.GetString() }
end function

function findHeaderEnd(ba as Object) as Integer
    n = ba.Count()
    for i = 0 to n - 4
        if ba[i] = 13 and ba[i + 1] = 10 and ba[i + 2] = 13 and ba[i + 3] = 10 then return i
    end for
    return -1
end function

function bytesToStr(ba as Object, start as Integer, length as Integer) as String
    if length <= 0 then return ""
    out = CreateObject("roByteArray")
    for i = start to start + length - 1
        out.Push(ba[i])
    end for
    return out.ToAsciiString()
end function

sub sendJson(sock as Object, status as String, obj as Object)
    sendText(sock, status, "application/json; charset=utf-8", FormatJson(obj))
end sub

sub sendText(sock as Object, status as String, ctype as String, body as String)
    bodyBytes = CreateObject("roByteArray")
    bodyBytes.FromAsciiString(body)
    sendBytes(sock, status, ctype, bodyBytes)
end sub

sub sendBytes(sock as Object, status as String, ctype as String, bodyBytes as Object)
    crlf = Chr(13) + Chr(10)
    head = "HTTP/1.1 " + status + crlf
    head = head + "Content-Type: " + ctype + crlf
    head = head + "Content-Length: " + bodyBytes.Count().ToStr() + crlf
    head = head + "Cache-Control: no-store" + crlf
    head = head + "Connection: close" + crlf + crlf
    headBytes = CreateObject("roByteArray")
    headBytes.FromAsciiString(head)
    sendAll(sock, headBytes)
    sendAll(sock, bodyBytes)
end sub

sub sendAll(sock as Object, ba as Object)
    total = ba.Count()
    offset = 0
    retries = 0
    while offset < total and retries < 600
        chunk = total - offset
        if chunk > 16384 then chunk = 16384
        sent = sock.send(ba, offset, chunk)
        if sent > 0 then
            offset = offset + sent
            retries = 0
        else
            retries = retries + 1
            sleep(5)
        end if
    end while
end sub
