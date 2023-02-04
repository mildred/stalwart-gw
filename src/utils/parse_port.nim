import strutils, net, asyncnet, nativesockets, os, options, asyncdispatch
import ./sd_daemon

proc parse_sd_socket_activation*(arg: string): int =
  var parts = arg.split("=")
  if parts.len == 2 and parts[0] == "sd":
    parts = parts[1].split(':', 1)
    if parts.len == 1:
      let n = parse_int(parts[0])
      if n < sd_listen_fds():
        return SD_LISTEN_FDS_START + n
    else:
      let fds = sd_listen_fds_with_names()
      var n = parse_int(parts[1])
      var fd = SD_LISTEN_FDS_START
      for fdname in fds:
        if fdname == parts[0]:
          if n == 0:
            return fd
          else:
            n = n - 1
        fd = fd + 1
  return 0

proc parse_port*(arg: string, def: int): Port =
  let parts = arg.split("=")
  if parts.len == 2 and parts[0] == "sd":
    return Port(def)
  return Port(parse_int(arg))


proc get_bound_socket_async*(address: string, port: Port, protocol = IPPROTO_TCP, buffered = true): owned(AsyncSocket) =
  let sockType = protocol.toSockType()

  let aiList = getAddrInfo(address, port, AF_UNSPEC, sockType, protocol)

  let invalidFD: AsyncFD = osInvalidSocket.AsyncFD

  var fdPerDomain: array[low(Domain).ord..high(Domain).ord, AsyncFD]
  for i in low(fdPerDomain)..high(fdPerDomain):
    fdPerDomain[i] = invalidFD
  template closeUnusedFds(domainToKeep = -1) {.dirty.} =
    for i, fd in fdPerDomain:
      if fd != invalidFD and i != domainToKeep:
        fd.closeSocket()

  var success = false
  var lastError: OSErrorCode
  var it = aiList
  var domain: Domain
  var lastFd: AsyncFD
  while it != nil:
    let domainOpt = it.ai_family.toKnownDomain()
    if domainOpt.isNone:
      it = it.ai_next
      continue
    domain = domainOpt.unsafeGet()
    lastFd = fdPerDomain[ord(domain)]
    if lastFd == invalidFD:
      lastFd = createAsyncNativeSocket(domain, sockType, protocol)
      if lastFd == invalidFD:
        # we always raise if socket creation failed, because it means a
        # network system problem (e.g. not enough FDs), and not an unreachable
        # address.
        let err = osLastError()
        freeAddrInfo(aiList)
        closeUnusedFds()
        raiseOSError(err)
      fdPerDomain[ord(domain)] = lastFd
    result = newAsyncSocket(lastFd, domain, sockType, protocol, buffered)
    if bindAddr(result.getFd(), it.ai_addr, it.ai_addrlen.SockLen) == 0'i32:
      success = true
      break
    lastError = osLastError()
    it = it.ai_next
  freeAddrInfo(aiList)
  closeUnusedFds(ord(domain))

  if success:
    return result
  elif lastError != 0.OSErrorCode:
    raiseOSError(lastError)
  else:
    raise newException(IOError, "Couldn't resolve address: " & address)
