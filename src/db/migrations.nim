import strutils
import strformat
import db_sqlite
import tables

proc migrate*(db: DbConn): bool =
  var user_version = parseInt(db.get_value(sql"PRAGMA user_version;"))
  if user_version == 0:
    echo "Initialise database..."
  var migrating = true
  while migrating:
    var description: string
    let old_version = user_version
    case user_version
    of 0:
      description = "database initialized"
      db.exec(sql"""
        CREATE TABLE IF NOT EXISTS users (
          id           INTEGER PRIMARY KEY NOT NULL,
          local_part   TEXT NOT NULL,
          domain       TEXT NOT NULL,
          super_admin  BOOLEAN NOT NULL DEFAULT FALSE,
          domain_admin BOOLEAN NOT NULL DEFAULT FALSE,
          created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT user_unique UNIQUE (local_part, domain)
        )
      """)
      user_version = 1
    of 1:
      description = "added user parameters"
      db.exec(sql"""
        CREATE TABLE IF NOT EXISTS user_params (
          id           INTEGER PRIMARY KEY NOT NULL,
          user_id      INTEGER NOT NULL,
          name         TEXT NOT NULL,
          value        TEXT NOT NULL,
          CONSTRAINT param_unique UNIQUE (user_id, name)
        )
      """)
      user_version = 2
    else:
      migrating = false
    if migrating:
      if old_version == user_version:
        return false
      db.exec(sql"PRAGMA user_version = ?;", user_version)
      if description == "":
        echo &"Migrated database v{old_version} to v{user_version}"
      else:
        echo &"Migrated database v{old_version} to v{user_version}: {description}"
  echo "Finished database initialization"
  return true

