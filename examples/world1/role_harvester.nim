# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types
import math

proc roleHarvester*(creep: Creep) =
  let cm = creep.cmem

  # setup
  if cm.sourceId == nil:
    let sources = creep.room.find(Source)
    var ourSource: Source
    for source in sources:
      # check if that source has a container or link nearby
      let near = source.pos.findClosestByPath(Structure) do(structure: Structure) -> bool:
        structure.structureType == STRUCTURE_TYPE_CONTAINER or
          structure.structureType == STRUCTURE_TYPE_LINK
      if near != nil and not source.pos.inRangeTo(near,2): continue # no? check the next source

      let harvesters = creep.rmem.creepStats.harvesters
      var freeSource = true
      for harvester in harvesters:
        if harvester == nil: continue
        if source.id == harvester.cmem.sourceId:
          freeSource = false
      if freeSource:
        cm.sourceId = source.id
        ourSource = source
        break

    if ourSource == nil:
      # check for a construction site near of the source. if we have one, build it
      # this is pretty unoptimized but better than doing nothing at all
      let sources = creep.room.find(Source)
      for source in sources:
        let near = source.pos.findClosestByPath(ConstructionSite) do(site: ConstructionSite) -> bool:
          site.structureType == STRUCTURE_TYPE_CONTAINER
        if near != nil and not source.pos.inRangeTo(near,2): continue # no? check the next source

        if creep.carryCapacity == 0:
          log "harvester without carry but not container", error
          return

        log "Harvester " & creep.name & " builds its own container"
        if creep.carry.energy == 0:
          cm.refilling = true
        if creep.carry.energy == creep.carryCapacity:
          cm.refilling = false;

        if not cm.refilling:
          # we move there and build
          let ret = creep.build(near)
          if ret == ERR_NOT_IN_RANGE:
            creep.moveTo(near)
          return
        else:
          let ret = creep.harvest(source)
          if ret == ERR_NOT_IN_RANGE:
            log "Harvester " & creep.name & " moves to source", debug
            creep.moveTo(source)
          return

      log creep.name & " could not find a source with container in " & creep.room.name, error
      return

    # harvesters always fill the nearest container / link to the source
    if cm.targetId == nil:
      var target = ourSource.pos.findClosestByPath(Structure) do(structure: Structure) -> bool:
        structure.structureType == STRUCTURE_TYPE_CONTAINER or
          structure.structureType == STRUCTURE_TYPE_LINK

      if target != nil:
        cm.targetId = target.id
        var rm = target.room.rmem
        # we automatically store what are source containers and links
        if target.structureType == STRUCTURE_TYPE_CONTAINER:
          rm.sourceContainers.uniqueAdd target.id

        elif target.structureType == STRUCTURE_TYPE_LINK:
          rm.sourceLinks.uniqueAdd target.id
      else:
        log creep.name & ": No container in reach? Roaming a bit!", error
        let source = game.getObjectById(cm.sourceId, Source)
        # we dance around the source so a build gets through to a construction site
        creep.moveTo(source.pos.x + (game.time mod 5) - 2, source.pos.y + (game.time mod 5) - 2)

  let target = game.getObjectById(cm.targetId, EnergizedStructure)
  if target == nil:
    # recalibrate?
    log "Recalibrate?", error
    cm.sourceId = nil.ObjId
    cm.targetId = nil.ObjId
    return

  # Move to the source (or on top of the container)
  if creep.carry.energy < creep.carryCapacity or creep.carryCapacity == 0:
      # if your target is a container we want to sit on it!
      if target.structureType == STRUCTURE_TYPE_CONTAINER and
        not creep.pos.isEqualTo(target.pos):
        log "Harvester " & creep.name & " moves onto container", debug
        creep.moveTo(target)
      else:
        let source = game.getObjectById(cm.sourceId, Source)
        let ret = creep.harvest(source)
        if ret == ERR_NOT_IN_RANGE:
          log "Harvester " & creep.name & " moves to source", debug
          creep.moveTo(source)
        elif ret == ERR_NOT_ENOUGH_ENERGY:
          creep.say "Empty?"
        elif ret != OK and ret != ERR_BUSY:
          creep.say "#?%!"
          log creep.name & " is lost: " & ret

  if creep.carry.energy > 0:
    var ret = creep.transfer(target, RESOURCE_TYPE_ENERGY)
    if ret == ERR_NOT_FOUND:
      log "Container gone?", error
      cm.targetId = nil.ObjId
    elif ret == ERR_NOT_IN_RANGE:
      log "Harvester moves "  & creep.name & " to target", debug
      creep.moveTo(target)
    elif ret == ERR_FULL:
      log "Container in Room " & target.room.name & " is full!", error
    elif ret != OK:
      log "Container problem: " & ret, error
