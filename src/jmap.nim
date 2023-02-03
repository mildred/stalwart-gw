import httpclient
import json
import asyncdispatch
import strformat

type Client* = ref object
  url: string
  jmap_session: JsonNode
  credentials: string
  api_url: string
  account_id: string

proc newClient*(url: string, credentials: string): Client =
  result = Client(
    url: url,
    jmap_session: newJNull(),
    credentials: credentials)

proc get_jmap_session*(client: Client): Future[JsonNode] {.async.} =
  if client.jmap_session.kind == JNull:
    let http = newAsyncHttpClient(headers = newHttpHeaders({
      "Authorization": &"Basic {client.credentials}"
    }))
    echo &"Connecting to the JMAP server {client.url}"
    let jmap_session_raw = await http.getContent(client.url)
    client.jmap_session = parse_json(jmap_session_raw)
    echo &"Obtained JMAP session {client.jmap_session}"
    client.api_url = $client.jmap_session["apiUrl"]
    for account_id in keys(client.jmap_session["accounts"]):
      client.account_id = $account_id
      break
  result = client.jmap_session

proc accounts_list*(client: Client): Future[JsonNode] {.async.} =
  discard await client.get_jmap_session()
  let http = newAsyncHttpClient(headers = newHttpHeaders({
    "Authorization": &"Basic {client.credentials}",
    "Content-Type": "application/json"
  }))
  let req = %{
    "using": %["urn:ietf:params:jmap:core","urn:ietf:params:jmap:mail"],
    "methodCalls": %[
      %[%"Principal/query",%{
        "accountId": %client.account_id,
        "filter": %{"type": %"individual"},
        "sort": %[ %{"isAscending": %true, "property": %"email"} ]
      },%"s0"],
      %[%"Principal/get",%{
        "accountId": %client.account_id,
        "#ids": %{"resultOf": %"s0", "name": %"Principal/query", "path": %"/ids"},
        "properties": %[%"email", %"name", %"description", %"quota"]
      },%"s1"]]
  }
  let raw_res = await http.postContent(client.api_url, $req)
  let res = parse_json(raw_res)
  result = res

proc user_exists*(client: Client, local, domain: string): Future[bool] {.async.} =
  result = false

proc has_domain*(client: Client, domain: string): Future[bool] {.async.} =
  result = false

proc get_alias_or_catchall*(client: Client, user, domain: string): Future[string] {.async.} =
  result = &"{user}@{domain}"

proc check_user_password*(client: Client, user, pass: string): Future[bool] {.async.} =
  result = false
