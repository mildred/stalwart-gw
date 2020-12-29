import zfblast
import ../common
import ../views/layout_signed
import ../views/home
import ../db/users

proc admin_home*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  let email = com.session.data.email
  let super_admin = com.db.is_admin(email)
  let domain_admin = com.db.is_admin(email, email.domain)
  let admin_domains = com.db.fetch_admin_domains(email)
  let users = if com.db.is_admin(email, email.domain): com.db.fetch_users(email.domain) else: @[]
  ctx.response.body = com.layout_signed(
    title = "Home",
    main = com.home(
      user = email,
      super_admin = super_admin,
      domain_admin = domain_admin,
      admin_domains = admin_domains,
      domain_users = users))

