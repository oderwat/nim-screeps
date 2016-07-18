# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleHarvester*(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert
  if creep.carry.energy == 0 and not cm.refilling:
    cm.refilling = true

  if cm.refilling == true:

    if cm.sourceId == nil:
      let sources = creep.room.find(Source)
      for source in sources:
        let harvesters = creep.room.memory.RoomMemory.stats.harvesters
        var freeSource = true
        for harvester in harvesters:
          if source.id == harvester.memory.CreepMemory.sourceId:
            freeSource = false
        if freeSource:
          cm.sourceId = source.id

    if creep.carry.energy < creep.carryCapacity:
        let source = game.getObjectById(cm.sourceId, Source)
        let ret = creep.harvest(source)
        if ret == ERR_NOT_IN_RANGE:
          logS "Harvester " & creep.name & " moves to source", debug
          creep.moveTo(source)
        elif ret == ERR_NOT_ENOUGH_ENERGY:
          creep.say "Empty?"
        elif ret != OK and ret != ERR_BUSY:
          creep.say "#?%!"
          log creep.name, "is lost:", ret

    else:
      #echo creep.name, " is now full"
      #creep.say "Full"
      cm.refilling = false
  else:
    # harvesters always fill the nearest container (noting else)
    if cm.targetId == nil:
      var target = creep.pos.findClosestByPath(Structure) do(structure: Structure) -> bool:
        structure.structureType == STRUCTURE_TYPE_CONTAINER or
          structure.structureType == STRUCTURE_TYPE_LINK

      if target != nil:
        cm.targetId = target.id
        var rm = target.room.memory.RoomMemory
        # we automatically store what are source containers and links
        if target.structureType == STRUCTURE_TYPE_CONTAINER:
          rm.sourceContainers.add target.id
        elif target.structureType == STRUCTURE_TYPE_LINK:
          rm.sourceLinks.add target.id
      else:
        logS "No container in reach?", error

    if cm.targetId != nil:
      let target = game.getObjectById(cm.targetId, EnergizedStructure)
      if target != nil:
        var ret = creep.transfer(target, RESOURCE_TYPE_ENERGY)
        if ret == ERR_NOT_FOUND:
          logS "Container gone?", error
          cm.targetId = nil.ObjId
        elif ret == ERR_NOT_IN_RANGE:
          logS "Harvester moves "  & creep.name & " to target", debug
          creep.moveTo(target)
        elif ret == ERR_FULL:
          logS "Container full!", error
        elif ret != OK:
          logS "Container problem: " & ret, error
