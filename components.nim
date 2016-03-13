import
  types,
  core, 
  os,
  json




define("Writer")
  .stdports()
  .ready do (p: Process) -> bool:
    return p.claimFirst(P_IN)
  .execute do (p: Process):
    if p[P_OUT].isAttached:
      # TODO
      discard
    else:
      echo p[P_IN].receive()

define("Reader")
  .stdports()
  .ready do (p: Process) -> bool:
    return true
  .execute do (p: Process):
    var s: string
    if p[P_IN].isAttached:
      # TODO
      discard
    else:
      s = stdin.readline
    if p[P_OUT].isAttached:
      p[P_OUT].send(%s)

when isMainModule:
  var w = @"Writer"
  var r = @"Reader"
  
  var pW = process("W1", w, true)
  var pR = process("R1", r)

  var g = graph()
  g.add(pW)
  g.add(pR)
  g.add(pR[P_OUT] -> pW[P_IN]) 
  
  echo g

  g.network.start()

  
  

