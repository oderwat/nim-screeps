# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import system except echo, log

import screeps
import types
import utils_stats

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
    if (stats.repairing < 1) or
      (hitsmissing > 0 and stats.repairing < 4): # never more than 4

      if stats.idle > 0:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Idle:
            m.action = Repair
            inc stats.repairing
            dec stats.idle
            break;

      elif stats.upgrading > 2:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Upgrade:
            m.action = Repair
            inc stats.repairing
            dec stats.upgrading
            break;

      elif stats.building > 3:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Build:
            m.action = Repair
            inc stats.repairing
            dec stats.building
            break;

      elif stats.charging > 4:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Charge:
            m.action = Repair
            inc stats.repairing
            dec stats.charging
            break;

    if hitsmissing == 0 and stats.repairing > 1:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Repair:
            m.action = Idle
            dec stats.repairing
            inc stats.idle
            break;

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
