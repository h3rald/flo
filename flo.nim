import
  critbits
import
  types,
  cli

LOG.level = OPTIONS.logLevel

case OPTIONS.command:
  of "run":
    if OPTIONS.arguments.len == 0:
      stderr.writeLine("No file specified")
      quit(100)
    runGraph(OPTIONS.arguments[0])
  of "info":
    if OPTIONS.arguments.len == 0:
      stderr.writeLine("No file specified")
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
    echo HELP
quit(0)


