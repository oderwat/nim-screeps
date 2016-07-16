# Copyright 2016.

# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleHealer*(creep: Creep) =
  #var cm = creep.memory.CreepMemory
  #var friendly = creep.room.findMy(CREEP)
  #creep.moveTo(game.flags.?Flag1)

  let target = creep.pos.findMyClosestByRange(Creep) do(creep: Creep) -> bool:
    creep.hits < creep.hitsMax

  if target != nil:
    creep.moveTo target
    if creep.pos.isNearTo target:
        creep.heal target
    else:
        creep.rangedHeal target
  else:
    let target = creep.pos.findMyClosestByRange(Creep) do(creep: Creep) -> bool:
      let cm = creep.memory.CreepMemory
      cm.role == Pirate
