import strutils
import strformat
import db_sqlite
import times
import tables

proc connect*(dbfile: string): DbConn =
  result = db_sqlite.open(dbfile, "", "", "")

export DbConn
export close

