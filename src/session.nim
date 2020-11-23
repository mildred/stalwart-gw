import times
import ./httputil/sessions

type SessionData* = object
 discard

type SessionList* = sessions.SessionList[SessionData]
type Session* = sessions.Session[SessionData]

proc close(session: sessions.Session[SessionData]) {.gcsafe.} =
  discard

func newSessionList*(timeout: Duration): SessionList {.gcsafe.} =
  sessions.newSessionList(timeout, close)

export sessions.defaultSessionTimeout
export sessions.deleteSession
export sessions.findSession
export sessions.newSession
export sessions.createSession
