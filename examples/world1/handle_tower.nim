# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc handleTower*(tower: StructureTower) =
    var closestHostile = tower.findClosestHostileByRange(Creep)
    if closestHostile != nil:
      tower.attack(closestHostile)
    elif tower.energy > tower.energyCapacity div 4:
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

        # keep everyting else at 95 %
        return structure.hits.float / structure.hitsMax.float <= 0.95

        #logH "handleTower found a " & structure.structureType & " structure"
        #structure.hits < structure.hitsMax div 5

      if closestDamagedStructure != nil:
        tower.repair(closestDamagedStructure)
