import httpcore
import strtabs
import cookies
import zfblast
import strutils
import ./common
import ./session

import ./db/users
import ./controllers/admin_login
import ./controllers/admin_logout
import ./controllers/admin_home
import ./controllers/admin_signup
import ./controllers/admin_domains
import ./controllers/admin_domain
import ./controllers/admin_users
import ./controllers/admin_user

proc handler*(ctx: HttpContext, com: Common) {.async gcsafe.} =
  let cookies = ctx.request.headers.getOrDefault("Cookie").parseCookies()
  let prefix = ctx.request.headers.getOrDefault("X-Forwarded-Prefix")
  let sess = com.sessions.findSession(cookies.getOrDefault("sid"))

  let common = CommonRequest(com: com, session: sess, prefix: prefix)

  defer:
    await ctx.resp

  if sess == nil and com.db.num_users() == 0:
    await admin_signup(ctx, common)
  elif sess == nil:
    await admin_login(ctx, common)
  elif ctx.request.url.get_path == &"{common.prefix}/logout":
    await admin_logout(ctx, common)
  elif ctx.request.url.get_path == &"{common.prefix}/domains":
    await admin_domains(ctx, common)
  elif ctx.request.url.get_path.starts_with(&"{common.prefix}/domains/"):
    var domain = ctx.request.url.get_path
    domain.remove_prefix(&"{common.prefix}/domains/")
    await admin_domain(ctx, common, domain)
  elif ctx.request.url.get_path == &"{common.prefix}/users":
    await admin_users(ctx, common)
  elif ctx.request.url.get_path.starts_with(&"{common.prefix}/users/"):
    var user = ctx.request.url.get_path
    user.remove_prefix(&"{common.prefix}/users/")
    await admin_user(ctx, common, user)
  else:
    await admin_home(ctx, common)
