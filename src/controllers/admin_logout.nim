import zfblast
import cookies
import times
import ../session
import ../common

proc admin_logout*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  let sess = com.sessions.createSession()
  if com.session != nil:
    discard com.sessions.deleteSession(com.session.sid)

  ctx.response.httpCode = Http303
  ctx.response.headers.add("Location", &"{com.prefix}/")
  ctx.response.headers.add("Set-Cookie", cookies.setCookie("sid", "", noName = true, expires = times.now()))
  return

