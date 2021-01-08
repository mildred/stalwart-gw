import asyncnet, net, options, strformat, asyncfutures, async, strutils

proc recv_line_end*(socket: AsyncSocket, flags = {SocketFlag.SafeDisconn}): Future[string] {.gcsafe async.} =
  var res = ""
  var c = ""
  while true:
    c = await recv(socket, 1, flags)
    res = res & c
    if c.len == 0 or c == "\L":
      return res

proc get_read*(client: AsyncSocket, proto: string, log: bool): proc(): Future[Option[string]] {.gcsafe.} =
  return proc(): Future[Option[string]] {.async, gcsafe.} =
    var line = await client.recvLine()
    if line == "": return none string
    stripLineEnd(line)
    result = some line
    if log: echo &"{proto} < {result.get}"

proc get_write*(client: AsyncSocket, proto: string, log: bool): proc(line: string): Future[void] {.gcsafe.} =
  return proc(line: string) {.async, gcsafe.} =
    await client.send(line)
    if log:
      var l = line
      stripLineEnd(l)
      echo &"{proto} > {l}"

proc get_starttls*(client: AsyncSocket, crypto: SslContext): proc() {.gcsafe.} =
  return proc() {.gcsafe.} =
    when defined(ssl):
      wrapConnectedSocket(crypto, client, handshakeAsServer)

