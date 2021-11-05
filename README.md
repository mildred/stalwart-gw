accountserver
=============

accountserver is a system service that provides on two separate ports:

- an admin interface to manage users and passwords, accessible by the users
  themselves to change their password or other details if needed

- an API accessible by [sasl2-httpdb] auxprop plugin

The storage is a SQLite database.

**This is a work in progress**

FIXME
-----

- replication HTTP client does not check CA certificates

Build
-----

    nimble c src/accountserver

Replication
-----------

Replication replicates operations as they appear on the master. They are sent to
the replica. To test this:

    src/accountserver -v --insecure-logs -d accounts0.db --allow-replicate test0
    src/accountserver -v --insecure-logs -d accounts1.db --sockapi-port 7998 --api-port 8001 --admin-port 8081 --replicate-to http://localhost:8080/replicate/test0

[sasl2-httpdb]: https://github.com/mildred/sasl2-httpdb
