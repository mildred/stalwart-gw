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
    # echo &"Obtained JMAP session {client.jmap_session}"
    client.api_url = client.jmap_session["apiUrl"].get_str()
    for account_id in keys(client.jmap_session["accounts"]):
      client.account_id = account_id
      break
    echo &"API to {client.api_url} account {client.account_id}"
  result = client.jmap_session

proc api_request(client: Client, request: JsonNode): Future[JsonNode] {.async.} =
  let http = newAsyncHttpClient(headers = newHttpHeaders({
    "Authorization": &"Basic {client.credentials}",
    "Content-Type": "application/json"
  }))
  let res = await http.postContent(client.api_url, $request)
  result = parse_json(res)

proc account_list*(client: Client): Future[JsonNode] {.async.} =
  discard await client.get_jmap_session()
  let res =await client.api_request(%{
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
        "properties": %[%"email", %"name", %"description", %"quota", %"timezone", %"aliases"]
      },%"s1"]]
  })
  result = res["methodResponses"][1][1]["list"]

proc domain_list*(client: Client): Future[JsonNode] {.async.} =
  discard await client.get_jmap_session()
  let res = await client.api_request(%{
    "using": %["urn:ietf:params:jmap:core","urn:ietf:params:jmap:mail"],
    "methodCalls": %[
      %[%"Principal/query",%{
        "accountId": %client.account_id,
        "filter": %{"type": %"domain"},
        "sort": %[ %{"isAscending": %true, "property": %"name"} ]
      },%"s0"],
      %[%"Principal/get",%{
        "accountId": %client.account_id,
        "#ids": %{"resultOf": %"s0", "name": %"Principal/query", "path": %"/ids"},
        "properties": %[%"name", %"description", %"dkim"]
      },%"s1"]]
  })
  result = res["methodResponses"][1][1]["list"]

proc find_exact_account(accounts: JsonNode, email: string, aliases: bool = true, multiple: bool = false): seq[JsonNode] =
  result = @[]
  for account in items(accounts):
    if account["email"].get_str == email:
      result.add(account)
      if not multiple: return result
      else: continue
    if aliases and account["aliases"].kind != JNull:
      for alias in items(account["aliases"]):
        if alias.get_str == email:
          result.add(account)
          if not multiple: return result
          else: continue

proc user_exists*(client: Client, local, domain: string): Future[bool] {.async.} =
  result = false
  let accounts = await client.account_list()
  for account in accounts.find_exact_account(&"{local}@{domain}"):
    return true

proc has_domain*(client: Client, domain: string): Future[bool] {.async.} =
  result = false
  for dom in items(await client.domain_list()):
    if dom["name"].get_str == domain:
      return true

proc get_alias_or_catchall*(client: Client, local, domain: string): Future[seq[string]] {.async.} =
  result = @[]
  let accounts = await client.account_list()
  for account in accounts.find_exact_account(&"{local}@{domain}", multiple = true):
    result.add(account["email"].get_str)
  if result.len > 0:
    return result
  for account in accounts.find_exact_account(&"*@{domain}", multiple = true):
    result.add(account["email"].get_str)

proc check_user_password*(client: Client, user, pass: string): Future[bool] {.async.} =
  result = false
