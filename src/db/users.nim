import db_sqlite
import strutils
import npeg
import options
import tables

type Email* = object
  local_part*: string
  domain*: string

const email = peg("email", e: Email):
  part  <- +( 1 - {'@'})
  email <- >part * "@" * >part:
    e.local_part = $1
    e.domain = $2

proc parse_email*(e: string): Option[Email] {.gcsafe.} =
  var res: Email
  if email.match(e, res).ok:
    result = some res
  else:
    result = none Email

proc num_users*(db: DbConn): int =
  result = parseInt(db.get_value(sql"SELECT COUNT(*) FROM users;"))

proc create_user*(db: DbConn, local_part, domain, password: string) =
  let user_id = db.insertId(sql"""
    INSERT INTO users(local_part, domain, super_admin, domain_admin)
    SELECT ?, ?,
      CASE (SELECT COUNT(*) FROM users)
        WHEN 0 THEN TRUE ELSE FALSE END,
      CASE (SELECT COUNT(*) FROM users WHERE local_part = ?)
        WHEN 0 THEN TRUE ELSE FALSE END
  """, local_part, domain, local_part)

  db.exec(sql"""
    INSERT INTO user_params(user_id, name, value)
    VALUES(?, 'userPassword', ?)
  """, user_id, password)

proc fetch_user_params*(db: DbConn, local_part, domain: string, params: seq[string]): Option[Table[string,string]] {.gcsafe.} =
  let q = """
    SELECT user_params.name, user_params.value
    FROM users LEFT OUTER JOIN user_params ON users.id = user_params.user_id
    WHERE users.local_part = ? AND users.domain = ?
  """
  var t: Table[string,string] = initTable[string,string]()
  result = none Table[string,string]
  for row in db.rows(sql(q), local_part, domain):
    if row[0] != "" and params.contains(row[0]):
      t[row[0]] = row[1]
    result = some t

