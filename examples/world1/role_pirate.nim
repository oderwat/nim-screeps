# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils

proc rolePirate*(creep: Creep, pirateTarget: RoomName) =
  #var cm = creep.mem(CreepMemory)

  var hostileCreeps = creep.room.findHostile(Creep)
  var hostileStructs: seq[Structure]
  var closestStruct: Structure
  var closestCreep: Creep
  #log creep.name, " in ", creep.room.name
  #log "Have ", hostileCreeps.len, " hostile Creeps"
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
      #logH "nothing to attack, hanging arround"
      creep.moveTo(game.flags.?Flag2)
    else:
      #echo "attacking ", closestStruct.id
      var ranged = false
      var melee = false
      for b in creep.body:
        if b.part == RANGED_ATTACK:
          ranged = true
        if b.part == ATTACK:
          melee = true

      if melee:
        if creep.attack(closestStruct) != OK:
          if ranged:
            discard creep.rangedAttack(closestStruct) # while going there
          var ret = creep.moveTo(closestStruct)
          log creep.name, "moves to attack (" & ret & ")"
  else:
    if pirateTarget != "":
      #log "pirateTarget is ", pirateTarget
      var rt = travel(creep, pirateTarget)
      #log creep.name, "moving to target", rt
    else:
      #log "moving to flag"
      creep.moveTo(game.flags.?Flag1)
