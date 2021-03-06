import 
  json,
  critbits,
  queues

type
  PortDirection* = enum IN, OUT
  ProcessStatus* = enum
    INITIALIZED,
    READY,
    ACTIVE,
    IDLE,
    STOPPED
  LogLevel* = enum
    lvDebug
    lvInfo
    lvWarn
    lvError
    lvNone
  Logger* = object
    level*: LogLevel
  ProcessOptions* = object
    listen*: bool
    logLevel*: LogLevel
  FloOptions* = object
    logLevel*: LogLevel
    command*: string
    arguments*: seq[string]
  Packet* = ref object
    contents*: JsonNode
    owner*: Process 
  Port* = ref object 
    name*: string
    component*: Component
    direction*: PortDirection
    process*: Process
    connection*: Connection
    lock*: Process
  Component* = ref object
    name*: string
    ports*: CritBitTree[Port]
    readyProc*: proc(p: Process): bool
    initProcs*: seq[proc(p: Process)]
    executeProc*: proc(p: Process)
  Process* = ref object
    name*: string
    component*: Component
    ports*: CritBitTree[Port]
    status*: ProcessStatus
    options*: ProcessOptions
    idleSince*: float
  Connection* = ref object
    id*: string
    size*: int
    packet*: Packet
    source*: Port 
    target*: Port
  Graph* = ref object
    processes*: CritBitTree[Process]
    connections*: seq[Connection]
  Network* = ref object
    graph*: Graph
  PortAlreadyAttachedError* = object of Exception
  PortNotAttachedError* = object of Exception
  InvalidPortError* = object of Exception
  NotImplementedError* = object of Exception
  NoConnectionsError* = object of Exception
  NoProcessesError* = object of Exception
  InvalidDataError* = object of Exception

var
  CONNECTION_QUEUE_SIZE* = 8
  PROCESS_TIMEOUT* = 1000 
  TICK* = 0
  QUEUES*: CritBitTree[Queue[Packet]]
  COMPONENTS*: CritBitTree[Component]
  NS* = "flo"
  LOG*: Logger
  OPTIONS* = FloOptions(logLevel: lvWarn, arguments: newSeq[string](0))

LOG.level = lvWarn

const
  P_IN* = "IN"
  P_OUT* = "OUT"
  P_ERR* = "ERR"
  P_OPT* = "OPT"
  P_LOG* = "LOG"

let
  anyPacket* = proc(pkt: Packet): bool =
    return true

