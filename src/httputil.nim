import cgi
import tables
import sequtils

export cgi.decode_data

proc decode_data*(data: string): Table[TaintedString, seq[TaintedString]] {.gcsafe.} =
  result = initTable[TaintedString,seq[TaintedString]]()
  for key, value in cgi.decode_data(data):
    result[key] = concat(result.getOrDefault(key), @[value])

func get_all[A,B](table: Table[A,seq[B]], key: A): seq[B] {.gcsafe.} =
  result = tables.`[]`(table, key)

func get[A,B](table: Table[A,seq[B]], key: A): B {.gcsafe.} =
  result = tables.`[]`(table, key)[0]

func `[]`[A,B](table: Table[A,seq[B]], key: A): B {.gcsafe.} =
  let list: seq[B] = tables.`[]`(table, key)
  result = list[0]

