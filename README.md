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

Services
--------

Accountserver provide three different services:

### Admin HTTP console

- default address: `127.0.0.1:8080`

Provides a UI to administrate the users. It provides a login form and can be
made available to the public.

### HTTP API

- default address: `127.0.0.1:8000`

Allows others programs to communicate using HTTP to the accountserver.
**Warning: this endpoint exposes all users password in clear, secure this
appropriately. This should not be open to the public.**

### TCP Socket API

- default address: `127.0.0.1:7999`

Allows others program to communicate with the accountserver using plaintext
TCP socket. **This should not be open to the public.**

Provides a UI to administrate the users

Replication
-----------

Replication replicates operations as they appear on the master. They are sent to
the replica. To test this:

    src/accountserver -v --insecure-logs -d accounts0.db --allow-replicate test0
    src/accountserver -v --insecure-logs -d accounts1.db --sockapi-port 7998 --api-port 8001 --admin-port 8081 --replicate-to http://localhost:8080/replicate/test0

[sasl2-httpdb]: https://github.com/mildred/sasl2-httpdb
