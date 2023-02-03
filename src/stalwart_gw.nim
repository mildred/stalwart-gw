import options
import strutils, strformat
import httpclient
import asyncdispatch, net
import docopt
import asynchttpserver
import zfblast/server
import tables
import nativesockets
import json
import base64
import ./utils/parse_port
import ./utils/lineproto
import ./jmap
import ./httputil

const version {.strdefine.}: string = "(no version information)"

const doc = ("""
Stalwart Gateway provides socket API for Stalwart accounts

Usage: stalwart_gw [options]

Options:
  -h, --help                Print help
  -v, --verbose             Be verbose
  --version                 Print version
  --jmap-url <port>         JMAP URL to use
  --basic-auth-file <file>  File containing USERNAME:PASSWORD without a newline
  --sockapi-port <port>     Socket API port [default: 7999]
  --sockapi-addr <addr>     Socket API bind address [default: 127.0.0.1]
  --insecure-logs           Log with user param values (passwords included)

Note: systemd socket activation is not supported yet
""") & (when not defined(version): "" else: &"""

Version: {version}
""")

const CRLF = "\c\L"

let
  args = docopt(doc)

if args["--version"]:
  echo version
  when defined(version):
    quit(0)
  else:
    quit(1)

proc main(args: Table[string, Value]) =
  echo &"Starting up stalwart_gw version {version}..."

  let
    arg_log = args["--verbose"]
    arg_ilog = args["--insecure-logs"]
    arg_jmap_url = $args["--jmap-url"]
    arg_basic_auth_file = $args["--basic-auth-file"]
    sockapi_port = parse_port($args["--sockapi-port"], 7999)
    sockapi_addr = $args["--sockapi-addr"]

  var sockapi: AsyncSocket
  sockapi = newAsyncSocket()
  sockapi.setSockOpt(OptReuseAddr, true)
  sockapi.bindAddr(sockapi_port, sockapi_addr)
  sockapi.listen()

  let credentials = base64.encode(readFile(arg_basic_auth_file))
  let client = jmap.newClient(arg_jmap_url, credentials)

  echo &"Listening Socket API on {sockapi_addr} port {sockapi_port}"

  proc get_param64(params: Table[string, seq[string]], key: string, def: string = ""): string =
    var val = params.get_params(key)
    if val.len > 0:
      return val[0]

    val = params.get_params(&"{key}64")
    if val.len > 0:
      return base64.decode(val[0].replace(" ", "+"))

    return def

  proc decode_data_raw(data: string): Table[string, seq[string]] {.gcsafe.} =
    iterator decodeDataRaw(data: string): tuple[key, value: string] =
      proc handleHexChar(c: char, x: var int, f: var bool) {.inline.} =
        case c
        of '0'..'9': x = (x shl 4) or (ord(c) - ord('0'))
        of 'a'..'f': x = (x shl 4) or (ord(c) - ord('a') + 10)
        of 'A'..'F': x = (x shl 4) or (ord(c) - ord('A') + 10)
        else: f = true
      proc decodePercent(s: string, i: var int): char =
        ## Converts `%xx` hexadecimal to the charracter with ordinal number `xx`.
        ##
        ## If `xx` is not a valid hexadecimal value, it is left intact: only the
        ## leading `%` is returned as-is, and `xx` characters will be processed in the
        ## next step (e.g. in `uri.decodeUrl`) as regular characters.
        result = '%'
        if i+2 < s.len:
          var x = 0
          var failed = false
          handleHexChar(s[i+1], x, failed)
          handleHexChar(s[i+2], x, failed)
          if not failed:
            result = chr(x)
            inc(i, 2)
      ## Reads and decodes CGI data and yields the (name, value) pairs the
      ## data consists of.
      proc parseData(data: string, i: int, field: var string, sep: char): int =
        result = i
        while result < data.len:
          let c = data[result]
          case c
          of '%': add(field, decodePercent(data, result))
          of '+': add(field, ' ')
          of '&': break
          else:
            if c == sep: break
            add(field, data[result])
          inc(result)

      var i = 0
      var name = ""
      var value = ""
      # decode everything in one pass:
      while i < data.len:
        setLen(name, 0) # reuse memory
        i = parseData(data, i, name, '=')
        setLen(value, 0) # reuse memory
        if i < data.len and data[i] == '=':
          inc(i) # skip '='
          i = parseData(data, i, value, '&')
        yield (name, value)
        if i < data.len:
          inc(i)

    result = initTable[string,seq[string]]()
    for key, value in decodeDataRaw(data):
      result.mget_or_put(key, @[]).add(value)

  proc handle_api_request(request: string): Future[tuple[body: string, httpCode: HttpCode]] {.async, gcsafe.} =
    let params = request.decode_data_raw()
    let req = params.get_param("req")
    if req == "lookup":
      let userid = params.get_param("userid")
      let realm = params.get_param("realm")
      let raw_req_params = params.get_params("param")
      echo &"API: Lookup userid={userid} realm={realm} params={raw_req_params}"
      var res: seq[(string,string)] = @[]
      let exists = await client.user_exists(userid, realm)
      if exists:
        res.add(("res", "none"))
        if arg_log and not arg_ilog: echo &"Respond with: res=none"
      else:
        res.add(("res", "ok"))
        if arg_log and not arg_ilog: echo &"Respond with: res=ok"
      result.httpCode = Http200
      result.body = res.encode_params
      if arg_ilog: echo &"API: Respond with: {result.body}"
    elif req == "store":
      let userid = params.get_param("userid")
      let realm = params.get_param("realm")
      echo &"API: Store userid={userid} realm={realm}"
      echo &"API: Respond error"
      result.httpCode = Http500
      result.body = {
        "res": "error",
      }.encode_params
    elif req == "checkdomain":
      result.httpCode = Http200
      let trueStr = params.get_param("true", "true")
      let falseStr = params.get_param("false", "false")
      let domain = params.get_param64("domain")
      if await client.has_domain(domain):
        echo &"API: Check domain {domain}: {trueStr}"
        result.body = trueStr
      else:
        echo &"API: Check domain {domain}: {falseStr}"
        result.body = falseStr
    elif req == "checkauth":
      result.httpCode = Http200
      let trueStr = params.get_param("true", "true")
      let falseStr = params.get_param("false", "false")
      let user = params.get_param64("user")
      let pass = params.get_param64("pass")
      if arg_ilog: echo &"API: Check auth user=\"{user}\" pass=\"{pass}\""
      if await client.check_user_password(user, pass):
        echo &"API: Check auth user={user}: {trueStr}"
        result.body = trueStr
      else:
        echo &"API: Check auth user={user}: {falseStr}"
        result.body = falseStr
    elif req == "getalias":
      result.httpCode = Http200
      let failureStr = params.get_param("failure", "")
      let domain = params.get_param64("domain")
      let localpart = params.get_param64("localpart")
      let alias = await client.get_alias_or_catchall(localpart, domain)
      if alias.len == 0:
        echo &"API: Get alias {localpart}@{domain}: failed \"{failureStr}\""
        result.body = failureStr
      else:
        for a in alias:
          if result.body.len > 0: result.body.add(",")
          result.body.add($a)
        echo &"API: Get alias {localpart}@{domain}: success \"{result.body}\""
    else:
      echo &"API: Unknown request {req}"
      result.httpCode = Http400
      result.body = {
        "res": "error",
      }.encode_params

  proc sockapi_handle_client(client: AsyncSocket) {.async gcsafe.} =
    defer:
      client.close()
    while true:
      let rawline = await client.recv_line_end()
      if rawline == "":
        return
      var line = rawline
      stripLineEnd(line)
      let res = await handle_api_request(line)
      if line == rawline:
        await client.send(res.body)
        return
      else:
        await client.send(res.body & CRLF)

  proc sockapi_handle(sockapi: AsyncSocket) {.async gcsafe.} =
    while true:
      let client = await sockapi.accept()
      try:
        asyncCheck sockapi_handle_client(client)
      except:
        echo "----------"
        let e = getCurrentException()
        echo &"{e.name}: {e.msg}"
        #echo getStackTrace(e)
        echo "----------"

  asyncCheck sockapi_handle(sockapi)

  runForever()

main(args)

