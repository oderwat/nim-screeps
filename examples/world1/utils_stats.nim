# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

type
  Stats* = ref object
    workers*: seq[Creep]
    fighters*: seq[Creep]
    pirates*: seq[Creep]
    charging*: seq[Creep]
    building*: seq[Creep]
    upgrading*: seq[Creep]
    repairing*: seq[Creep]
    idle*: seq[Creep]
    refilling*: seq[Creep]
    error*: seq[Creep]

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

    elif cm.role == Fighter:
      result.fighters.add creep

    elif cm.role == Pirate:
      result.pirates.add creep

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

proc changeAction*(stats: Stats, srcAction: Actions, dstAction: Actions) =
  var
    src = actionToSeq(stats, srcAction)
    dst = actionToSeq(stats, srcAction)

  for idx, creep in src:
    var m = creep.memory.CreepMemory
    m.action = dstAction
    m.targetId = nil # no target (yet)
    dst.add creep
    src.del idx
    break

proc changeActionToClosest*(stats: Stats, srcAction: Actions, dstAction: Actions, targets: seq[auto]) =
  var
    src = actionToSeq(stats, srcAction)
    dst = actionToSeq(stats, srcAction)

  for idx, creep in src:
    var m = creep.memory.CreepMemory
    m.action = dstAction
    dst.add creep
    src.del idx
    var closest = creep.pos.findClosestByPath(targets)
    m.targetId = closest.id
    break

proc log*(stats: Stats) =
  logS "workers: " & stats.workers.len & " / " &
    "fighters: " & stats.fighters.len & " / " &
    "pirates: " & stats.pirates.len & " / " &
    "charging: " & stats.charging.len & " / " &
    "building: " & stats.building.len & " / " &
    "upgrading: " & stats.upgrading.len & " / " &
    "repairing: " & stats.repairing.len & " / " &
    "idle: " & stats.idle.len & " / " &
    "refilling: " & stats.refilling.len & " / " &
    "error: " & stats.error.len, debug
