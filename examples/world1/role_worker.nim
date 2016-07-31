# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

proc roleWorker*(creep: Creep) =
  var cm = creep.cmem

  # so we can act on the same tick
  if creep.carry.energy == 0 and not cm.refilling:
    creep.say "Empty"
    # check if we want to continue or kill that creep
    if creep.ticksToLive < 50:
      creep.say "Oh No!"
      logH creep.name & ": Oh No! (" & creep.ticksToLive & ")"

    if creep.ticksToLive < 48:
      creep.suicide
      logH creep.name & " committed sucicide"
      return

    cm.refilling = true

  if cm.refilling == true:
    if creep.carry.energy < creep.carryCapacity:
      if cm.slurpId != nil:
        let resource = game.getObjectById(cm.slurpId, Resource)
        if resource == nil:
          cm.slurpId = nil.ObjId
          cm.refilling = false
          creep.say "Gone?"
          log creep.name & " Gone?"
        else:
          let ret = creep.pickup(resource)
          if ret == ERR_NOT_IN_RANGE:
            creep.moveTo(resource)
          elif ret == OK:
            creep.say "Slurped"
            log creep.name  & " Slurped"
            cm.slurpId = nil.ObjId
            cm.refilling = false
          elif ret != OK and ret != ERR_BUSY:
            creep.say "Cough"
            log creep.name & " Cough" & ret
            cm.slurpId = nil.ObjId
            cm.refilling = false
      else:
        type UseSource {.pure.} = enum
          nope   # not needed, have better option
          check  # not decided
          always # and nothing else
        var useSource = UseSource.check

        # specialized.. if we build a container we take energy from nearest source
        if cm.action == Build:
          var target = game.getObjectById(cm.targetId, ConstructionSite)
          if target != nil and target.structureType == STRUCTURE_TYPE_CONTAINER:
            cm.sourceId = target.pos.findClosestByPath(Source).id
            useSource = UseSource.always

        var haveStorage: StructureStorage
        var haveContainer: StructureContainer
        var haveLink: StructureLink

        if useSource == UseSource.check:
          # find a storage... if it has energy go there
          haveStorage = creep.pos.findClosestByPath(StructureStorage) do(structure: Structure) -> bool:
            structure.structureType == STRUCTURE_TYPE_STORAGE and
              structure.StructureStorage.store[RESOURCE_TYPE_ENERGY] > 0

          # find a container... if it has "enough" energy go there
          haveContainer = creep.pos.findClosestByPath(StructureContainer) do(structure: Structure) -> bool:
            structure.structureType == STRUCTURE_TYPE_CONTAINER and
              structure.StructureContainer.store[RESOURCE_TYPE_ENERGY] >= creep.carryCapacity

          # find a Link... if it has "enough" energy go there
          haveLink = creep.pos.findClosestByPath(StructureLink) do(structure: Structure) -> bool:
            structure.structureType == STRUCTURE_TYPE_LINK and
              structure.StructureLink.energy >= creep.carryCapacity

          var select: seq[Structure] = @[]
          if haveStorage != nil: select.add haveStorage.Structure
          if haveContainer != nil: select.add haveContainer.Structure
          if haveLink != nil: select.add haveLink.Structure

          # check what is the neares: storage, container or link
          let nearest = creep.pos.findClosestByPath(select)

          # we prefer container energy over harvesting ourselfs
          if nearest != nil:
            creep.say nearest.structureType
            useSource = UseSource.nope
            # this is a bold cast ... but works because of javascript
            let ret = creep.withdraw(nearest.EnergizedStructure, RESOURCE_TYPE_ENERGY)
            if ret == ERR_NOT_IN_RANGE:
              creep.moveTo(nearest)
            elif ret != OK and ret != ERR_BUSY:
              creep.say "#?%!"
              log creep.name & " is lost: " & ret

        if useSource != UseSource.nope:
          let source = game.getObjectById(cm.sourceId, Source)
          let ret = creep.harvest(source)
          if ret == ERR_NOT_IN_RANGE:
            creep.moveTo(source)
          elif ret == ERR_NOT_ENOUGH_ENERGY:
            if creep.carry.energy > 0:
              cm.refilling = false
              creep.say "Anyway"
            else:
              creep.say "Empty?"
          elif ret != OK and ret != ERR_BUSY:
            creep.say "#?%!"
            log creep.name & " is lost: " & ret

    else:
      #echo creep.name, " is now full"
      creep.say "Full"
      cm.refilling = false

  if not cm.refilling:
    #var needEnergy = energyNeeded(creep)
    # need some kind of priority list here
    case cm.action:
      of Idle:
        creep.say("Boring!")
        discard # hanging around

      of Charge:
        var target = game.getObjectById(cm.targetId, EnergizedStructure)
        if target.energy == target.energyCapacity:
          creep.say("Full?")
          cm.action = Idle
          cm.targetId = nil.ObjId
        else:
          #echo "Charging: ", target.structureType, at target.pos
          var ret = creep.transfer(target, RESOURCE_TYPE_ENERGY)
          if ret == ERR_NOT_IN_RANGE:
            creep.moveTo(target)
          elif ret == OK:
            creep.say("Better!")
            cm.action = Idle
            cm.targetId = nil.ObjId
          else:
            creep.say("? " & $ret.int)
            cm.action = Idle
            cm.targetId = nil.ObjId

      of Build:
        var target = game.getObjectById(cm.targetId, ConstructionSite)
        let ret = creep.build(target)
        if ret == OK:
          if target.progress == target.progressTotal:
            creep.say "done"
            cm.targetId = nil.ObjId
            cm.action = Idle
          #logH "building"
        elif ret == ERR_NOT_IN_RANGE:
          logH "moving to site " & target.pos.at
          creep.moveTo(target)
          creep.say ">" & target.pos.at
        else:
          if creep.moveTo(target) == ERR_INVALID_TARGET:
            cm.targetId = nil.ObjId
            cm.action = Idle
          creep.say "Site?"
          logH "building error: " & ret

      of Repair:
        var target = game.getObjectById(cm.targetId, Structure)
        if creep.repair(target) != OK:
          if creep.moveTo(target) == ERR_INVALID_TARGET:
            cm.targetId = nil.ObjId
            cm.action = Idle
        elif target.hits == target.hitsMax:
          cm.targetId = nil.ObjId
          cm.action = Idle

      of Upgrade:
        if creep.upgradeController(creep.room.controller) != OK:
          creep.moveTo(creep.room.controller)

      of Migrate:
        let target = game.getObjectById(cm.targetId, Structure)
        let ret = creep.moveTo(target)
        if ret == OK:
          log creep.name & " is traveling to " & target.pos.roomName, info
        elif ret != ERR_TIRED:
          log creep.name & " (traveling) error " & ret, info

        if creep.room.name == target.pos.roomName:
          cm.action = Idle # let the new room choose what to do
          cm.refilling = false
          cm.sourceId = nil.ObjId
          cm.slurpId = nil.ObjId

          logH "Reached target"

    #for target in targets:
    #  echo target.pos.x, " ", target.pos.y, " ", target.structureType, " ", target.id

  # if there is only one tick left we drop our energy so others can pick it up
  if creep.ticksToLive == 1:
    creep.drop(RESOURCE_TYPE_ENERGY)
    logH "dropped " & creep.carry.energy & " on death"
