import zfblast/server
import ../common
import ../views/layout_signed
import ../views/domains
import ../db/users

proc admin_domains*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  let email = com.session.data.email
  let admin_domains = com.db.fetch_admin_domains(email)
  ctx.response.body = com.layout_signed(
    title = "Domains",
    main = com.domains(
      my_domain = email.domain,
      domains = admin_domains))

