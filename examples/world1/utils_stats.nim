# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

type
  Stats* = ref object
    workers*: int
    fighters*: int
    pirates*: int
    charging*: int
    building*: int
    upgrading*: int
    repairing*: int
    idle*: int
    refilling*: int
    error*: int

proc stats*(creeps: seq[Creep]): Stats =
  result = new Stats
  for creep in creeps:
    let cm = creep.memory.CreepMemory
    if cm.role == Worker:
      inc result.workers
      if cm.action == Charge:
        inc result.charging
      elif cm.action == Build:
        inc result.building
      elif cm.action == Upgrade:
        inc result.upgrading
      elif cm.action == Repair:
        inc result.repairing
      elif cm.action == Idle:
        inc result.idle
      else:
        inc result.error
      if cm.refilling:
        inc result.refilling

    elif cm.role == Fighter:
      inc result.fighters

    elif cm.role == Pirate:
      inc result.pirates
