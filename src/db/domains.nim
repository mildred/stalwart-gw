import strformat
import db_sqlite
import strutils
import npeg
import tables

import ./users

type Domain* = object
  mailboxes*: Table[string,Mailbox]
  aliases*: Table[string,Alias]
  catchall*: string

proc has_domain*(db: DbConn, domain: string): bool {.gcsafe.} =
  let q = sql"""
    SELECT  COUNT(*)
    FROM    users
    WHERE   users.domain = ?
  """
  return db.get_value(q, domain).parse_int() > 0

proc fetch_domains*(db: DbConn): Table[string,Domain] {.gcsafe.} =
  let q = """
    SELECT  users.domain,
            users.local_part,
            catchall_user.local_part || '@' || catchall_user.domain,
            GROUP_CONCAT(alias_users.local_part || '@' || alias_users.domain)
    FROM    users
            LEFT OUTER JOIN catchall ON
              users.domain = catchall.domain
            LEFT OUTER JOIN users AS catchall_user ON
              catchall_user.id = catchall.user_id
            LEFT OUTER JOIN aliases ON
              aliases.user_id = users.id
            LEFT OUTER JOIN users AS alias_users ON
              alias_users.id = aliases.alias_user_id
    GROUP BY
            users.domain, users.local_part, catchall_user.domain, catchall_user.local_part
  """
  result = initTable[string,Domain]()
  for row in db.rows(sql(q)):
    if not result.contains(row[0]):
      result[row[0]] = Domain(
        mailboxes: initTable[string,Mailbox](),
        aliases:   initTable[string,Alias](),
        catchall:  row[2])
    if row[3] == "":
      result[row[0]].mailboxes[row[1]] = Mailbox()
    else:
      result[row[0]].aliases[row[1]] = Alias(alias: row[3])

proc update_domain_catchall*(db: DbConn, domain: string, user: Email) {.gcsafe.} =
  db.exec(sql"""
    INSERT INTO catchall(domain, user_id)
    SELECT ?, users.id
    FROM users
    WHERE users.local_part = ? AND users.domain = ?
    ON CONFLICT (domain) DO
    UPDATE SET user_id = EXCLUDED.user_id
  """, domain, user.local_part, user.domain)

