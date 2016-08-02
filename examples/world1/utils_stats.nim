# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

proc dumpCreeps*(creeps: CreepList, label: cstring) =
  var all = ""
  for creep in creeps:
    if all != "":
      all.add ", "
    if creep == nil:
      all.add "NULL"
    else:
      all.add creep.name
  log label & ": " & all, info

proc add*(stats: CreepStats, cm: CreepMemory, creep: Creep) =
  case cm.role:
  of Worker:
    case cm.action:
    of Charge: stats.charging.add creep
    of Build: stats.building.add creep
    of Upgrade: stats.upgrading.add creep
    of Repair: stats.repairing.add creep
    of Migrate: stats.migrating.add creep
    of Idle: stats.idle.add creep
    if cm.refilling: stats.refilling.add creep
    # we don't list imigrants as workers anymore
    if cm.action != Migrate:
      stats.workers.add creep
  of Defender: stats.defenders.add creep
  of Pirate: stats.pirates.add creep
  of Claimer: stats.claimers.add creep
  of Harvester: stats.harvesters.add creep
  of Hauler: stats.haulers.add creep
  of Uplinker: stats.uplinkers.add creep
  of Healer: discard
  of Tank: discard

proc stats*(creeps: seq[Creep] | JSAssoc[cstring, Creep]): CreepStats =
  result = new CreepStats
  for creep in creeps:
    result.add creep.cmem, creep

proc actionToSeq*(stats: CreepStats, action: Actions): ptr CreepList =
  case action:
    of Idle: return stats.idle.addr
    of Charge: return stats.charging.addr
    of Repair: return stats.repairing.addr
    of Build: return stats.building.addr
    of Upgrade: return stats.upgrading.addr
    of Migrate: return stats.migrating.addr

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

proc setAction*(creep: Creep, stats: CreepStats, action: Actions) =
  let cm = creep.cmem
  var src, dst: ptr CreepList
  src = actionToSeq(stats, cm.action)
  dst = actionToSeq(stats, action)

  cm.action = action
  cm.targetId = nil.ObjId # no target (yet)

  dst[].add creep

  for idx, srcCreep in src[]:
    if creep == srcCreep:
      src[].del idx
      return

  log "setAction could not find the creep in the src", error

proc changeAllAction*(stats: CreepStats, srcAction: Actions, dstAction: Actions) =
  var src, dst: ptr CreepList
  src = actionToSeq(stats, srcAction)
  dst = actionToSeq(stats, dstAction)

  for idx, creep in src[]:
    if creep == nil: continue # new spawns
    let cm = creep.cmem
    cm.action = dstAction
    cm.targetId = nil.ObjId # no target (yet)
    dst[].add creep
    src[].del idx

proc changeAction*(stats: CreepStats, srcAction: Actions, dstAction: Actions) =
  # @araq: gives compiler error when used in one line
  var src, dst: ptr CreepList
  src = actionToSeq(stats, srcAction)
  dst = actionToSeq(stats, dstAction)

  #dumpCreeps(src[], "iSrc")
  #dumpCreeps(dst[], "iDst")

  for idx, creep in src[]:
    if creep == nil: continue # new spawns
    let cm = creep.cmem
    cm.action = dstAction
    cm.targetId = nil.ObjId # no target (yet)
    dst[].add creep
    src[].del idx
    break

  #dumpCreeps(src[], "oSrc")
  #dumpCreeps(dst[], "onDst")

proc changeActionToClosest*(stats: CreepStats, srcAction: Actions, dstAction: Actions, targets: seq[auto]) =
  var src, dst: ptr CreepList
  src = actionToSeq(stats, srcAction)
  dst = actionToSeq(stats, dstAction)

  #dumpCreeps(src[], "iSrc")
  #dumpCreeps(dst[], "iDst")

  for idx, creep in src[]:
    if creep == nil: continue # new spawns
    var closest = creep.pos.findClosestByPath(targets)
    if closest != nil:
      let cm = creep.cmem
      cm.action = dstAction
      dst[].add creep
      src[].del idx
      if cm.targetId != closest.id:
        creep.say dstAction.short & closest.pos.at
        cm.targetId = closest.id
      break

  #dumpCreeps(src[], "oSrc")
  #dumpCreeps(dst[], "onDst")

  #let room = targets[0].room
  #let creeps = room.findMy(Creep)
  #discard stats.check(creeps.stats(), "CC: " & $srcAction & " to " & $dstAction)

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

proc `check`*(a, b: CreepStats, label: cstring): bool =
  var errors = 0
  # testing if a and b have the same number (later maybe id's) of creeps
  if a.workers.len != b.workers.len:
    log "Stats (" & label & ") differ for 'workers' " & a.workers.len & " != " & b.workers.len, error
    inc errors
  if a.defenders.len != b.defenders.len:
    log "Stats (" & label & ") differ for 'defenders' " & a.defenders.len & " != " & b.defenders.len, error
    inc errors
  if a.pirates.len != b.pirates.len:
    log "Stats (" & label & ") differ for 'pirates' " & a.pirates.len & " != " & b.pirates.len, error
    inc errors
  if a.claimers.len != b.claimers.len:
    log "Stats (" & label & ") differ for 'claimers' " & a.claimers.len & " != " & b.claimers.len, error
    inc errors
  if a.harvesters.len != b.harvesters.len:
    log "Stats (" & label & ") differ for 'harvesters' " & a.harvesters.len & " != " & b.harvesters.len, error
    inc errors
  if a.uplinkers.len != b.uplinkers.len:
    log "Stats (" & label & ") differ for 'uplinkers' " & a.uplinkers.len & " != " & b.uplinkers.len, error
    inc errors
  if a.haulers.len != b.haulers.len:
    log "Stats (" & label & ") differ for 'haulers' " & a.haulers.len & " != " & b.haulers.len, error
    inc errors
  if a.charging.len != b.charging.len:
    log "Stats (" & label & ") differ for 'charging' " & a.charging.len & " != " & b.charging.len, error
    inc errors
  if a.building.len != b.building.len:
    log "Stats (" & label & ") differ for 'building' " & a.building.len & " != " & b.building.len, error
    inc errors
  if a.upgrading.len != b.upgrading.len:
    log "Stats (" & label & ") differ for 'upgrading' " & a.upgrading.len & " != " & b.upgrading.len, error
    inc errors
  if a.repairing.len != b.repairing.len:
    log "Stats (" & label & ") differ for 'repairing' " & a.repairing.len & " != " & b.repairing.len, error
    inc errors
  if a.idle.len != b.idle.len:
    log "Stats (" & label & ") differ for 'idle' " & a.idle.len & " != " & b.idle.len, error
    inc errors
  if a.refilling.len != b.refilling.len:
    log "Stats (" & label & ") differ for 'refilling' " & a.refilling.len & " != " & b.refilling.len, error
    inc errors
  if a.migrating.len != b.migrating.len:
    log "Stats (" & label & ") differ for 'migrating' " & a.migrating.len & " != " & b.migrating.len, error
    inc errors
  if a.error.len != b.error.len:
    log "Stats (" & label & ") differ for 'error' " & a.error.len & " != " & b.error.len, error
    inc errors
  errors > 0
