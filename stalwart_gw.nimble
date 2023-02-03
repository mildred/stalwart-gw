# Package

version       = "0.1.0"
author        = "Mildred Ki'Lya"
description   = "Gateway interface for Stalwart Accounts API"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["stalwart_gw"]


# Dependencies

requires "nim >= 1.6.0"

requires "docopt"
requires "zfblast#head"
requires "https://github.com/mildred/asynctools"
requires "templates"
requires "npeg"
requires "base32"
requires "jwt"
