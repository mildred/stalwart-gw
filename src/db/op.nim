import asyncdispatch
import marshal
import httpclient
import strformat

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
    DbInsertAllData

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
    of DbInsertAllData:
      insert_all_data*: DbInsertAllDataOp

proc parse_operations*(json: string): DbOperations =
  to[DbOperations](json)

proc to_json*(ops: DbOperations): string =
  $$ops

proc replicate(db: DbWriteHandle, ops: DbOperations) {.async.} =
  let client = newAsyncHttpClient()
  let payload = ops.to_json()
  for replicate_to in db.replicate_to:
    for op in ops:
      echo &"Replicate to {replicate_to}: {op.kind}"
    try:
      let res = await client.postContent(replicate_to, payload)
      echo &"Replicate to {replicate_to} ({ops.len} operations): {res}"
    except:
      echo &"ERROR: Replicate to {replicate_to} ({ops.len} operations): FAILED {getCurrentExceptionMsg()}"


proc replicate(db: DbWriteHandle, op: DbOperation) {.async.} =
  await replicate(db, @[op])

proc run*(db: DbWriteHandle, op: DbOperation, replicate: bool = true) {.async.} =
  case op.kind
  of DbUpdateDomainCatchall:
    run(db.db, op.update_domain_catchall)
  of DbCreateUser:
    run(db.db, op.create_user)
  of DbAddAlias:
    run(db.db, op.add_alias)
  of DbUpdateUserPassword:
    run(db.db, op.update_user_password)
  of DbInsertAllData:
    run(db.db, op.insert_all_data)
  if replicate:
    await replicate(db, op)

proc run*(db: DbWriteHandle, ops: DbOperations) {.async.} =
  for op in ops:
    await run(db, op, false)
  await replicate(db, ops)

proc create_user*(db: DbWriteHandle, local_part, domain, password: string, super_admin: bool = false, domain_admin: bool = false, auto_admin: bool = true) {.async.} =
  let op = DbCreateUserOp(local_part: local_part, domain: domain, password: password, super_admin: super_admin, domain_admin: domain_admin, auto_admin: auto_admin)
  run(db.db, op)
  await replicate(db, DbOperation(kind: DbCreateUser, create_user: op))

proc add_alias*(db: DbWriteHandle, user: Email, alias: Email) {.async.} =
  let op = DbAddAliasOp(user: user, alias: alias)
  run(db.db, op)
  await replicate(db, DbOperation(kind: DbAddAlias, add_alias: op))

proc update_user_password*(db: DbWriteHandle, email: Email, password: string) {.async gcsafe.} =
  let op = DbUpdateUserPasswordOp(email: email, password: password)
  run(db.db, op)
  await replicate(db, DbOperation(kind: DbUpdateUserPassword, update_user_password: op))

proc update_domain_catchall*(db: DbWriteHandle, domain: string, user: Email) {.async gcsafe.} =
  let op = DbUpdateDomainCatchallOp(domain: domain, user: user)
  run(db.db, op)
  await replicate(db, DbOperation(kind: DbUpdateDomainCatchall, update_domain_catchall: op))

proc insert_all_data*(db: DbWriteHandle, extract: Extract, only_replicate: bool) {.async gcsafe.} =
  let op = DbInsertAllDataOp(extract: extract)
  if not only_replicate:
    run(db.db, op)
  await replicate(db, DbOperation(kind: DbInsertAllData, insert_all_data: op))

