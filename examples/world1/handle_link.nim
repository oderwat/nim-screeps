# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types

proc handleLink*(link: StructureLink) =
  var sourceLink = false
  var rm = link.room.rmem
  for t in rm.sourceLinks:
    if link.id == t:
      sourceLink = true
      break

  #logH "link: " & link.id & " " & (if sourceLink: "Source" else: "Dest").cstring

  if sourceLink:
    if link.cooldown > 0:
      #logH "but we are in cooldown"
      return

    let have = link.energy
    # nothin here anyway (does not matter if source or not)
    if have == 0: return

    let targets = link.room.find(StructureLink) do(structure: Structure) -> bool:
      structure.structureType == STRUCTURE_TYPE_LINK and
        structure != link

    # who needs the most?
    var target: StructureLink = nil
    var target_want: int
    for checkneed in targets:
      let want = checkneed.energyCapacity - checkneed.energy
      if want > 0:
        if target != nil and want < target_want:
          continue
        target = checkneed
        target_want = want

    if target != nil:
        link.transferEnergy(target, min(have, target_want))
