import
  types,
  strutils,
  os,
  queues,
  critbits

proc canRun(p: Process): bool {.discardable.}=
  return p.component.ready(p)

proc addStandardPorts(c: var Component) =
  c.inport(P_IN)
  c.outport(P_OUT)
  c.outport(P_ERR)

proc available(p: Port): bool =
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

proc enqueue(c: Connection, packet: Packet) =
  QUEUES[c.id].enqueue packet

proc dequeue(c: Connection): Packet =
  return QUEUES[c.id].dequeue()

proc send*(outport: Port, packet: Packet) =
  discard outport.requireOutPort().requireAttachedPort()
  outport.connection.enqueue(packet)

proc receive*(inport: Port): Packet = 
  discard inport.requireInPort().requireAttachedPort()
  return inport.connection.dequeue()

proc run(p: Process) =
  while true:
    case p.status:
      of INITIALIZED, WAITING:
        if p.canRun():
          p.status = READY
      of READY:
        p.status = ACTIVE
        discard p.component.execute(p)
      of ACTIVE:
        if p.canRun():
          p.status = READY
        else:
          p.status = WAITING
      of IDLE: # NOT MANAGED FOR NOW
        if not p.component.execute(p):
          p.status = STOPPED
      of STOPPED:
        break
    #echo "$1: $2" % [$p, $p.status]
    sleep(50)

proc start(n: Network) =
  var 
    threads = newSeq[Thread[Process]](n.graph.processes.len)
    count = 0
  for p in n.graph.processes.values:
    createThread(threads[count], run, p)
    count.inc
  threads.joinThreads()


when isMainModule:
  import
    times,
    json

  var c = component("Consumer")
  c.addStandardPorts()
  c.ready = proc(p: Process): bool =
    return p.claimFirst(P_IN)
  c.execute = proc(p: Process): bool =
    echo p[P_IN].receive()
    return true

  var p = component("Provider")
  p.addStandardPorts()
  p.ready = proc(p: Process): bool =
    return p[P_OUT].available()
  p.execute = proc(p: Process): bool =
    p[P_OUT].send(@(%(cpuTime())))
    return true
  
  var cons = process("CONS", c) 
  var prov = process("PROV", p)

  var graph = graph()
  graph.add(cons)
  graph.add(prov)
  graph.add(prov[P_OUT] -> cons[P_IN])

  echo graph

  network(graph).start()

