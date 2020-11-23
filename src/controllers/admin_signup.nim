import zfblast
import options
import ../httputil
import ../common
import ../views/layout
import ../views/signup
import ../db/users

proc admin_signup*(ctx: HttpContext, com: Common) {.async gcsafe.} =
  if ctx.request.httpMethod == HttpPost:
    let params = ctx.request.body.read_file().decode_data()
    let email = parse_email(params.get_param("email"))
    let password1 = params.get_param("password1")
    let password2 = params.get_param("password2")
    if password1 == password2 and email.is_some:
      com.db.create_user(email.get.local_part, email.get.domain, password1)
      ctx.response.httpCode = Http303
      ctx.response.headers.add("Location", "/")
      return

  ctx.response.body = layout(
    title = "Sign-Up",
    main = signup())

