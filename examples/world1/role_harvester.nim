# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

proc roleHarvester*(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert

  # setup
  if cm.sourceId == nil:
    let sources = creep.room.find(Source)
    var ourSource: Source
    for source in sources:
      # check if that source has a container or link nearby
      let near = source.pos.findClosestByPath(Structure) do(structure: Structure) -> bool:
        structure.structureType == STRUCTURE_TYPE_CONTAINER or
          structure.structureType == STRUCTURE_TYPE_LINK
      if not source.pos.isNearTo(near): continue # no? check the next source

      let harvesters = creep.room.memory.RoomMemory.stats.harvesters
      var freeSource = true
      for harvester in harvesters:
        if source.id == harvester.memory.CreepMemory.sourceId:
          freeSource = false
      if freeSource:
        cm.sourceId = source.id
        ourSource = source
        break

    if ourSource == nil:
      logS creep.name & " could not find a source in " & creep.room.name, error
      return

    # harvesters always fill the nearest container / link to the source
    if cm.targetId == nil:
      var target = ourSource.pos.findClosestByPath(Structure) do(structure: Structure) -> bool:
        structure.structureType == STRUCTURE_TYPE_CONTAINER or
          structure.structureType == STRUCTURE_TYPE_LINK

      if target != nil:
        cm.targetId = target.id
        var rm = target.room.memory.RoomMemory
        # we automatically store what are source containers and links
        if target.structureType == STRUCTURE_TYPE_CONTAINER:
          rm.sourceContainers.uniqueAdd target.id

        elif target.structureType == STRUCTURE_TYPE_LINK:
          rm.sourceLinks.uniqueAdd target.id
      else:
        logS creep.name & ": No container in reach?", error

  let target = game.getObjectById(cm.targetId, EnergizedStructure)
  if target == nil:
    # recalibrate?
    logS "Recalibrate?", error
    cm.sourceId = nil.ObjId
    cm.targetId = nil.ObjId
    return

  if creep.carry.energy < creep.carryCapacity:
      let source = game.getObjectById(cm.sourceId, Source)
      let ret = creep.harvest(source)
      if ret == ERR_NOT_IN_RANGE:
        if target.structureType == STRUCTURE_TYPE_CONTAINER:
          logS "Harvester " & creep.name & " moves onto container", debug
        else:
          logS "Harvester " & creep.name & " moves to source", debug
        creep.moveTo(source)
      elif ret == ERR_NOT_ENOUGH_ENERGY:
        creep.say "Empty?"
      elif ret != OK and ret != ERR_BUSY:
        creep.say "#?%!"
        log creep.name, "is lost:", ret

  if creep.carry.energy > 0:
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
