import
  os,
  json
import
  types,
  core, 
  dsl

namespace "sys":

  define("writer")
    .inport(P_IN)
    .ready do (p: Process) -> bool:
      return p.claim(P_IN)
    .execute do (p: Process):
      if p[P_OUT].isAttached:
        # TODO write to file
        discard
      else:
        # TODO handle different types 
        echo p[P_IN].receive().contents.getStr
  
  define("reader")
    .inport(P_IN)
    .ready do (p: Process) -> bool:
      return p.options.listen
    .execute do (p: Process):
      var s: string
      if p[P_IN].isAttached:
        # TODO read from file
        discard
      else:
        s = stdin.readline
      if p[P_OUT].isAttached:
        p[P_OUT].send(%s)

namespace "os":

  copyNimProc(fileExists,   true,   "IN",   JString)
  copyNimProc(dirExists,    true,   "IN",   JString) 
  copyNimProc(copyFile,     false,  "SRC",  JString, "DEST",  JString)
  copyNimProc(moveFile,     false,  "SRC",  JString, "DEST",  JString)
  copyNimProc(removeFile,   false,  "IN",   JString)
  copyNimProc(execShellCmd, true,   "IN",   JString)
  copyNimProc(getEnv,       true,   "IN",   JString)
  copyNimProc(existsEnv,    true,   "IN",   JString)
  copyNimProc(putEnv,       false,  "KEY",  JString, "VALUE", JString)
  copyNimProc(removeDir,    false,  "IN",   JString)
  copyNimProc(createDir,    false,  "IN",   JString)
  copyNimProc(copyDir,      false,  "SRC",  JString, "DEST",  JString)

when isMainModule:
  var data = """
{
  "processes": {
    "W1": {
      "component": "sys.writer"  
    },
    "R1": {
      "component": "sys.reader"  
    }
  },  
  "connections": [
    {
      "src": {
        "process": "R1",
        "port": "OUT"
      },
      "tgt": {
        "process": "W1",
        "port": "IN"
      }
    },
    {
      "data": {"listen": true},
      "tgt": {
        "process": "R1",
        "port": "OPT"
      }
    },
    {
      "data": {"listen": true},
      "tgt": {
        "process": "W1",
        "port": "OPT"
      }
    }
  ]
}

  """
  var g = data.toGraph 
  echo g
  g.network.start()

  
  

