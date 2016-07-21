# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleUplinker*(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert

  let controller = creep.room.controller
  if controller == nil:
    logS "No controller?", error
    return

  # initial setup for the creep target and source
  if cm.sourceId == nil:
    # maybe better keep a list of "destination" links
    let source = controller.pos.findClosestByRange(StructureLink) do(structure: Structure) -> bool:
      structure.structureType == STRUCTURE_TYPE_LINK

    if source != nil:
      cm.sourceId = source.id

  if cm.sourceId != nil:
    if creep.carry.energy == 0:
      let link = game.getObjectById(cm.sourceId, StructureLink)
      let ret = creep.withdraw(link, RESOURCE_TYPE_ENERGY)
      if ret == ERR_NOT_IN_RANGE:
        creep.moveTo(link)
      elif ret == ERR_NOT_ENOUGH_ENERGY:
        creep.say "Wait?"
      elif ret != OK:
        logS creep.name & "is lost:" & ret
    # should work in same tick
    if creep.carry.energy > 0:
      discard creep.upgradeController(creep.room.controller)
