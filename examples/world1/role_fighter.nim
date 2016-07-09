# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps

proc roleFighter*(creep: Creep) =
  #var cm = creep.mem(CreepMemory)

  var hostiles = creep.room.findHostile(CREEP)
  #echo "Have ", hostiles.len, " hostiles"
  if hostiles.len > 0:
    var closest = creep.pos.findClosestByPath(hostiles)
    if closest == nil:
      #echo "hostile direct path"
      closest = creep.pos.findClosestByRange(hostiles)

    if closest == nil:
      log "this should not happen (155)"
      closest = hostiles[0]

    if creep.rangedAttack(closest) != OK:
      var ret = creep.moveTo(closest)
      log creep.name, " moves to attack (", ret, ")"

  else:
    creep.moveTo(game.flags.Flag1)
