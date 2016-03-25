import
  os,
  json
import
  types,
  core, 
  dsl


namespace "flo":

  define("if")
    .inport(P_IN)
    .outport("TRUE")
    .outport("FALSE")
    .ready do (p: Process) -> bool:
      return p.claim(P_IN)
    .execute do (p: Process):
      var res = false
      let pkt = p[P_IN].receive().contents
      case pkt.kind:
        of JNull:
          res = false
        of JBool:
          res = pkt.getBVal
        of JInt:
          res = pkt.getNum > 0
        of JFloat:
          res = pkt.getFNum > 0
        of JString:
          res = pkt.getStr.len > 0
        of JObject:
          res = pkt.getFields.len > 0
        of JArray:
          res = pkt.getElems.len > 0
      if res == false:
        p["FALSE"].send(pkt)
      else:
        p["TRUE"].send(pkt)

  define("split")
    .inport(P_IN)
    .outport("OUT1")
    .outport("OUT2")
    .ready do (p: Process) -> bool:
      return p.claim(P_IN)
    .execute do (p: Process):
      let pkt = p[P_IN].receive()
      p["OUT1"].send(pkt)
      p["OUT2"].send(pkt)

  define("merge")
    .inport("IN1")
    .inport("IN2")
    .outport(P_OUT)
    .ready do (p: Process) -> bool:
      return p.claim("IN1") and p.claim("IN2")
    .execute do (p: Process):
      p[P_OUT].send(p["IN1"].receive())
      p[P_OUT].send(p["IN2"].receive())



