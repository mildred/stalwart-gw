import zfblast
import options
import ../httputil
import ../common
import ../views/layout_anon
import ../views/signup
import ../db/users

proc admin_signup*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  let domain = ctx.request.url.get_query("domain", "")

  if com.db.num_users() != 0:
    if com.session == nil or not com.db.is_admin(com.session.data.email, domain):
      ctx.response.httpCode = Http403
      return

  if ctx.request.httpMethod == HttpPost:
    let params = ctx.request.body.read_file().decode_data()
    let email = parse_email(params.get_param("email"))
    let password1 = params.get_param("password1")
    let password2 = params.get_param("password2")
    if password1 == password2 and email.is_some:
      if domain == "" or domain == email.get.domain:
        com.db.create_user(email.get.local_part, email.get.domain, password1)
        ctx.response.httpCode = Http303
        ctx.response.headers.add("Location", &"{com.prefix}/")
        return

  ctx.response.body = com.layout_anon(
    title = "Sign-Up",
    main = com.signup(domain = domain))

