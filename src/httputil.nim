import cgi
import tables

export cgi.decode_data

func decode_data*(data: string): Table[TaintedString, seq[TaintedString]] =
  result = initTable[TaintedString,seq[TaintedString]]()
  for key, value in cgi.decode_data(data):
    result[key].add(value)

func get_all*[A,B](table: Table[A,seq[B]], key: A): seq[B] =
  result = tables.`[]`(table, key)

func get*[A,B](table: Table[A,seq[B]], key: A): B =
  result = tables.`[]`(table, key)[0]

func `[]`*[A,B](table: Table[A,seq[B]], key: A): B =
  let list: seq[B] = tables.`[]`(table, key)
  result = list[0]

