import zfblast
import ../common
import ../views/layout_signed
import ../views/domain
import ../db/users

proc admin_domain*(ctx: HttpContext, com: CommonRequest, domain: string) {.async gcsafe.} =
  if not com.db.is_admin(com.session.data.email, domain):
    ctx.response.httpCode = Http403
    return

  let super_admin = com.db.is_admin(com.session.data.email)

  let users = com.db.fetch_users(domain)
  ctx.response.body = com.layout_signed(
    title = domain,
    main = com.domain(
      domain = domain,
      users = users,
      super_admin = super_admin))

