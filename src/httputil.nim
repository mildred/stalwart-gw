import cgi
import tables

export cgi.decode_data

func decode_data*(data: string): Table[TaintedString, TaintedString] =
  result = initTable[TaintedString,TaintedString]()
  for key, value in cgi.decode_data(data):
    result.add(key, value)

func get_all*[A,B](table: Table[A,B], key: A): seq[B] =
  result = @[]
  for k, v in pairs(table):
    if key == k:
      result.add(v)
