import zfblast
import ../common
import ../db/op

proc admin_replicate*(ctx: HttpContext, com: CommonRequest) {.async gcsafe.} =
  let ops = ctx.request.body.read_file().parse_operations()
  await run(com.dbw, ops)
  ctx.response.httpCode = Http201

