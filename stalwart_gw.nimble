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
requires "zfblast"
