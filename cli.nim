import
  parseopt2,
  json,
  strutils,
  critbits,
  os

import
  types,
  core,
  logger,
  dsl,
  components


const
  program = "flo"
  version = "1.0.0"

let
  help = """$1 v$2 - A simple flow-based programming (FBP) engine - (c) 2016 Fabio Cevasco

  Usage:
    flo command <argument> [option1, option2, ...]

  Commands:
    run <file>            Runs the specified JSON Graph file.
    info <file>           Display information about the specified JSON Graph file.
    describe <component>  Display information about the specified component.

  Options:
    -h, --help            Display this message.
    -l, --log             Specify the log level: debug, info, warn, error, none (default: warn)
    -v, --version         Display the program version.""" % [program, version]

proc loadFile(file: string): Graph =
  var contents: string
  try:
    contents = file.readFile
  except:
    LOG.error("Unable to read file: $1" % [file])
    quit(10)
  try:
    result = contents.toGraph()
  except:
    LOG.error(getCurrentExceptionMsg())
    quit(11)

proc runGraph(file: string) = 
  try:
    loadFile(file).network.start()
  except:
    LOG.error(getCurrentExceptionMsg())
    quit(20)

proc infoGraph(file: string) = 
  try:
    echo $loadFile(file)
  except:
    LOG.error(getCurrentExceptionMsg())
    quit(30)

proc describeComponent(name: string) = 
  if not COMPONENTS.hasKey(name):
    LOG.error("Component '$1' not found" % [name])
    quit(40)
  let component = COMPONENTS[name]
  echo "Component: ", name
  echo "InPorts:"
  for p in component.ports.values:
    if p.direction == IN:
      echo "- ", p.name
  echo "OutPorts:"
  for p in component.ports.values:
    if p.direction == OUT:
      echo "- ", p.name

for kind, key, val in getopt():
  case kind:
    of cmdArgument:
      if OPTIONS.command.isNil:
        case key:
          of "run":
            OPTIONS.command = "run"
          of "info":
            OPTIONS.command = "info"
          of "describe":
            OPTIONS.command = "describe"
          else:
            LOG.error("Invalid command: $1" % [key]) 
            quit(1)
      else:
        case OPTIONS.command:
          of "run":
            OPTIONS.command = "run"
            OPTIONS.arguments.add key
          of "info":
            OPTIONS.command = "info"
            OPTIONS.arguments.add key
          of "describe":
            OPTIONS.command = "describe"
            OPTIONS.arguments.add key
          else:
            discard
    of cmdLongOption, cmdShortOption:
      case key:
        of "version", "v":
          echo version
          quit(0)
        of "help", "h":
          echo help
          quit(0)
        of "log", "l":
          case val:
            of "warn":
              OPTIONS.logLevel = lvWarn
            of "error":
              OPTIONS.logLevel = lvError
            of "info":
              OPTIONS.logLevel = lvInfo
            of "debug":
              OPTIONS.logLevel = lvDebug
            of "none":
              OPTIONS.logLevel = lvNone
            else:
              discard
        else:
          discard
    else:
      discard

case OPTIONS.command:
  of "run":
    if OPTIONS.arguments.len == 0:
      LOG.error("No file specified")
      quit(100)
    runGraph(OPTIONS.arguments[0])
  of "info":
    if OPTIONS.arguments.len == 0:
      LOG.error("No file specified")
      quit(101)
    infoGraph(OPTIONS.arguments[0])
  of "describe":
    if OPTIONS.arguments.len == 0:
      echo "Components:"
      for c in COMPONENTS.keys:
        echo "- ", c
    else:
      describeComponent(OPTIONS.arguments[0])
  else:
    echo help
quit(0)

