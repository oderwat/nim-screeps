# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc handleLink*(link: StructureLink) =
  var sourceLink = false
  var rm = link.room.memory.RoomMemory
  for t in rm.sourceLinks:
    if link.id == t:
      sourceLink = true
      break

  if sourceLink:
    #logH "we are a source link"
    if link.cooldown > 0:
      #logH "but we are in cooldown"
      return
    let targets = link.room.find(StructureLink) do(structure: Structure) -> bool:
      structure.structureType == STRUCTURE_TYPE_LINK and
        structure != link

    for target in targets:
      let have = link.energy
      if have == 0: break
      let want = target.energyCapacity - target.energy
      if want > 0:
        link.transferEnergy(target, min(have, want))
