# Package

version       = "0.1.0"
author        = "Mildred Ki'Lya"
description   = "Account server with administration interface over HTTP and API interface to use with Cyrus-SASL http auxprop plugin"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["accountserver"]


# Dependencies

requires "nim >= 1.6.0"

requires "docopt"
requires "zfblast#head"
requires "https://github.com/mildred/asynctools"
requires "templates"
requires "npeg#head"
requires "base32"
requires "jwt"
