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
  catchall*: bool
  num_aliases*: int

type Mailbox* = object
  discard

type Alias* = object
  alias*: string

type
  ExtractUser* = object
    local_part*: string
    domain*: string
    super_admin*: bool
    domain_admin*: bool
    created_at*: string

  ExtractAlias* = object
    src_local_part*: string
    src_domain*: string
    alias_local_part*: string
    alias_domain*: string

  ExtractCatchall* = object
    domain*: string
    catchall_local_part*: string
    catchall_domain*: string

  ExtractParam* = object
    local_part*: string
    domain*: string
    param*: string
    value*: string

  Extract* = object
    users*: seq[ExtractUser]
    params*: seq[ExtractParam]
    aliases*: seq[ExtractAlias]
    catchall*: seq[ExtractCatchall]

type
  DbCreateUserOp* = object
    local_part*: string
    domain*: string
    password*: string
    super_admin*: bool
    domain_admin*: bool
    auto_admin*: bool

  DbAddAliasOp* = object
    user*: Email
    alias*: Email

  DbUpdateUserPasswordOp* = object
    email*: Email
    password*: string

  DbInsertAllDataOp* = object
    extract*: Extract

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

proc create_user(db: DbConn, local_part, domain, password: string, super_admin: bool = false, domain_admin: bool = false, auto_admin: bool = true) =
  let user_id = db.insertId(sql"""
    INSERT INTO users(local_part, domain, super_admin, domain_admin)
    SELECT ?, ?,
      ? OR (? AND CASE (SELECT COUNT(*) FROM users)
        WHEN 0 THEN TRUE ELSE FALSE END),
      ? OR (? AND CASE (SELECT COUNT(*) FROM users WHERE local_part = ?)
        WHEN 0 THEN TRUE ELSE FALSE END)
  """, local_part, domain, super_admin.to_sql_bool, auto_admin.to_sql_bool, domain_admin.to_sql_bool, auto_admin.to_sql_bool, local_part)

  if password != "":
    db.exec(sql"""
      INSERT INTO user_params(user_id, name, value)
      VALUES(?, 'userPassword', ?)
    """, user_id, password)

proc run*(db: DbConn, op: DbCreateUserOp) =
  create_user(db, op.local_part, op.domain, op.password, op.super_admin, op.domain_admin, op.auto_admin)

proc add_alias(db: DbConn, user: Email, alias: Email) =
  db.exec(sql"""
    INSERT  INTO aliases(user_id, alias_user_id)
    SELECT  users.id, alias_users.id
    FROM    users, users AS alias_users
    WHERE   users.local_part = ? AND users.domain = ? AND
            alias_users.local_part = ? AND alias_users.domain = ?
  """, user.local_part, user.domain, alias.local_part, alias.domain)

proc run*(db: DbConn, op: DbAddAliasOp) =
  add_alias(db, op.user, op.alias)

proc get_alias*(db: DbConn, user: Email): seq[Email] {.gcsafe.} =
  let q = """
    SELECT  alias_users.local_part, alias_users.domain
    FROM    users
            JOIN aliases ON aliases.user_id = users.id
            JOIN users AS alias_users ON aliases.alias_user_id = alias_users.id
    WHERE   users.local_part = ? AND users.domain = ?
  """
  result = @[]
  for row in db.rows(sql(q), user.local_part, user.domain):
    result.add(Email(local_part: row[0], domain: row[1]))

proc get_alias_or_catchall*(db: DbConn, user: Email): seq[Email] {.gcsafe.} =
  result = get_alias(db, user)
  if result.len == 0:
    let q = """
      SELECT  users.local_part, users.domain
      FROM    users JOIN catchall ON catchall.user_id = users.id
      WHERE   catchall.domain = ?
    """
    result = @[]
    for row in db.rows(sql(q), user.domain):
      result.add(Email(local_part: row[0], domain: row[1]))

proc fetch_credentials*(db: DbConn): Table[string,string] {.gcsafe.} =
  let q = """
    SELECT users.local_part || '@' || users.domain, user_params.value
    FROM users JOIN user_params ON users.id = user_params.user_id
    WHERE user_params.name = 'userPassword'
  """
  result = initTable[string,string]()
  for row in db.rows(sql(q)):
    result[row[0]] = row[1]

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

  return (db_password != "" and password == db_password)

proc update_user_password(db: DbConn, email: Email, password: string) {.gcsafe.} =
  if password == "":
    db.exec(sql"""
      DELETE  FROM user_params
      WHERE   name = 'userPassword' AND
              user_id IN (
                SELECT id FROM USERS
                WHERE local_part = ? AND domain = ?)
    """, email.local_part, email.domain)
  else:
    db.exec(sql"""
      UPDATE  user_params
      SET     value = ?
      WHERE   name = 'userPassword' AND
              user_id IN (
                SELECT id FROM USERS
                WHERE local_part = ? AND domain = ?)
    """, password, email.local_part, email.domain)

proc run*(db: DbConn, op: DbUpdateUserPasswordOp) {.gcsafe.} =
  update_user_password(db, op.email, op.password)

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
  if domain != "":
    let q = sql"""
      SELECT  users.local_part, users.domain, users.super_admin, users.domain_admin,
              catchall.user_id IS NOT NULL,
              COUNT(aliases.id)
      FROM    users
              LEFT OUTER JOIN catchall ON
                catchall.user_id == users.id AND catchall.domain == users.domain
              LEFT OUTER JOIN aliases ON
                aliases.user_id = users.id
      WHERE   users.domain = ?
      GROUP   BY users.local_part, users.domain, users.super_admin, users.domain_admin, catchall.user_id
    """
    result = @[]
    for row in db.rows(q, domain):
      result.add(User(email: Email(local_part: row[0], domain: row[1]),
                      super_admin: row[2] == "1",
                      domain_admin: row[3] == "1",
                      catchall: row[4] == "1",
                      num_aliases: row[5].parse_int()))
  else:
    let q = sql"""
      SELECT  users.local_part, users.domain, users.super_admin, users.domain_admin,
              catchall.user_id IS NOT NULL,
              COUNT(aliases.id)
      FROM    users
              LEFT OUTER JOIN catchall ON
                catchall.user_id == users.id AND catchall.domain == users.domain
              LEFT OUTER JOIN aliases ON
                aliases.user_id = users.id
      GROUP   BY users.local_part, users.domain, users.super_admin, users.domain_admin, catchall.user_id
    """
    result = @[]
    for row in db.rows(q):
      result.add(User(email: Email(local_part: row[0], domain: row[1]),
                      super_admin: row[2] == "1",
                      domain_admin: row[3] == "1",
                      catchall: row[4] == "1",
                      num_aliases: row[5].parse_int()))

proc fetch_user_aliases*(db: DbConn, user: Email): seq[Email] {.gcsafe.} =
  let q = sql"""
    SELECT  alias_users.local_part, alias_users.domain
    FROM    users
            JOIN aliases ON
              aliases.user_id = users.id
            JOIN users AS alias_users ON
              aliases.alias_user_id = alias_users.id
    WHERE   users.local_part = ? AND users.domain = ?
  """
  result = @[]
  for row in db.rows(q, user.local_part, user.domain):
    result.add(Email(local_part: row[0], domain: row[1]))

proc extract_all*(db: DbConn): Extract {.gcsafe.} =
  result = Extract(
    users: @[],
    params: @[],
    aliases: @[],
    catchall: @[])

  for row in db.rows(sql"""
    SELECT  users.domain, users.local_part,
            users.domain_admin, users.super_admin,
            users.created_at
    FROM    users
  """):
    result.users.add(ExtractUser(domain: row[0], local_part: row[1], domain_admin: row[2] == "1", super_admin: row[3] == "1", created_at: row[4]))

  for row in db.rows(sql"""
    SELECT  users.domain, users.local_part, user_params.name, user_params.value
    FROM    user_params JOIN users ON user_params.user_id = users.id
  """):
    result.params.add(ExtractParam(domain: row[0], local_part: row[1], param: row[2], value: row[3]))

  for row in db.rows(sql"""
    SELECT  src.domain, src.local_part, alias.domain, alias.local_part
    FROM    aliases
            JOIN users AS src ON aliases.user_id = src.id
            JOIN users AS alias ON aliases.alias_user_id = alias.id
  """):
    result.aliases.add(ExtractAlias(src_domain: row[0], src_local_part: row[1], alias_domain: row[2], alias_local_part: row[3]))

  for row in db.rows(sql"""
    SELECT  catchall.domain, users.domain, users.local_part
    FROM    catchall
            JOIN users ON catchall.user_id = users.id
  """):
    result.catchall.add(ExtractCatchall(domain: row[0], catchall_domain: row[1], catchall_local_part: row[2]))

proc insert_all_data(db: DbConn, extract: Extract) {.gcsafe.} =
  var q: string

  db.exec(sql"BEGIN")
  db.exec(sql"DELETE FROM users;")
  db.exec(sql"DELETE FROM user_params;")
  db.exec(sql"DELETE FROM catchall;")
  db.exec(sql"DELETE FROM aliases;")

  for user in extract.users:
    q = """
      INSERT INTO users (domain, local_part, domain_admin, super_admin, created_at)
      VALUES (?, ?, ?, ?, ?)
    """
    discard db.insertId(sql(q), user.domain, user.local_part, if user.domain_admin: "1" else: "0", if user.super_admin: "1" else: "0", user.created_at)

  for param in extract.params:
    q = """
      INSERT INTO user_params (user_id, name, value)
      SELECT users.id, ?, ?
      FROM   users
      WHERE  users.domain = ? AND users.local_part = ?
    """
    discard db.insertId(sql(q), param.param, param.value, param.domain, param.local_part)

  for alias in extract.aliases:
    q = """
      INSERT INTO aliases (user_id, alias_user_id)
      SELECT user.id, alias_user.id
      FROM   users AS user, users AS alias_user
      WHERE  user.domain = ? AND user.local_part = ? AND alias_user.domain = ? AND alias_user.local_part = ?
    """
    discard db.insertId(sql(q), alias.src_domain, alias.src_local_part, alias.alias_domain, alias.alias_local_part)

  for catchall in extract.catchall:
    q = """
      INSERT INTO catchall (domain, user_id)
      SELECT ?, users.id
      FROM   users
      WHERE  users.domain = ? AND users.local_part = ?
    """
    discard db.insertId(sql(q), catchall.domain, catchall.catchall_domain, catchall.catchall_local_part)

  db.exec(sql"COMMIT")

proc run*(db: DbConn, op: DbInsertAllDataOp) {.gcsafe.} =
  insert_all_data(db, op.extract)
