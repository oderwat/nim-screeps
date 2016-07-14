# Copyright 2016.

# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc roleHealer*(creep: Creep) =
  #var cm = creep.memory.CreepMemory
  #var friendly = creep.room.findMy(CREEP)
  creep.moveTo(game.flags.?Flag1)
