# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import screeps
import types

proc energyNeeded(creep: Creep): auto =
  result = creep.room.find(Structure) do (struct: Structure) -> bool:
    if struct.structureType == STRUCTURE_TYPE_SPAWN:
      let spawn = struct.StructureSpawn
      result = spawn.energy < spawn.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_EXTENSION:
      let extension = struct.StructureExtension
      result = extension.energy < extension.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_TOWER:
      let tower = struct.StructureTower
      result = tower.energy < tower.energyCapacity

    else: result = false

proc roleWorker*(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert

  # so we can act on the same tick
  if creep.carry.energy == 0 and not cm.refilling:
    creep.say "Empty"
    cm.refilling = true

  if cm.refilling == true:
    if creep.carry.energy < creep.carryCapacity:
      var source = game.getObjectById(cm.sourceId, Source)
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
    var needEnergy = energyNeeded(creep)
    # need some kind of priority list here
    if cm.action == Charge:
      if needEnergy.len > 0:
        let target = needEnergy[0]
        #echo "Charging: ", target.structureType, at target.pos
        if creep.transfer(target, RESOURCE_TYPE_ENERGY) != OK:
          creep.moveTo(target)
      else:
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

    if cm.action == Idle:
      if needEnergy.len > 0:
        cm.action = Charge
      else:
        cm.action = Upgrade

    #for target in targets:
    #  echo target.pos.x, " ", target.pos.y, " ", target.structureType, " ", target.id
