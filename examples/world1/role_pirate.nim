# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils

proc rolePirate*(creep: Creep, pirateTarget: RoomName) =
  #var cm = creep.mem(CreepMemory)

  var hostileCreeps = creep.room.findHostile(Creep)
  var hostileStructs: seq[Structure]
  var closestStruct: Structure
  var closestCreep: Creep
  #echo creep.name, " in ", creep.room.name
  #echo "Have ", hostileCreeps.len, " hostile Creeps"
  if hostileCreeps.len > 0:
    closestCreep = creep.pos.findClosestByPath(hostileCreeps)
    if closestCreep != nil:
      if creep.attack(closestCreep) != OK:
        var ret = creep.moveTo(closestCreep)
        discard ret
        #echo creep.name, " moves to attack (", ret, ")"
      return

  if creep.room.name == pirateTarget:
    # check if we have towers and a path to them
    hostileStructs = creep.room.find(Structure) do (struct: Structure) -> bool:
      struct.structureType == STRUCTURE_TYPE_TOWER
    # and a path to the tower
    closestStruct =  creep.pos.findClosestByPath(hostileStructs)

    if closestStruct == nil:
      # find other structs
      hostileStructs = creep.room.find(Structure) do (struct: Structure) -> bool:
        struct.structureType != STRUCTURE_TYPE_ROAD and struct.structureType != STRUCTURE_TYPE_CONTROLLER

      #echo "Have ", hostileStructs.len, " hostile Structs"
      closestStruct =  creep.pos.findClosestByPath(hostileStructs)

    if closestStruct == nil:
      #echo "nothing to attack, going home"
      creep.moveTo(game.flags.Flag1)
    else:
      #echo "attacking ", closestStruct.id
      if creep.attack(closestStruct) != OK:
        var ret = creep.moveTo(closestStruct)
        log creep.name, "moves to attack (" & ret & ")"
  else:
    if pirateTarget != "":
      log creep.name, "moving to target", travel(creep, pirateTarget)
    else:
      #echo "moving to flag"
      creep.moveTo(game.flags.Flag1)
