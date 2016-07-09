# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import system except echo, log

import screeps
import types
import utils_stats
import sequtils

proc handleRepairs*(room: Room, creeps: seq[Creep], stats: var Stats) =
  var hitsmissing = 0
  proc checkHits(s: Structure): bool =
    # calc how much hits we are missing with thresholds
    if s.hitsMax < 6000:
      if s.hits.float / s.hitsMax.float <= 0.95:
        hitsmissing += s.hitsMax - s.hits

    s.hits < s.hitsMax

  var repairs = room.find(Structure, checkHits)

  # sort by structures with fewest health
  repairs.sort() do (a, b: Structure) -> int:
    a.hits - b.hits

  if repairs.len > 0:
    # we need at least one builder in this room
    log "having", repairs.len, "structures to repair (", hitsmissing, " hits)"

    # shrink the number of repair sites to 4
    if repairs.len > 4:
      repairs = repairs[0..3]

    for site in repairs:
      log site.id, site.hits, site.structureType

    # utilize some new creeps if less than 1 or structs < 90% and less than 4
    if (stats.repairing.len < 1) or
      (hitsmissing > 0 and stats.repairing.len < 4): # never more than 4

      if stats.idle.len > 0:
        changeAction(stats, Idle, Repair)

      elif stats.upgrading.len > 2:
        changeAction(stats, Upgrade, Repair)

      elif stats.building.len > 3:
        changeAction(stats, Build, Repair)

      elif stats.charging.len > 4:
        changeAction(stats, Charge, Repair)

    if hitsmissing == 0 and stats.repairing.len > 1:
        changeAction(stats, Repair, Idle)

    for creep in creeps:
      let m = creep.memory.CreepMemory
      if m.action == Repair:
        var closest = creep.pos.findClosestByPath(repairs)
        if closest != nil:
          m.targetId = closest.id
        else:
          log "no closest for", creep.name, "?"
          creep.say "NoWay!"
          m.action = Idle
          m.targetId = nil
