# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleDefender*(creep: Creep) =
  #var cm = creep.memory.CreepMemory
  # changing role (just a hack now)
  #cm.role = Pirate

  var hostiles = creep.room.findHostile(CREEP)
  #var hostiles: seq[RoomObject] = @[]
  #hostiles.add game.getObjectById("578edc78a423f04b5db0b5ad".ObjId, RoomObject)

  #echo "Have ", hostiles.len, " hostiles"
  if hostiles.len > 0:
    var closest = creep.pos.findClosestByPath(hostiles)
    if closest == nil:
      #echo "hostile direct path"
      closest = creep.pos.findClosestByRange(hostiles)

    if closest == nil:
      logS "this should not happen (155)"
      closest = hostiles[0]

    if creep.rangedAttack(closest) != OK:
      var ret = creep.moveTo(closest)
      logS creep.name & " moves to attack (" & ret & ")"

  else:
    for flag in game.flags:
      if flag.room != creep.room:
        continue

      if flag.color == COLOR_PURPLE:
        creep.moveTo(flag)
        break
