# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

proc stats*(creeps: seq[Creep]): Stats =
  result = new Stats
  for creep in creeps:
    let cm = creep.memory.CreepMemory
    if cm.role == Worker:
      result.workers.add creep
      if cm.action == Charge:
        result.charging.add creep
      elif cm.action == Build:
        result.building.add creep
      elif cm.action == Upgrade:
        result.upgrading.add creep
      elif cm.action == Repair:
        result.repairing.add creep
      elif cm.action == Idle:
        result.idle.add creep
      else:
        result.error.add creep
      if cm.refilling:
        result.refilling.add creep

    elif cm.role == Defender:
      result.defenders.add creep

    elif cm.role == Pirate:
      result.pirates.add creep

    elif cm.role == Claimer:
      result.claimers.add creep

    elif cm.role == Harvester:
      result.harvesters.add creep

    elif cm.role == Hauler:
      result.haulers.add creep

    elif cm.role == Uplinker:
      result.uplinkers.add creep

proc actionToSeq*(stats: Stats, action: Actions): seq[Creep] =
  if action == Idle:
    result = stats.idle
  elif action == Charge:
    result = stats.charging
  elif action == Repair:
    result = stats.repairing
  elif action == Build:
    result = stats.building
  elif action == Upgrade:
    result = stats.upgrading
  else:
    logS "unsuported change action " & $action, error
    return

proc short*(action: Actions): cstring =
  if action == Idle:
    result = "I"
  elif action == Charge:
    result = "C"
  elif action == Repair:
    result = "R"
  elif action == Build:
    result = "B"
  elif action == Upgrade:
    result = "U"
  else:
    logS "unsuported change action " & $action, error
    return

proc `$$`*(role: Roles): cstring =
  if role == Worker: "worker".cstring
  elif role == Defender: "defender".cstring
  elif role == Pirate: "pirate".cstring
  elif role == Claimer: "claimer".cstring
  else: "unknown".cstring

proc changeAction*(stats: Stats, srcAction: Actions, dstAction: Actions) =
  var
    src = actionToSeq(stats, srcAction)
    dst = actionToSeq(stats, dstAction)

  let
    srclen = src.len
    dstlen = dst.len

  for idx, creep in src:
    var m = creep.memory.CreepMemory
    m.action = dstAction
    m.targetId = nil.ObjId # no target (yet)
    dst.add creep
    src.del idx
    break

  if srclen - 1 != src.len:
    logS "CA error src " & src.len & " " & srclen
  if dstlen + 1 != dst.len:
    logS "CA error dst " & dst.len & " " & dstlen


proc changeActionToClosest*(stats: Stats, srcAction: Actions, dstAction: Actions, targets: seq[auto]) =
  var
    src = actionToSeq(stats, srcAction)
    dst = actionToSeq(stats, dstAction)

  let
    srclen = src.len
    dstlen = dst.len

  for idx, creep in src:
    var closest = creep.pos.findClosestByPath(targets)
    if closest != nil:
      var m = creep.memory.CreepMemory
      m.action = dstAction
      dst.add creep
      src.del idx
      if m.targetId != closest.id:
        creep.say dstAction.short & closest.pos.at
        m.targetId = closest.id
      break

  if srclen - 1 != src.len:
    logS "CC error src " & src.len & " " & srclen
  if dstlen + 1 != dst.len:
    logS "CC error dst " & dst.len & " " & dstlen


proc log*(stats: Stats, globalPirates: seq[Creep], globalClaimers: seq[Creep]) =
  logS "workers: " & stats.workers.len & " " &
    "defenders: " & stats.defenders.len & " " &
    "pirates: " & stats.pirates.len & " (" & globalPirates.len & ") " &
    "charging: " & stats.charging.len & " " &
    "building: " & stats.building.len & " " &
    "upgrading: " & stats.upgrading.len & " " &
    "repairing: " & stats.repairing.len & " " &
    "idle: " & stats.idle.len & " " &
    "refilling: " & stats.refilling.len & " " &
    "claiming: " & globalClaimers.len & " " &
    "harvesting: " & stats.harvesters.len & " " &
    "uplinking: " & stats.uplinkers.len & " " &
    "hauling: " & stats.haulers.len & " " &
    "error: " & stats.error.len, debug
