import zfblast
import options
import ../common
import ../views/layout_signed
import ../views/user
import ../db/users
import ../db/op
import ../httputil

proc admin_user*(ctx: HttpContext, com: CommonRequest, user: string) {.async gcsafe.} =
  var message = ""
  let user_email = parse_email(user)
  if user_email.is_none:
    ctx.response.httpCode = Http404
    return
  if not com.db.is_admin(com.session.data.email, user_email.get):
    ctx.response.httpCode = Http403
    return

  if ctx.request.httpMethod == HttpPost:
    let params = ctx.request.body.read_file().decode_data()
    let email = params.get_param("email")
    let password1 = params.get_param("password1")
    let password2 = params.get_param("password2")
    let catchall = params.get_param("catchall")
    let aliases = params.get_params("alias")

    if password1 == password2 and email == user:
      com.db.update_user_password(user_email.get, password1)
      message.add("Password has been updated. ")

    if catchall != "" and user_email.is_some:
      com.db.update_domain_catchall(user_email.get.domain, user_email.get)

    for alias in aliases:
      let alias_email = alias.parse_email()
      if alias_email.is_some:
        com.db.add_alias(user_email.get, alias_email.get)

  let super_admin = com.db.is_admin(com.session.data.email)
  let domain_admin = com.db.is_admin(com.session.data.email, user_email.get.domain)
  let user_super_admin = com.db.is_admin(user_email.get)
  let user_domain_admin = com.db.is_admin(user_email.get, user_email.get.domain)
  let aliases = com.db.fetch_user_aliases(user_email.get)

  ctx.response.body = com.layout_signed(
    title = user,
    message = message,
    main = com.view_user(
      user = user_email.get,
      aliases = aliases,
      super_admin = super_admin,
      domain_admin = domain_admin,
      user_super_admin = user_super_admin,
      user_domain_admin = user_domain_admin))

