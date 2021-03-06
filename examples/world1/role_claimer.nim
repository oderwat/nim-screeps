# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils
import types

proc roleClaimer*(creep: Creep, claimRoom: RoomName) =
  let controller = creep.room.controller
  if controller.my:
    discard creep.travel(claimRoom)

  else:
    let ret = creep.claimController(controller)
    if ret != OK:
      let ret = creep.reserveController(controller)
      if ret != OK:
        creep.moveTo(controller)
        #log "claiming", debug
    else:
      log "what now? " & $$ret, debug
