import strformat
import db_sqlite
import strutils
import npeg
import options
import tables

type Email* = object
  local_part*: string
  domain*: string

type User* = object
  email*: Email
  super_admin*: bool
  domain_admin*: bool

proc `$`*(email: Email): string =
  &"{email.local_part}@{email.domain}"

proc to_sql_bool(b: bool): int =
  if b: 1 else: 0

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

proc create_user*(db: DbConn, local_part, domain, password: string, super_admin: bool = false, domain_admin: bool = false, auto_admin: bool = true) =
  let user_id = db.insertId(sql"""
    INSERT INTO users(local_part, domain, super_admin, domain_admin)
    SELECT ?, ?,
      ? OR (? AND CASE (SELECT COUNT(*) FROM users)
        WHEN 0 THEN TRUE ELSE FALSE END),
      ? OR (? AND CASE (SELECT COUNT(*) FROM users WHERE local_part = ?)
        WHEN 0 THEN TRUE ELSE FALSE END)
  """, local_part, domain, super_admin.to_sql_bool, auto_admin.to_sql_bool, domain_admin.to_sql_bool, auto_admin.to_sql_bool, local_part)

  db.exec(sql"""
    INSERT INTO user_params(user_id, name, value)
    VALUES(?, 'userPassword', ?)
  """, user_id, password)

proc fetch_domains*(db: DbConn): seq[string] {.gcsafe.} =
  let q = """
    SELECT DISTINCT users.domain
    FROM users
  """
  result = @[]
  for row in db.rows(sql(q)):
    result.add(row[0])

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

proc check_user_password*(db: DbConn, email: Email, password: string): bool {.gcsafe.} =
  let db_password = db.get_value(sql"""
    SELECT user_params.value
    FROM users JOIN user_params ON users.id = user_params.user_id
    WHERE users.local_part = ? AND users.domain = ? AND user_params.name = 'userPassword'
  """, email.local_part, email.domain)

  return (password == db_password)

proc update_user_password*(db: DbConn, email: Email, password: string) {.gcsafe.} =
  db.exec(sql"""
    UPDATE  user_params
    SET     value = ?
    WHERE   name = 'userPassword' AND
            user_id IN (
              SELECT id FROM USERS
              WHERE local_part = ? AND domain = ?)
  """, password, email.local_part, email.domain)

proc is_admin*(db: DbConn, email: Email, domain: string = ""): bool {.gcsafe.} =
  if domain == "" or email.domain != domain:
    let res = parseInt(db.get_value(sql"""
      SELECT CASE users.super_admin WHEN TRUE THEN 1 ELSE 0 END
      FROM users
      WHERE users.local_part = ? AND users.domain = ?
    """, email.local_part, email.domain))
    return res == 1
  else:
    let res = parseInt(db.get_value(sql"""
      SELECT CASE WHEN (users.super_admin OR users.domain_admin) THEN 1 ELSE 0 END
      FROM users
      WHERE users.local_part = ? AND users.domain = ?
    """, email.local_part, email.domain))
    return res == 1

proc is_admin*(db: DbConn, email: Email, target_user: Email): bool {.gcsafe.} =
  if email.local_part == target_user.local_part and email.domain == target_user.domain:
    return true
  return is_admin(db, email, target_user.domain)

proc fetch_admin_domains*(db: DbConn, email: Email): seq[string] {.gcsafe.} =
  let q = sql"""
    SELECT  DISTINCT users.domain
    FROM    users, users AS current_user
    WHERE   current_user.local_part = ? AND current_user.domain = ? AND
            CASE
              WHEN current_user.super_admin THEN TRUE
              WHEN current_user.domain_admin THEN users.id = current_user.id
              ELSE FALSE
            END
  """
  result = @[]
  for row in db.rows(q, email.local_part, email.domain):
    result.add(row[0])

proc fetch_users*(db: DbConn, domain: string = ""): seq[User] {.gcsafe.} =
  if domain == "":
    let q = sql"""
      SELECT  users.local_part, users.domain, users.super_admin, users.domain_admin
      FROM    users
    """
    result = @[]
    for row in db.rows(q, domain):
      result.add(User(email: Email(local_part: row[0], domain: row[1]),
                      super_admin: row[2] == "1",
                      domain_admin: row[3] == "1"))
  else:
    let q = sql"""
      SELECT  users.local_part, users.domain, users.super_admin, users.domain_admin
      FROM    users
    """
    result = @[]
    for row in db.rows(q):
      result.add(User(email: Email(local_part: row[0], domain: row[1]),
                      super_admin: row[2] == "1",
                      domain_admin: row[3] == "1"))

