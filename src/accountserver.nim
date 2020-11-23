import options
import strutils, strformat
import asyncdispatch, net
import docopt
import zfblast
import tables
import ./utils/parse_port
import ./db/dbcommon
import ./db/migrations
import ./db/users
import ./httputil
import ./admin_routes
import ./session
import ./common

const version {.strdefine.}: string = "(no version information)"

const doc = ("""
AccountServer provides HTTP server to manage accounts

Usage: accountserver [options]

Options:
  -h, --help                Print help
  --version                 Print version
  -d, --db <file>           Database file [default: accounts.db]
  -p, --port <port>         API port [default: 8000]
  -a, --addr <addr>         API bind address [default: 127.0.0.1]
  -P, --admin-port <port>   Admin interface port [default: 8080]
  -A, --admin-addr <addr>   Admin interface bind address [default: 127.0.0.1]
  -v, --verbose             Be verbose

Note: systemd socket activation is not supported yet
""") & (when not defined(version): "" else: &"""

Version: {version}
""")


let
  args = docopt(doc)
  arg_db = $args["--db"]

if args["--version"]:
  echo version
  when defined(version):
    quit(0)
  else:
    quit(1)

proc main(args: Table[string, Value]) =
  echo &"Opening database {arg_db}"
  var db: DbConn = connect(arg_db)
  defer: db.close()

  if not migrate(db):
    echo "Invalid database"
    quit(1)

  let
    sessions = newSessionList(defaultSessionTimeout)
    arg_log = args["--verbose"]
    api_server = newZFBlast(
      trace = arg_log,
      port = parse_port($args["--port"], def = 8080),
      address = $args["--addr"])
    admin_server = newZFBlast(
      trace = arg_log,
      port = parse_port($args["--admin-port"], def = 8080),
      address = $args["--admin-addr"])
    common = Common(
      sessions: sessions,
      db: db)

  proc admin_handler(ctx: HttpContext) {.async gcsafe.} =
    await admin_routes.handler(ctx, common)

  proc api_handler(ctx: HttpContext) {.async gcsafe.} =
    let params = ctx.request.body.read_file().decode_data()
    let userid = params.get_param("userid")
    let realm = params.get_param("realm")
    let req = params.get_param("req")
    if req == "lookup":
      let req_params = params.get_params("param")
      echo &"Lookup userid={userid} realm={realm} params={req_params}"
      let values = db.fetch_user_params(userid, realm, req_params)
      var res: seq[(string,string)] = @[]
      if values.is_none:
        res.add(("res", "none"))
      else:
        res.add(("res", "ok"))
        for k, v in values.get:
          res.add( (&"param.{k}", v) )
      ctx.response.httpCode = Http200
      ctx.response.body = res.encode_params
    elif req == "store":
      echo &"Store userid={userid} realm={realm}"
      ctx.response.httpCode = Http500
      ctx.response.body = {
        "res": "error",
      }.encode_params
    else:
      ctx.response.httpCode = Http400
      ctx.response.body = {
        "res": "error",
      }.encode_params
    await ctx.resp

  asyncCheck api_server.doServe(api_handler)
  asyncCheck admin_server.doServe(admin_handler)

  runForever()

main(args)

