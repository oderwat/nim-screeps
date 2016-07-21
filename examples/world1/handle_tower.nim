# nop
# run nim build --hint[conf]:off main.nim

import system except log

import screeps
import types
import macros

proc handleTower*(tower: StructureTower) =
    var closestHostile = tower.findClosestHostileByRange(Creep)
    if closestHostile != nil:
      tower.attack(closestHostile)

    #log "Tower " & tower.energy

    if tower.energy > 0:
      var closestDamegedCreep = tower.findMyClosestByRange(Creep) do(creep: Creep) -> bool:
        creep.hits < creep.hitsMax

      if closestDamegedCreep != nil:
        tower.heal(closestDamegedCreep)

    if tower.energy > tower.energyCapacity div 3 and tower.room.name != "W38N7":
      var closestDamagedStructure = tower.findClosestByRange(Structure) do(structure: Structure) -> bool:
        if structure.hits == structure.hitsMax:
          return false

        if structure.structureType == STRUCTURE_TYPE_TOWER:
          return false

        if structure.structureType == STRUCTURE_TYPE_CONTROLLER:
          return structure.hits < structure.hitsMax

        if structure.structureType == STRUCTURE_TYPE_SPAWN:
          return structure.hits < structure.hitsMax

        if structure.structureType == STRUCTURE_TYPE_EXTENSION:
          return structure.hits < structure.hitsMax

        if structure.structureType == STRUCTURE_TYPE_WALL:
          return structure.hits < 20000

        if structure.structureType == STRUCTURE_TYPE_RAMPART:
          return structure.hits < 50000

        # keep everyting else at 80 %
        return structure.hits.float / structure.hitsMax.float <= 0.80

        #logH "handleTower found a " & structure.structureType & " structure"
        #structure.hits < structure.hitsMax div 5

      if closestDamagedStructure != nil:
        tower.repair(closestDamagedStructure)
