import 
  strutils,
  json,
  critbits,
  queues,
  oids

type
  PortDirection* = enum IN, OUT
  ProcessStatus* = enum
    INITIALIZED,
    WAITING,
    READY,
    ACTIVE,
    IDLE,
    STOPPED
  Packet* = ref object
    contents*: JsonNode
    owner*: Process
  Command* = proc(p: Process): bool
  Port* = ref object 
    name: string
    component: Component
    direction: PortDirection
    process*: Process
    connection*: Connection
    lock*: Process
  Component* = ref object
    name*: string
    ports: CritBitTree[Port]
    ready*: Command
    execute*: Command
  Process* = ref object
    name*: string
    component*: Component
    ports: CritBitTree[Port]
    status*: ProcessStatus
  Connection* = ref object
    id*: string
    size*: int
    source*: Port
    target*: Port
  Graph* = ref object
    processes*: CritBitTree[Process]
    connections*: seq[Connection]
  Network* = ref object
    graph*: Graph
  PortAlreadyAttachedError = object of Exception
  PortNotAttachedError = object of Exception
  InvalidPortError = object of Exception
  NotImplementedError* = object of Exception

var
  CONNECTION_QUEUE_SIZE* = 2
  QUEUES*: CritBitTree[Queue[Packet]]

const
  P_IN* = "IN"
  P_OUT* = "OUT"
  P_ERR* = "ERR"
let
  anyPacket* = proc(pkt: Packet): bool =
    return true

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
  return "$1: $2 $3 -> $4 $5" % [$conn.id, $conn.source.process, $conn.source.name, $conn.target.name, $conn.target.process]

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

proc inport*(comp: var Component, name: string) =
  ## Adds a new InPort to an existing Component.
  comp.ports[name] = Port(name: name, component: comp, direction: IN)

proc outport*(comp: var Component, name: string) =
  ## Adds a new OutPort to an existing Component.
  comp.ports[name] = Port(name: name, component: comp, direction: OUT)

proc component*(name: string): Component =
  ## Creates a new Component.
  return Component(name: name)

proc process*(name: string, comp: Component): Process =
  ## Creates a new Process.
  result = Process(name: name, component: comp, status: INITIALIZED)
  for p in comp.ports.values:
    result.ports[p.name] = Port(name: p.name, component: p.component, direction: p.direction, process: result)

proc `[]`*(comp: Component, name: string): Port =
  ## Retrieves a Component Port by name.
  return comp.ports[name]

proc `[]`*(process: Process, name: string): Port =
  ## Retrieves a Process Port by name.
  return process.ports[name]

proc `->`*(outport: Port, inport: Port): Connection =
  ## Creates a new Connection.
  discard outport.requireOutPort().requireUnattachedPort()
  discard inport.requireInPort().requireUnattachedPort()
  result = Connection(size: CONNECTION_QUEUE_SIZE, source: outport, target: inport, id: $genOid())
  QUEUES[result.id] = initQueue[Packet](CONNECTION_QUEUE_SIZE)
  inport.connection = result
  outport.connection = result

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
  return Network(graph: graph)

when isMainModule:
  var c1 = component "Component1"
  var c2 = component "Component2"
  c1.inport("IN-1")
  c1.inport("IN-2")
  c1.outport("OUT-1")
  c1.outport("OUT-2")
  c2.inport("II-1")
  c2.inport("II-2")
  c2.outport("OO-1")
  c2.outport("OO-2")
  var p1 = process("P1", c1)
  var p2 = process("P2", c2)
  var g = graph()
  g.add p1
  g.add p2
  g.add(p1["OUT-2"] -> p2["II-1"])
  g.add(p1["OUT-1"] -> p2["II-2"])
  echo g

