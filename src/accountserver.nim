import strutils, strformat
import asyncdispatch, net
import docopt, options
import zfblast
import tables
import ./utils/parse_port
import ./db/common
import ./db/migrations
import ./httputil

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

proc process_db(): bool =
  result = true
  echo &"Opening database {arg_db}"
  var db: DbConn = connect(arg_db)
  defer: db.close()
  if not migrate(db):
    echo "Invalid database"
    result = false
    quit(1)

proc main(args: Table[string, Value]) =
  let
    arg_log  = args["--verbose"]
    api_server = newZFBlast(
      trace = arg_log,
      port = parse_port($args["--port"], def = 8080),
      address = $args["--addr"])
    admin_server = newZFBlast(
      trace = arg_log,
      port = parse_port($args["--admin-port"], def = 8080),
      address = $args["--admin-addr"])


  proc admin_handler(req: HttpContext) {.async gcsafe.} =
    echo "Not Implemented"

  proc api_handler(ctx: HttpContext) {.async gcsafe.} =
    let params = ctx.request.body.read_file().decode_data()
    let userid = params.get_param("userid")
    let realm = params.get_param("realm")
    let req = params.get_param("req")
    echo params
    if req == "lookup":
      let req_params = params.get_params("param")
      echo &"Lookup userid={userid} realm={realm} params={req_params}"
      ctx.response.httpCode = Http200
      ctx.response.body = {
        "res": "ok",
        "param.foo": "bar"
      }.encode_params
    elif req == "store":
      echo "Store"
      ctx.response.httpCode = Http500
      ctx.response.body = {
        "res": "error",
      }.encode_params
    else:
      echo "Not Acceptable"
      ctx.response.httpCode = Http400
      ctx.response.body = {
        "res": "error",
      }.encode_params
    await ctx.resp

  asyncCheck api_server.doServe(api_handler)
  asyncCheck admin_server.doServe(admin_handler)

  runForever()

if process_db():
  main(args)

