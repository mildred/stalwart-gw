import cgi
import tables

export cgi.decode_data

func encode_params*(params: openArray[(string,string)]): string {.gcsafe.} =
  result = ""
  for i, pair in params:
    if result != "":
      result = result & "&"
    result = result & cgi.encodeUrl(pair[0]) & "=" & cgi.encodeUrl(pair[1])

func decode_data*(data: string): Table[TaintedString, seq[TaintedString]] {.gcsafe.} =
  result = initTable[TaintedString,seq[TaintedString]]()
  for key, value in cgi.decode_data(data):
    result.mget_or_put(key, @[]).add(value)

func get_param*(params: Table[TaintedString, seq[TaintedString]], key: string, def: string = ""): TaintedString {.gcsafe.} =
  result = def
  let list = params.get_or_default(key)
  if len(list) > 0:
    result = list[0]

func get_params*(params: Table[TaintedString, seq[TaintedString]], key: string): seq[TaintedString] {.gcsafe.} =
  result = params.get_or_default(key)

