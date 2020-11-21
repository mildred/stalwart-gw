import nre, strutils, strformat
import asyncdispatch, net
import docopt, options
import zfblast
import cgi
import asynctools/asyncsync
import ./utils/parse_port
import ./db/common
import ./db/migrations
import ./httputil

const version {.strdefine.}: string = "(no version information)"

const doc = ("""
AccountServer provides HTTP server to manage accounts

Usage: newsweb [options]

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
    discard

  proc api_handler(req: HttpContext) {.async gcsafe.} =
    let params = req.request.body.decode_data()
    let userid = params["userid"]
    let realm = params["realm"]
    case params["req"]
    of "lookup":
      let req_params = params.get_all("params")
      echo &"Lookup userid={userid} realm={realm} params={req_params}"
      discard
    of "store":
      discard
    else:
      discard

  asyncCheck api_server.doServe(api_handler)
  asyncCheck admin_server.doServe(admin_handler)

  runForever()

if process_db():
  main(args)

