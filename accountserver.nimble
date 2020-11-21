# Package

version       = "0.1.0"
author        = "Mildred Ki'Lya"
description   = "Account server with administration interface over HTTP and API interface to use with Cyrus-SASL http auxprop plugin"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["accountserver"]


# Dependencies

requires "nim >= 1.4.0"

requires "docopt"
requires "zfblast@#head"
