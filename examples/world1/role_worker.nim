# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleWorker*(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert

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
          log creep.name, "Gone?"
        else:
          let ret = creep.pickup(resource)
          if ret == ERR_NOT_IN_RANGE:
            creep.moveTo(resource)
          elif ret == OK:
            creep.say "Slurped"
            log creep.name, "Slurped"
            cm.slurpId = nil.ObjId
            cm.refilling = false
          elif ret != OK and ret != ERR_BUSY:
            creep.say "Cough"
            log creep.name, "Cough", ret
            cm.slurpId = nil.ObjId
            cm.refilling = false
      else:
        # find a storage... if it has energy go there
        let storage = creep.pos.findMyClosestByPath(StructureStorage) do(structure: Structure) -> bool:
          structure.structureType == STRUCTURE_TYPE_STORAGE

        # we prefer storage energy over harvesting ourselfs
        if storage != nil and storage.store[RESOURCE_TYPE_ENERGY] > 0:
          let ret = creep.withdraw(storage, RESOURCE_TYPE_ENERGY)
          if ret == ERR_NOT_IN_RANGE:
            creep.moveTo(storage)
          elif ret != OK and ret != ERR_BUSY:
            creep.say "#?%!"
            log creep.name, "is lost:", ret
        else:
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
            log creep.name, "is lost:", ret

    else:
      #echo creep.name, " is now full"
      creep.say "Full"
      cm.refilling = false
  else:

    #var needEnergy = energyNeeded(creep)
    # need some kind of priority list here
    if cm.action == Charge:
      var target = game.getObjectById(cm.targetId, EnergizedStructure)
      #echo "Charging: ", target.structureType, at target.pos
      var ret = creep.transfer(target, RESOURCE_TYPE_ENERGY)
      if ret == ERR_NOT_IN_RANGE:
        creep.moveTo(target)
      else:
        creep.say($ret.int)
        cm.action = Idle

    elif cm.action == Build:
      var target = game.getObjectById(cm.targetId, ConstructionSite)
      if creep.build(target) != OK:
        if creep.moveTo(target) == ERR_INVALID_TARGET:
          cm.targetId = nil.ObjId
          cm.action = Idle
      elif target.progress == target.progressTotal:
        cm.targetId = nil.ObjId
        cm.action = Idle

    elif cm.action == Repair:
      var target = game.getObjectById(cm.targetId, Structure)
      if creep.repair(target) != OK:
        if creep.moveTo(target) == ERR_INVALID_TARGET:
          cm.targetId = nil.ObjId
          cm.action = Idle
      elif target.hits == target.hitsMax:
        cm.targetId = nil.ObjId
        cm.action = Idle

    elif cm.action == Upgrade:
      if creep.upgradeController(creep.room.controller) != OK:
        creep.moveTo(creep.room.controller)

    #for target in targets:
    #  echo target.pos.x, " ", target.pos.y, " ", target.structureType, " ", target.id

  # if there is only one tick left we drop our energy so others can pick it up
  if creep.ticksToLive == 1:
    creep.drop(RESOURCE_TYPE_ENERGY)
    logH "dropped " & creep.carry.energy & " on death"
