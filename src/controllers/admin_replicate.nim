import zfblast
import marshal
import ../common
import ../db/op
import ../db/users

proc admin_replicate*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  if ctx.request.httpMethod == HttpPost:
    let ops = ctx.request.body.read_file().parse_operations()
    await run(com.dbw, ops)
    ctx.response.httpCode = Http201
  else:
    let extract = users.extract_all(com.db)
    ctx.response.httpCode = Http200
    ctx.response.headers.add("Content-Type", "application/json")
    ctx.response.body = $$extract

