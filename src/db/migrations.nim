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
          id          INTEGER PRIMARY KEY NOT NULL,
          local_part  TEXT NOT NULL,
          domain      TEXT NOT NULL,
          admin       BOOLEAN NOT NULL DEFAULT FALSE,
          created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      """)
      user_version = 1
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

