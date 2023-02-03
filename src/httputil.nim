import cgi
import tables

export cgi.decode_data

func encode_params*(params: openArray[(string,string)]): string {.gcsafe.} =
  result = ""
  for i, pair in params:
    if result != "":
      result = result & "&"
    result = result & cgi.encodeUrl(pair[0]) & "=" & cgi.encodeUrl(pair[1])

func decode_data*(data: string): Table[string, seq[string]] {.gcsafe.} =
  result = initTable[string,seq[string]]()
  for key, value in cgi.decode_data(data):
    result.mget_or_put(key, @[]).add(value)

func get_param*(params: Table[string, seq[string]], key: string, def: string = ""): string {.gcsafe.} =
  result = def
  let list = params.get_or_default(key)
  if len(list) > 0:
    result = list[0]

func get_params*(params: Table[string, seq[string]], key: string): seq[string] {.gcsafe.} =
  result = params.get_or_default(key)

