# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleTank*(creep: Creep) =
  #var cm = creep.memory.CreepMemory
  #var friendly = creep.room.findMy(CREEP)
  creep.moveTo(game.flags.?Flag1)