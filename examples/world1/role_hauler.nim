# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleHauler*(creep: Creep) =
  let cm = creep.cmem

  # initial setup for the creep target and source
  if cm.targetId == nil:
    let targets = creep.room.findMy(StructureStorage) do(structure: Structure) -> bool:
      structure.structureType == STRUCTURE_TYPE_STORAGE

    if targets.len > 0:
      cm.targetId = targets[0].id

  if cm.sourceId == nil:
    let source = creep.pos.findClosestByPath(StructureContainer) do(structure: Structure) -> bool:
      if structure.structureType != STRUCTURE_TYPE_CONTAINER:
        return false
      for others in creep.rmem.creepStats.haulers:
        if others == nil: continue # skipping spawns first tick
        if others == creep: continue
        let om = others.cmem
        # handled by other hauler already
        if om.sourceId == structure.id:
          return false
      true

    if source != nil:
      cm.sourceId = source.id

  if cm.targetId != nil and cm.sourceId != nil:
    if creep.carry.energy == 0:
      let container = game.getObjectById(cm.sourceId, StructureContainer)
      let ret = creep.withdraw(container, RESOURCE_TYPE_ENERGY)
      if ret == ERR_NOT_IN_RANGE:
        creep.moveTo(container)
      elif ret == ERR_NOT_ENOUGH_ENERGY:
        creep.say "Wait?"
      elif ret != OK and ret != ERR_BUSY:
        log creep.name & " is lost: " & ret

    # should work (move) in same tick
    if creep.carry.energy > 0:
      let storage = game.getObjectById(cm.targetId, StructureStorage)
      let ret = creep.transfer(storage, RESOURCE_TYPE_ENERGY)
      if ret == ERR_NOT_IN_RANGE:
        creep.moveTo(storage)
      elif ret != OK and ret != ERR_BUSY:
        log creep.name & " is lost: " & ret
