import zfblast
import ./common

import ./db/users
import ./controllers/admin_login
import ./controllers/admin_signup

proc handler*(ctx: HttpContext, com: Common) {.async gcsafe.} =
  if com.db.num_users() == 0:
    await admin_signup(ctx, com)
  else:
    await admin_login(ctx, com)

  defer:
    await ctx.resp
