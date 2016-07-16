# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

const claimRoom = "W39N8".RoomName

proc roleClaimer*(creep: Creep) =
  let controller = creep.room.controller
  if controller.my:
    discard creep.travel(claimRoom)
  else:
    let ret = creep.attackController(controller)
    if ret != OK:
      creep.moveTo(controller)
      logS "attacked", debug
    else:
      logS "what now? " & $$ret, debug
