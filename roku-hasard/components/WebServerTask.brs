' Mini serveur HTTP qui tourne dans l'app Roku.
' GET  /           -> page d'édition (web/index.html)
' GET  /api/data   -> liste actuelle en JSON
' POST /api/data   -> remplace la liste

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

    m.html = ReadAsciiFile("pkg:/web/index.html")
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
                sendResponse(c.sock, "431 Request Header Fields Too Large", "text/plain; charset=utf-8", "En-têtes trop grands")
                return true
            end if
            return false
        end if
        c.headerEnd = he
        lines = bytesToStr(c.buf, 0, he).Split(Chr(10))
        first = lines[0].Trim().Split(" ")
        c.method = UCase(first[0])
        if first.Count() > 1 then c.path = first[1] else c.path = "/"
        q = Instr(1, c.path, "?")
        if q > 0 then c.path = Left(c.path, q - 1)
        for each l in lines
            idx = Instr(1, l, ":")
            if idx > 0 and LCase(Left(l, idx - 1).Trim()) = "content-length" then
                c.clen = Mid(l, idx + 1).Trim().ToInt()
            end if
        end for
        if c.clen > 65536 then
            sendResponse(c.sock, "413 Payload Too Large", "application/json", "{" + Chr(34) + "error" + Chr(34) + ":" + Chr(34) + "Trop gros" + Chr(34) + "}")
            return true
        end if
    end if

    bodyStart = c.headerEnd + 4
    if c.buf.Count() - bodyStart < c.clen then return false

    handleRequest(c.sock, c.method, c.path, bytesToStr(c.buf, bodyStart, c.clen))
    return true
end function

sub handleRequest(sock as Object, method as String, path as String, body as String)
    if method = "GET" and (path = "/" or path = "/index.html") then
        sendResponse(sock, "200 OK", "text/html; charset=utf-8", m.html)
    else if path = "/api/data" and method = "GET" then
        sendResponse(sock, "200 OK", "application/json; charset=utf-8", LoadDataJson())
    else if path = "/api/data" and method = "POST" then
        d = SanitizeData(ParseJson(body))
        if d = invalid then
            sendResponse(sock, "400 Bad Request", "application/json; charset=utf-8", FormatJson({ error: "Format invalide" }))
            return
        end if
        json = FormatJson(d)
        err = SaveDataJson(json)
        if err <> "" then
            sendResponse(sock, "400 Bad Request", "application/json; charset=utf-8", FormatJson({ error: err }))
            return
        end if
        m.top.dataJson = json ' prévient l'écran
        sendResponse(sock, "200 OK", "application/json; charset=utf-8", json)
    else
        sendResponse(sock, "404 Not Found", "text/plain; charset=utf-8", "Introuvable")
    end if
end sub

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

sub sendResponse(sock as Object, status as String, ctype as String, body as String)
    crlf = Chr(13) + Chr(10)
    bodyBytes = CreateObject("roByteArray")
    bodyBytes.FromAsciiString(body)
    head = "HTTP/1.1 " + status + crlf
    head = head + "Content-Type: " + ctype + crlf
    head = head + "Content-Length: " + bodyBytes.Count().ToStr() + crlf
    head = head + "Cache-Control: no-store" + crlf
    head = head + "Connection: close" + crlf + crlf
    all = CreateObject("roByteArray")
    all.FromAsciiString(head)
    for each b in bodyBytes
        all.Push(b)
    end for

    total = all.Count()
    offset = 0
    retries = 0
    while offset < total and retries < 400
        sent = sock.send(all, offset, total - offset)
        if sent > 0 then
            offset = offset + sent
            retries = 0
        else
            retries = retries + 1
            sleep(5)
        end if
    end while
end sub
