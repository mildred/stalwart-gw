import zfblast
import options
import ../common
import ../views/layout_signed
import ../views/users as vusers
import ../db/users
import ../db/op
import ../httputil

proc admin_users*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  let is_super_admin = com.db.is_admin(com.session.data.email)

  if ctx.request.httpMethod == HttpPost:
    let params = ctx.request.body.read_file().decode_data()
    let email = parse_email(params.get_param("email"))
    let password1 = params.get_param("password1")
    let password2 = params.get_param("password2")
    let super_admin  = params.get_param("super_admin") == "1" and is_super_admin
    let domain_admin = params.get_param("domain_admin") == "1"
    let catchall = params.get_param("catchall")
    let aliases = params.get_params("alias")

    if password1 != password2 or email.is_none:
      ctx.response.httpCode = Http400
      return

    if not com.db.is_admin(com.session.data.email, email.get.domain):
      ctx.response.httpCode = Http403
      return

    await com.dbw.create_user(email.get.local_part, email.get.domain, password1,
                        super_admin = super_admin,
                        domain_admin = domain_admin,
                        auto_admin = false)

    if catchall != "" and email.is_some:
      await com.dbw.update_domain_catchall(email.get.domain, email.get)

    for alias in aliases:
      let alias_email = alias.parse_email()
      if alias_email.is_some:
        await com.dbw.add_alias(email.get, alias_email.get)

    ctx.response.httpCode = Http303
    ctx.response.headers.add("Location", &"{com.prefix}/users/{$email.get}")

  ctx.response.body = com.layout_signed(
    title = "Users",
    main = com.view_users(
      super_admin = is_super_admin))

