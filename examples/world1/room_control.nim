# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types
import utils_stats

import handle_repairs
import handle_tower

proc energyNeeded(room: Room): auto =
  result = room.find(Structure) do (struct: Structure) -> bool:
    if struct.structureType == STRUCTURE_TYPE_SPAWN:
      let spawn = struct.StructureSpawn
      result = spawn.energy < spawn.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_EXTENSION:
      let extension = struct.StructureExtension
      result = extension.energy < extension.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_TOWER:
      let tower = struct.StructureTower
      result = tower.energy < tower.energyCapacity

    else: result = false

proc roomControl*(room: Room, globalPirates: seq[Creep], pirateTarget: RoomName) =
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
  pirateBody = @[ATTACK, ATTACK, MOVE, MOVE, ATTACK]

  # level 1 or all workers gone, fallback to low energy ones?
  if room.energyCapacityAvailable < 450 or stats.workers.len < 6:
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

  var needCreeps = 0

  # counting of needed creeps is not yet really ok but better than before
  var spawns = room.findMy(StructureSpawn)
  if spawns.len == 0:
    logH "Room has no (owned) spawns"
  else:
    if clevel >= 2 and stats.fighters.len < 2 and stats.workers.len >= 8:
      log "need fighters (" & fightBody.calcEnergyCost, "/", room.energyAvailable & ")"
      inc needCreeps
      if room.energyAvailable >=  fightBody.calcEnergyCost:
        for spawn in spawns:
          let rm = CreepMemory(role: Fighter, refilling: true, action: Idle)
          var name = spawn.createCreep(fightBody, nil, rm)
          log "New Fighter", name, "is spawning"
          if name != "":
            dec needCreeps
            break
    elif stats.workers.len < 10:
      log "need workers (" & workBody.calcEnergyCost & " / " & room.energyAvailable & ")"
      inc needCreeps
      if room.energyAvailable >=  workBody.calcEnergyCost:
        for spawn in spawns:
          let rm = CreepMemory(role: Worker, refilling: true, action: Idle)
          var name = spawn.createCreep(workBody, nil, rm)
          log "New Worker", name, "is spawning"
          if name != "":
            dec needCreeps
            break
    # we count pirates global (and currently spwan in any room we own)
    elif clevel >= 3 and globalPirates.len < (if pirateTarget != NOROOM: 4 else: 1):
      log "need pirates (" & fightBody.calcEnergyCost & " / " & room.energyAvailable & ")"
      inc needCreeps
      if room.energyAvailable >=  pirateBody.calcEnergyCost:
        for spawn in spawns:
          let rm = CreepMemory(role: Pirate, refilling: true, action: Idle)
          var name = spawn.createCreep(pirateBody, nil, rm)
          log "New Pirate", name, "is spawning"
          if name != "":
            dec needCreeps
            break

  logS room.name & " needs " & needCreeps & " Creeps", info

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

    if stats.building.len < 6: # never more than 6

      if stats.idle.len > 0:
        changeActionToClosest(stats, Charge, Build, csites)

      elif stats.upgrading.len > 2:
        changeActionToClosest(stats, Upgrade, Build, csites)

      elif stats.charging.len > 4:
        changeActionToClosest(stats, Charge, Build, csites)

      elif stats.building.len < 3 and stats.repairing.len > 3:
        changeActionToClosest(stats, Repair, Build, csites)


  # we always charge with 3 creeps
  var needEnergy = energyNeeded(room)

  if needEnergy.len > 0 and stats.charging.len < 6: # never less than 4

    if stats.idle.len > 0:
      changeActionToClosest(stats, Idle, Charge, needEnergy)

    elif (needCreeps > 0 and stats.upgrading.len > 0) or stats.upgrading.len > 1:
      changeActionToClosest(stats, Upgrade, Charge, needEnergy)

    elif stats.building.len > 3 or stats.charging.len < 3:
      changeActionToClosest(stats, Build, Charge, needEnergy)

  if clevel >= 2:
    handleRepairs(room, creeps, stats)

  # if we have idle creeps let them upgrade
  if stats.idle.len > 0:
    changeAction(stats, Idle, Upgrade)

  #let workers = filterCreeps() do (creep: Creep) -> bool:
  #  #echo creep.name
  #  creep.mem(CreepMemory).role == Worker

  # Handle towers if available
  var towers = room.find(StructureTower) do(a: StructureTower) -> bool:
    a.structureType == STRUCTURE_TYPE_TOWER

  #logS "have " & towers.len & " towers", info
  for tower in towers:
    handleTower(tower)

  # show what we have right now
  stats.log globalPirates

