import marshal

import ./dbcommon
import ./users
import ./domains

type
  DbOperations* = seq[DbOperation]

  DbOperationType* = enum
    DbUpdateDomainCatchall
    DbCreateUser
    DbAddAlias
    DbUpdateUserPassword

  DbOperation* = object
    case kind*: DbOperationType
    of DbUpdateDomainCatchall:
      update_domain_catchall*: DbUpdateDomainCatchallOp
    of DbCreateUser:
      create_user*: DbCreateUserOp
    of DbAddAlias:
      add_alias*: DbAddAliasOp
    of DbUpdateUserPassword:
      update_user_password*: DbUpdateUserPasswordOp

proc parse_operations*(json: string): DbOperations =
  to[DbOperations](json)

proc to_json*(ops: DbOperations): string =
  $$ops

proc create_user*(db: DbConn, local_part, domain, password: string, super_admin: bool = false, domain_admin: bool = false, auto_admin: bool = true) =
  let op = DbCreateUserOp(local_part: local_part, domain: domain, password: password, super_admin: super_admin, domain_admin: domain_admin, auto_admin: auto_admin)
  run(db, op)

proc add_alias*(db: DbConn, user: Email, alias: Email) =
  let op = DbAddAliasOp(user: user, alias: alias)
  run(db, op)

proc update_user_password*(db: DbConn, email: Email, password: string) {.gcsafe.} =
  let op = DbUpdateUserPasswordOp(email: email, password: password)
  run(db, op)

proc update_domain_catchall*(db: DbConn, domain: string, user: Email) {.gcsafe.} =
  let op = DbUpdateDomainCatchallOp(domain: domain, user: user)
  run(db, op)

