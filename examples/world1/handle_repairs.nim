# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import screeps
import types
import utils_stats

proc handleRepairs*(room: Room, creeps: seq[Creep], stats: var Stats) =
  var repairs = room.find(Structure) do (s: Structure) -> bool:
    s.hits < s.hitsMax

  # sort by structures with fewest health
  repairs.sort() do (a, b: Structure) -> int:
    a.hits - b.hits

  if repairs.len > 0:
    # we need at least one builder in this room
    log "having", repairs.len, "structures to repair"

    # shrink the number of repair sites to 4
    if repairs.len > 4:
      repairs = repairs[0..3]

    for site in repairs:
      log site.id, site.hits, site.structureType

    if stats.repairing < 4: # never more than 4

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
