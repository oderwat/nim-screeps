# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleHarvester*(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert

  # so we can act on the same tick
  if creep.carry.energy == 0 and not cm.refilling:
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
        let source = game.getObjectById(cm.sourceId, Source)
        let ret = creep.harvest(source)
        if ret == ERR_NOT_IN_RANGE:
          creep.moveTo(source)
        elif ret != OK and ret != ERR_BUSY:
          creep.say "#?%!"
          log creep.name, "is lost:", ret

    else:
      #echo creep.name, " is now full"
      creep.say "Full"
      cm.refilling = false
  else:
    # harvesters always fill the nearest container (noting else)
    if cm.targetId == nil:
      var target = creep.pos.find
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
          cm.targetId = nil
          cm.action = Idle
      elif target.progress == target.progressTotal:
        cm.targetId = nil
        cm.action = Idle

    elif cm.action == Repair:
      var target = game.getObjectById(cm.targetId, Structure)
      if creep.repair(target) != OK:
        if creep.moveTo(target) == ERR_INVALID_TARGET:
          cm.targetId = nil
          cm.action = Idle
      elif target.hits == target.hitsMax:
        cm.targetId = nil
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
