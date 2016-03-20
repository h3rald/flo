import
  json,
  strutils,
  critbits,
  types,
  core


proc parseGraph(data: string): JsonNode =
  result = data.parseJson()
  if result["connections"].isNil:
    raise newException(NoConnectionsError, "No connections defined in graph.")
  if result["processes"].isNil:
    raise newException(NoProcessesError, "No processes defined in graph.")
  if result["processes"].kind != JObject:
    raise newException(InvalidDataError, "Property 'processes' is not an object.")
  if result["connections"].kind != JArray:
    raise newException(InvalidDataError, "Property 'connections' is not an array.")
  for p in result["processes"].pairs:
    if p.val.kind != JObject:
      raise newException(InvalidDataError, "Process '$1' is not an object." % [p.key])
    if p.val["component"].isNil:
      raise newException(InvalidDataError, "No component specified for process '$1'." % [p.key])
  var count = 0
  for c in result["connections"].items:
    count.inc
    if c.kind != JObject:
      raise newException(InvalidDataError, "Connection #$1 is not an object." % [$count])
    if c["data"].isNil and c["src"].isNil:
      raise newException(InvalidDataError, "No source or data specified for connection #$1." % [$count])
    if c["tgt"].isNil:
      raise newException(InvalidDataError, "No target specified for connection #$1." % [$count])
    if not c["src"].isNil:
      if c["src"].kind != JObject:
        raise newException(InvalidDataError, "Source of connection #$1 is not an object." % [$count])
      if c{"src", "process"}.isNil:
        raise newException(InvalidDataError, "No process specified for the source of connection #$1." % [$count])
      if c{"src", "port"}.isNil:
        raise newException(InvalidDataError, "No port specified for the source of connection #$1." % [$count])
    if c["tgt"].kind != JObject:
      raise newException(InvalidDataError, "Target of connection #$1 is not an object." % [$count])
    if c{"tgt", "process"}.isNil:
      raise newException(InvalidDataError, "No process specified for the target of connection #$1." % [$count])
    if c{"tgt", "port"}.isNil:
      raise newException(InvalidDataError, "No port specified for the target of connection #$1." % [$count])

proc toGraph*(data: string): Graph =
  var json = data.parseGraph()
  result = graph()
  for p in json["processes"].pairs:
    result.add(process(p.key, @(p.val["component"].getStr)))
  for c in json["connections"].items:
    if not c["data"].isNil:
      let pkt = @(c["data"])
      let tgt = result.processes[c{"tgt", "process"}.getStr][c{"tgt", "port"}.getStr]
      result.add(pkt -> tgt)
    else:
      let src = result.processes[c{"src","process"}.getStr][c{"src", "port"}.getStr]
      let tgt = result.processes[c{"tgt", "process"}.getStr][c{"tgt", "port"}.getStr]
      result.add(src -> tgt)


