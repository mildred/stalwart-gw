import zfblast
import ../common
import ../views/layout
import ../views/login

proc admin_login*(ctx: HttpContext, com: Common) {.async gcsafe.} =
  ctx.response.body = layout(
    title = "Log-In",
    main = login())

