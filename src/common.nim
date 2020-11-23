import ./db/dbcommon
import ./session

type Common* = ref object
  sessions*: SessionList
  db*: DbConn
