import ./db/dbcommon
import ./session

type Common* = ref object
  sessions*: SessionList
  db*: DbConn

type CommonRequest* = ref object
  com*: Common
  session*: Session
  prefix*: string

func db*(com: CommonRequest): DbConn = com.com.db
func sessions*(com: CommonRequest): SessionList = com.com.sessions

