import
  types,
  strutils,
  oids,
  os,
  queues,
  critbits,
  json

## String Representations

proc `$`*(port: Port): string =
  return port.name

proc `$`*(p: Packet): string =
  return $p.contents

proc `$`*(comp: Component): string =
  return comp.name 

proc `$`*(process: Process): string =
  return "$1($2)" % [process.name, process.component.name]

proc `$`*(conn: Connection): string =
  var src: string
  if not conn.packet.isNil:
    src = "[[PKT:$1]]" % $conn.packet
  else:
    src = "$1 $2" % [$conn.source.process, $conn.source.name]
  return "$1: $2 -> $3 $4" % [$conn.id, src, $conn.target.name, $conn.target.process]

proc `$`*(graph: Graph): string =
  result = "Processes:\n"
  for p in graph.processes.values:
    result &= " - " & $p & "\n"
  result &= "Connections:\n"
  for c in graph.connections:
    result &= " - " & $c & "\n"

## Constructors & Utility Methods

proc isAttached*(port: Port): bool =
  ## Returns true if port is attached.
  return not port.connection.isNil

proc isIn*(port: Port): bool =
  ## Returns true if port is an InPort.
  return port.direction == IN

proc isOut*(port: Port): bool =
  ## Returns true if port is an OutPort.
  return port.direction == OUT

proc requireOutPort*(outport: Port): Port =
  if outport.isIn:
    raise newException(InvalidPortError, "Port $1.$2 is not an OutPort" % [outport.component.name, outport.name]) 
  return outport

proc requireInPort*(inport: Port): Port =
  if inport.isOut:
    raise newException(InvalidPortError, "Port $1.$2 is not an InPort" % [inport.component.name, inport.name]) 
  return inport

proc requireAttachedPort*(port: Port): Port =
  if not port.isAttached:
    raise newException(PortNotAttachedError, "Port $1.$2 is not attached" % [port.component.name, port.name]) 
  return port

proc requireUnattachedPort*(port: Port): Port =
  if port.isAttached:
    raise newException(PortAlreadyAttachedError, "Port $1.$2 is already attached" % [port.component.name, port.name]) 
  return port

proc `@`*(contents: JsonNode, owner: Process = nil): Packet =
  ## Creates a new Packet.
  return Packet(contents: contents, owner: owner)

proc inport*(comp: Component, name: string): Component {.discardable.} =
  ## Adds a new InPort to an existing Component.
  comp.ports[name] = Port(name: name, component: comp, direction: IN)
  return comp

proc outport*(comp: Component, name: string): Component {.discardable.} =
  ## Adds a new OutPort to an existing Component.
  comp.ports[name] = Port(name: name, component: comp, direction: OUT)
  return comp

proc execute*(c: Component, fun: proc(p: Process)): Component {.discardable.} =
  c.executeProc = fun
  return c 

proc init*(c: Component, fun: proc(p: Process)): Component {.discardable.} =
  c.initProcs.add fun
  return c 

proc ready*(c: Component, fun: proc(p: Process): bool): Component {.discardable.} =
  c.readyProc = fun
  return c 

proc `@`*(name: string): Component =
  return COMPONENTS[name]

proc process*(name: string, comp: Component): Process =
  ## Creates a new Process.
  result = Process(name: name, component: comp, status: INITIALIZED, options: ProcessOptions(listen: false, logLevel: LogLevel(2)))
  for p in comp.ports.values:
    result.ports[p.name] = Port(name: p.name, component: p.component, direction: p.direction, process: result)

proc `[]`*(comp: Component, name: string): Port =
  ## Retrieves a Component Port by name.
  return comp.ports[name]

proc `[]`*(process: Process, name: string): Port =
  ## Retrieves a Process Port by name.
  return process.ports[name]

proc enqueue*(c: Connection, packet: Packet) =
  QUEUES[c.id].enqueue packet

proc dequeue*(c: Connection): Packet =
  return QUEUES[c.id].dequeue()

proc `->`*(outport: Port, inport: Port): Connection =
  ## Creates a new Connection.
  discard outport.requireOutPort().requireUnattachedPort()
  discard inport.requireInPort().requireUnattachedPort()
  result = Connection(size: CONNECTION_QUEUE_SIZE, source: outport, target: inport, id: $genOid())
  QUEUES[result.id] = initQueue[Packet](CONNECTION_QUEUE_SIZE)
  inport.connection = result
  outport.connection = result

proc `->`*(pkt: Packet, inport: Port): Connection =
  discard inport.requireInPort().requireUnattachedPort()
  result = Connection(size: CONNECTION_QUEUE_SIZE, packet: pkt, target: inport, id: $genOid())
  QUEUES[result.id] = initQueue[Packet](CONNECTION_QUEUE_SIZE)
  result.enqueue(pkt)
  inport.connection = result

proc `->`*(contents: JsonNode, inport: Port): Connection =
  return (@contents -> inport)

proc add*(graph: var Graph, connection: Connection) =
  ## Adds a Connection to an existing Graph.
  graph.connections.add connection

proc add*(graph: var Graph, process: Process) =
  ## Adds a Process to an existing Graph.
  graph.processes[process.name] = process

proc graph*(): Graph =
  ## Creates a new Graph.
  return Graph(connections: newSeq[Connection](0))

proc network*(graph: Graph): Network=
  ## Creates a new Network.
  result = Network(graph: graph)

proc ready(p: Process): bool {.discardable.}=
  return p.component.readyProc(p)

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

proc claimPacket(p: Process, pkt: Packet): bool =
  if pkt.owner.isNil:
    pkt.owner = p
    return true
  else:
    return false

iterator packets(p: Port): Packet =
  discard p.requireInPort().requireAttachedPort()
  for pkt in QUEUES[p.connection.id].items:
    yield pkt

proc claim*(p: Process, port: string, receivable: proc(pkt: Packet): bool = anyPacket): bool =
  if p.lock(port):
    for pkt in p[port].packets:
      if pkt.receivable:
        if p.claimPacket(pkt):
          return p.unlock(port)
  return false

proc send*(outport: Port, packet: Packet) =
  discard outport.requireOutPort().requireAttachedPort()
  outport.connection.enqueue(packet)

proc send*(outport: Port, contents: JsonNode) =
  outport.send(@contents)

proc receive*(inport: Port): Packet {.discardable.}= 
  discard inport.requireInPort().requireAttachedPort()
  return inport.connection.dequeue()

proc initOpts(p:Process) =
  if p.options.listen:
    return
  if p[P_OPT].isAttached:
    if p.claim(P_OPT):
      var opts = p[P_OPT].receive().contents
      for o in opts.pairs:
        case o.key:
          of "listen":
            p.options.listen = o.val.getBVal
          of "logLevel":
            p.options.logLevel = LogLevel(o.val.getNum)
          else:
            discard

proc component*(name: string): Component =
  ## Creates a new Component.
  result = Component(name: name, initProcs: newSeq[proc(p: Process)](0))
  result.inport(P_IN)
  result.inport(P_OPT)
  result.outport(P_OUT)
  result.outport(P_ERR)
  result.init(initOpts)

template namespace*(name: string, stmt: stmt) =
  NS = name
  stmt

proc define*(name: string): Component {.discardable.} =
  var fullname = NS & "." & name
  result = component(fullname)
  COMPONENTS[fullname] = result

proc run(p: Process) =
  for pr in p.component.initProcs:
    pr(p)
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
        if not p.options.listen:
          p.status = STOPPED
      else:
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
    .ready do (p: Process) -> bool:
      return p.claim(P_IN)
    .execute do (p: Process):
      echo p[P_IN].receive()

  var p = component("Provider")
    .ready do (p: Process) -> bool:
      return p[P_OUT].available()
    .execute do (p: Process):
      p[P_OUT].send(%(cpuTime()))
  
  var cons = process("CONS", c) 
  var prov = process("PROV", p)

  var g = graph()
  g.add(cons)
  g.add(prov)
  g.add(prov[P_OUT] -> cons[P_IN])
  #g.add(%"TEST" -> cons[P_WAIT])

  echo g

  network(g).start()

