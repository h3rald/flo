import
  types,
  strutils,
  os,
  queues,
  critbits,
  json

proc ready(p: Process): bool {.discardable.}=
  return p.component.readyProc(p)

proc stdports*(c: Component): Component {.discardable.} =
  c.inport(P_IN)
  c.outport(P_OUT)
  c.outport(P_ERR)
  return c

proc available*(p: Port): bool =
  discard p.requireOutPort().requireAttachedPort()
  return QUEUES[p.connection.id].len < p.connection.size

proc lock(p: Process, port: string): bool =
  if p[port].lock.isNil or p[port].lock == p:
    p[port].lock = p
    return true
  else:
    return false

proc unlock(p: Process, port: string): bool =
  if p[port].lock.isNil or p[port].lock == p:
    p[port].lock = nil
    return true
  else:
    return false

proc claim(p: Process, pkt: Packet): bool =
  if pkt.owner.isNil:
    pkt.owner = p
    return true
  else:
    return false

iterator packets(p: Port): Packet =
  discard p.requireInPort().requireAttachedPort()
  for pkt in QUEUES[p.connection.id].items:
    yield pkt

proc claimFirst*(p: Process, port: string, receivable: proc(pkt: Packet): bool = anyPacket): bool =
  if p.lock(port):
    for pkt in p[port].packets:
      if pkt.receivable:
        if p.claim(pkt):
          return p.unlock(port)
  return false

proc send*(outport: Port, packet: Packet) =
  discard outport.requireOutPort().requireAttachedPort()
  outport.connection.enqueue(packet)

proc send*(outport: Port, contents: JsonNode) =
  outport.send(@contents)

proc receive*(inport: Port): Packet = 
  discard inport.requireInPort().requireAttachedPort()
  return inport.connection.dequeue()

proc run(p: Process) =
  while true:
    case p.status:
      of INITIALIZED:
        if p.ready():
          p.status = READY
        else: 
          p.status = IDLE
      of READY:
        p.status = ACTIVE
        p.component.executeProc(p)
      of ACTIVE:
        if p.ready():
          p.status = READY
        else:
          p.status = IDLE
      of IDLE: 
        if p.ready():
          p.status = READY
        if not p.persistent:
          p.status = STOPPED
      of STOPPED:
        break
    #echo "$1: $2" % [$p, $p.status]
    sleep(TICK)

proc start*(n: Network) =
  var 
    threads = newSeq[Thread[Process]](n.graph.processes.len)
    count = 0
  for p in n.graph.processes.values:
    createThread(threads[count], run, p)
    count.inc
  threads.joinThreads()


when isMainModule:
  import
    times

  var c = component("Consumer")
    .stdports()
    .ready do (p: Process) -> bool:
      return p.claimFirst(P_IN)
    .execute do (p: Process):
      echo p[P_IN].receive()

  var p = component("Provider")
    .stdports()
    .ready do (p: Process) -> bool:
      return p[P_OUT].available()
    .execute do (p: Process):
      p[P_OUT].send(%(cpuTime()))
  
  var cons = process("CONS", c, true) 
  var prov = process("PROV", p)

  var graph = graph()
  graph.add(cons)
  graph.add(prov)
  graph.add(prov[P_OUT] -> cons[P_IN])
  #graph.add(%"TEST" -> cons[P_IN])

  echo graph

  network(graph).start()

