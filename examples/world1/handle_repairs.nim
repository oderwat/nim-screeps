# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import screeps_utils

import types
import utils_stats
import sequtils

proc handleRepairs*(room: Room, creeps: seq[Creep], rstats: CreepStats, minUpgraders: int, minChargers: int, minBuilders: int) =
  var hitsmissing = 0
  proc checkHits(s: Structure): bool =
    # calc how much hits we are missing with thresholds
    if s.hitsMax < 6000:
      if s.hits.float / s.hitsMax.float <= 0.95:
        hitsmissing += s.hitsMax - s.hits
        #log s.hits & " " & s.structureType, debug
      return s.hits < s.hitsMax

    if s.structureType == STRUCTURE_TYPE_WALL:
      s.hits < (if room.controller.level < 3: 1000 else: 20000)
    else:
      false #s.hits < 10000

  var repairs = room.find(Structure, checkHits)
  log "repairs needed total: " & repairs.len & " hitsmissing: " & hitsmissing, debug

  # sort by structures with fewest health
  repairs.sort() do (a, b: Structure) -> int:
    a.hits - b.hits

  if repairs.len > 0:
    # we need at least one builder in this room
    #log "having", repairs.len, "structures to repair (", hitsmissing, " hits)"

    # shrink the number of repair sites to 4
    if repairs.len > 4:
      repairs = repairs[0..3]

    #for site in repairs:
    #  log site.id, site.hits, site.structureType

    # utilize some new creeps if less than 1 or structs < 90% and less than 4
    if hitsmissing > 0 and rstats.repairing.len < 4: # never more than 4

      if rstats.idle.len > 0:
        changeAction(rstats, Idle, Repair)

      elif rstats.upgrading.len > minUpgraders:
        changeAction(rstats, Upgrade, Repair)

      elif rstats.building.len > minBuilders:
        changeAction(rstats, Build, Repair)

      elif rstats.charging.len > minChargers:
        changeAction(rstats, Charge, Repair)

    if hitsmissing == 0 and rstats.repairing.len > 1:
        changeAction(rstats, Repair, Idle)

    for creep in creeps:
      let cm = creep.cmem
      if cm.action == Repair:
        var closest = creep.pos.findClosestByPath(repairs)
        if closest != nil:
          if cm.targetId != closest.id:
            creep.say "R" & closest.pos.at
            cm.targetId = closest.id
        else:
          log "no closest for " & creep.name & "?"
          creep.say "NoWay!"
          cm.action = Idle
          cm.targetId = nil.ObjId

  elif rstats.repairing.len > 0:
        changeAction(rstats, Repair, Idle)
