# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

proc add*(stats: CreepStats, cm: CreepMemory, creep: Creep) =
  case cm.role:
  of Worker:
    stats.workers.add creep
    case cm.action:
    of Charge: stats.charging.add creep
    of Build: stats.building.add creep
    of Upgrade: stats.upgrading.add creep
    of Repair: stats.repairing.add creep
    of Migrate: stats.migrating.add creep
    of Idle: stats.idle.add creep
    if cm.refilling: stats.refilling.add creep
  of Defender:stats.defenders.add creep
  of Pirate:stats.pirates.add creep
  of Claimer:stats.claimers.add creep
  of Harvester:stats.harvesters.add creep
  of Hauler:stats.haulers.add creep
  of Uplinker:stats.uplinkers.add creep
  of Healer: discard
  of Tank: discard

proc stats*(creeps: seq[Creep] | JSAssoc[cstring, Creep]): CreepStats =
  result = new CreepStats
  for creep in creeps:
    result.add creep.cmem, creep

proc actionToSeq*(stats: CreepStats, action: Actions): seq[Creep] =
  case action:
    of Idle: return stats.idle
    of Charge: return stats.charging
    of Repair: return stats.repairing
    of Build: return stats.building
    of Upgrade: return stats.upgrading
    of Migrate: return stats.migrating

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
    log "unsuported change action " & $action, error
    return

proc `$$`*(role: Roles): cstring =
  if role == Worker: "worker".cstring
  elif role == Defender: "defender".cstring
  elif role == Pirate: "pirate".cstring
  elif role == Claimer: "claimer".cstring
  else: "unknown".cstring

proc changeAction*(stats: CreepStats, srcAction: Actions, dstAction: Actions) =
  var
    src = actionToSeq(stats, srcAction)
    dst = actionToSeq(stats, dstAction)

  let
    srclen = src.len
    dstlen = dst.len

  for idx, creep in src:
    if creep == nil: continue # new spawns
    let cm = creep.cmem
    cm.action = dstAction
    cm.targetId = nil.ObjId # no target (yet)
    dst.add creep
    src.del idx
    break

  if srclen - 1 != src.len:
    log "CA error src " & src.len & " " & srclen
  if dstlen + 1 != dst.len:
    log "CA error dst " & dst.len & " " & dstlen


proc changeActionToClosest*(stats: CreepStats, srcAction: Actions, dstAction: Actions, targets: seq[auto]) =
  var
    src = actionToSeq(stats, srcAction)
    dst = actionToSeq(stats, dstAction)

  let
    srclen = src.len
    dstlen = dst.len

  for idx, creep in src:
    if creep == nil: continue # new spawns
    var closest = creep.pos.findClosestByPath(targets)
    if closest != nil:
      let cm = creep.cmem
      cm.action = dstAction
      dst.add creep
      src.del idx
      if cm.targetId != closest.id:
        creep.say dstAction.short & closest.pos.at
        cm.targetId = closest.id
      break

  if srclen - 1 != src.len:
    log "CC error src " & src.len & " " & srclen & " " & $srcAction
  if dstlen + 1 != dst.len:
    log "CC error dst " & dst.len & " " & dstlen & " " & $dstAction


proc logInfo*(stats: CreepStats) =
  let gstats = memory.GameMemory.creepStats
  log "wrk: " & stats.workers.len & " " &
    "def: " & stats.defenders.len & " " &
    "pir: " & stats.pirates.len & " (" & gstats.pirates.len & ") " &
    "chg: " & stats.charging.len & " " &
    "bld: " & stats.building.len & " " &
    "upg: " & stats.upgrading.len & " " &
    "rep: " & stats.repairing.len & " " &
    "idl: " & stats.idle.len & " " &
    "ref: " & stats.refilling.len & " " &
    "cla: " & stats.claimers.len & " (" & gstats.claimers.len & ") " &
    "hvs: " & stats.harvesters.len & " " &
    "upl: " & stats.uplinkers.len & " " &
    "hau: " & stats.haulers.len & " " &
    "mig: " & stats.migrating.len & " "
