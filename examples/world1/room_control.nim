# nop
# run nim build --verbosity:1 --hint[processing]:off --hint[conf]:off main.nim

import screeps
import types
import utils_stats

import handle_repairs
import handle_tower

proc roomControl*(room: Room) =
  # is null for sim
  #let exits = game.map.describeExits(room.name)
  #for k, v in exits:
  #  echo "Exit: ", k, " > ", v

  #var rm = room.memory.RoomMemory
  #rm.war = true
  #let war = true

  #let cinfo = room.controller.info()
  template clevel: int = room.controller.level

  log "Room Capacity:", room.energyAvailable, "/", room.energyCapacityAvailable

  let sources = room.find(Source)
  let creeps = room.findMy(Creep)

  var stats = creeps.stats()

  var idx = 0
  for creep in creeps:
    let cm = creep.memory.CreepMemory
    if cm.role == Worker:
      # naive sources "assignment"
      inc idx
      if cm.sourceId == nil:
        cm.sourceId = sources[idx mod sources.len].id

  var workBody: seq[BodyPart]
  var fightBody: seq[BodyPart]
  var pirateBody: seq[BodyPart]

  # just for fun :)
  pirateBody = @[ATTACK, MOVE, ATTACK, MOVE]

  # level 1 or all workers gone?
  if room.energyCapacityAvailable < 450 or stats.workers < 2:
    #body = @[WORK, WORK, CARRY, MOVE]
    workBody = @[WORK, CARRY, CARRY, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 550:
    workBody = @[WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 800:
    workBody = @[WORK, WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[RANGED_ATTACK, MOVE, RANGED_ATTACK]
  else:
    workBody = @[WORK, WORK, WORK, WORK, WORK, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[RANGED_ATTACK, MOVE, RANGED_ATTACK, MOVE]

  var csites = room.find(ConstructionSite)
  # Sort by smalles energy cost for finishing construction
  # Extensions are priorised above walls and rampants
  csites.sort() do (a, b: ConstructionSite) -> int:
    var ea, eb: int
    if a.structureType == STRUCTURE_TYPE_EXTENSION:
      ea = 2
    else:
      ea = a.progressTotal - a.progress

    if b.structureType == STRUCTURE_TYPE_EXTENSION:
      eb = 2
    else:
      eb = b.progressTotal - b.progress

    ea - eb

  if csites.len > 0:
    # we need at least one builder in this room
    log "having", csites.len, "construction sites"
    #for site in csites:
    #  echo site.id, " ", site.progressTotal - site.progress

    # shrink the number of repair sites to 4
    if csites.len > 2:
      csites = csites[0..2]

    for site in csites:
      log site.id, site.progressTotal - site.progress, site.structureType

    if stats.building < 6: # never more than 6

      if stats.idle > 0:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Idle:
            m.action = Build
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.building
            dec stats.idle
            break;

      elif stats.upgrading > 2:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Upgrade:
            m.action = Build
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.building
            dec stats.upgrading
            break;

      elif stats.charging > 4:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Charge:
            m.action = Build
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.building
            dec stats.charging
            break;

      elif stats.building < 3 and stats.repairing > 3:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Repair:
            m.action = Build
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.building
            dec stats.repairing
            break;

  # we always charge with 3 creeps
  if stats.charging < 3: # never less than 3

    if stats.idle > 0:
      for creep in creeps:
        let m = creep.memory.CreepMemory
        if m.action == Idle:
          m.action = Charge
          m.targetId = nil
          inc stats.charging
          dec stats.idle
          break;

    elif stats.upgrading > 2:
      for creep in creeps:
        let m = creep.memory.CreepMemory
        if m.action == Upgrade:
          m.action = Charge
          m.targetId = nil
          inc stats.charging
          dec stats.upgrading
          break;

    elif stats.building > 3:
      for creep in creeps:
        let m = creep.memory.CreepMemory
        if m.action == Build:
          m.action = Charge
          m.targetId = nil
          inc stats.charging
          dec stats.building
          break;

  if clevel >= 2:
    handleRepairs(room, creeps, stats)

  #let workers = filterCreeps() do (creep: Creep) -> bool:
  #  #echo creep.name
  #  creep.mem(CreepMemory).role == Worker

  if clevel >= 2 and stats.fighters < 4 and stats.workers >= 2:
    log "need fighters (" & fightBody.calcEnergyCost, "/", room.energyAvailable & ")"
    if room.energyAvailable >=  fightBody.calcEnergyCost:
      for spawn in game.spawns:
        let rm = CreepMemory(role: Fighter, refilling: true, action: Charge)
        var name = spawn.createCreep(fightBody, nil, rm)
        dump name
        log "New Fighter", name, "is spawning"
  elif stats.workers < 14:
    log "need workers (" & workBody.calcEnergyCost & " / " & room.energyAvailable & ")"
    if room.energyAvailable >=  workBody.calcEnergyCost:
      for spawn in game.spawns:
        let rm = CreepMemory(role: Worker, refilling: true, action: Idle)
        var name = spawn.createCreep(workBody, nil, rm)
        dump name
        log "New Worker", name, "is spawning"
  elif clevel >= 3 and stats.pirates < 4:
    log "need pirates (" & fightBody.calcEnergyCost & " / " & room.energyAvailable & ")"
    if room.energyAvailable >=  pirateBody.calcEnergyCost:
      for spawn in game.spawns:
        let rm = CreepMemory(role: Pirate, refilling: true, action: Idle)
        var name = spawn.createCreep(pirateBody, nil, rm)
        dump name
        log "New Pirate", name, "is spawning"

  # Handle towers if available
  var towers = room.find(StructureTower) do(a: StructureTower) -> bool:
    a.structureType == STRUCTURE_TYPE_TOWER

  log "have", towers.len, "towers"
  for tower in towers:
    handleTower(tower)

  # show what we have right now
  dump stats
