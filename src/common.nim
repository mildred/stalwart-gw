import ./db/dbcommon
import ./session

type Common* = ref object
  sessions*: SessionList
  db*: DbConn
  replicate_token*: string
  replicate_to*: seq[string]

type CommonRequest* = ref object
  com*: Common
  session*: Session
  prefix*: string

func db_write_handle(com: Common): DbWriteHandle =
  result = DbWriteHandle(db: com.db, replicate_to: com.replicate_to)

func db*(com: CommonRequest): DbConn = com.com.db
func dbw*(com: CommonRequest): DbWriteHandle = com.com.db_write_handle
func sessions*(com: CommonRequest): SessionList = com.com.sessions

