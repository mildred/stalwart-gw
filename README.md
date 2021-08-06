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

[sasl2-httpdb]: https://github.com/mildred/sasl2-httpdb
