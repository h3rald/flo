import 
  strutils,
  times

import
  types

proc currentTime*(plain = false): string =
  if plain:
    return getTime().getGMTime().format("yyyy-MM-dd' @ 'hh:mm:ss")
  else:
    return getTime().getGMTime().format("yyyy-MM-dd'T'hh:mm:ss'Z'")

proc logString(kind: LogLevel,  message: string, params: varargs[string, `$`]): string =
  return currentTime(true) & " " & format(message, params)

proc msg(logger: Logger, kind: LogLevel, message: string, params: varargs[string, `$`]) =
  if kind >= lvWarn:
    stderr.writeLine(logString(kind, message, params))
  else:
    echo logString(kind, message, params)

proc error*(logger: Logger, message: string, params: varargs[string, `$`]) = 
  if logger.level <= lvError:
    logger.msg(lvError, "  ERROR: " & message, params)

proc warn*(logger: Logger, message: string, params: varargs[string, `$`]) = 
  if logger.level <= lvWarn:
    logger.msg(lvWarn, "WARNING: " & message, params)

proc info*(logger: Logger, message: string, params: varargs[string, `$`]) = 
  if logger.level <= lvInfo:
    logger.msg(lvInfo, "   INFO: " & message, params)

proc debug*(logger: Logger, message: string, params: varargs[string, `$`]) = 
  if logger.level <= lvDebug:
    logger.msg(lvDebug, "  DEBUG: " & message, params)
