import
  types,
  core, 
  os,
  json




namespace "os":

  define("writer")
    .ready do (p: Process) -> bool:
      return p.claimFirst(P_IN)
    .execute do (p: Process):
      if p[P_OUT].isAttached:
        # TODO
        discard
      else:
        echo p[P_IN].receive().contents.getStr
  
  define("reader")
    .ready do (p: Process) -> bool:
      return p.persistent
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
  var w = @"os.writer"
  var r = @"os.reader"
  
  var pW = process("W1", w)
  var pR = process("R1", r)

  var g = graph()
  g.add(pW)
  g.add(pR)
  g.add(pR[P_OUT] -> pW[P_IN]) 
  g.add(%true -> pR[P_WAIT]) 
  g.add(%true -> pW[P_WAIT]) 
  
  echo g

  g.network.start()

  
  

