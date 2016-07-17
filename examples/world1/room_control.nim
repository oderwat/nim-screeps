# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps
import types
import utils_stats

import handle_repairs
import handle_tower
import handle_link

proc energyNeededTotal(room: Room): auto =
  result = room.find(Structure) do (struct: Structure) -> bool:
    #if struct.structureType == STRUCTURE_TYPE_SPAWN:
    #  let spawn = struct.StructureSpawn
    #  result = spawn.energy < spawn.energyCapacity

    if struct.structureType == STRUCTURE_TYPE_EXTENSION:
      let extension = struct.StructureExtension
      result = extension.energy < extension.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_TOWER:
      let tower = struct.StructureTower
      result = tower.energy < tower.energyCapacity

    #elif struct.structureType == STRUCTURE_TYPE_STORAGE:
    #  let tower = struct.StructureStorage
    #  result = tower.energy < tower.energyCapacity

    else: result = false

proc energyNeeded(room: Room): auto =
  # udate spawn energy first
  result = room.find(Structure) do (struct: Structure) -> bool:
    if struct.structureType == STRUCTURE_TYPE_SPAWN:
      let spawn = struct.StructureSpawn
      return spawn.energy.float < spawn.energyCapacity.float * 0.90
    return false

  if result.len > 0:
    return result

  result = room.find(Structure) do (struct: Structure) -> bool:
    if struct.structureType == STRUCTURE_TYPE_TOWER:
      let tower = struct.StructureTower
      return tower.energy.float < tower.energyCapacity.float * 0.75
    return false

  if result.len > 0:
    return result

  return room.energyNeededTotal

template mySpawn(newRole: Roles, body: seq[BodyPart], needCreeps) =
  let roleName = ($newRole).cstring
  log "need " & roleName & " (" & body.calcEnergyCost & " / " & room.energyAvailable & ")"
  if room.energyAvailable >= body.calcEnergyCost:
      for spawn in spawns:
        let rm = CreepMemory(role: newRole, refilling: true, action: Idle)
        var name = spawn.createCreep(body, nil, rm)
        if name != "":
          log "New", roleName, name, "is spawning"
          dec needCreeps
          break

proc roomControl*(room: Room, globalPirates: seq[Creep], pirateTarget: RoomName, globalClaimers: seq[Creep]) =
  # is null for sim
  #let exits = game.map.describeExits(room.name)
  #for k, v in exits:
  #  echo "Exit: ", k, " > ", v

  var rm = room.memory.RoomMemory
  if rm.sourceContainers == nil:
    rm.sourceContainers = @[]
  if rm.sourceLinks == nil:
    rm.sourceLinks = @[]
  #rm.war = true
  #let war = true

  #let cinfo = room.controller.info()
  template clevel: int = room.controller.level

  log "Room Capacity:", room.energyAvailable, "/", room.energyCapacityAvailable

  let sources = room.find(Source)
  let creeps = room.findMy(Creep)

  var stats = creeps.stats()

  room.memory.RoomMemory.stats = stats

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
  var claimBody: seq[BodyPart]
  var healerBody: seq[BodyPart]
  var tankBody: seq[BodyPart]
  var harvestBody: seq[BodyPart]
  var haulBody: seq[BodyPart]
  var uplinkBody: seq[BodyPart]

  # just for fun :)
  pirateBody = @[ATTACK, ATTACK, MOVE, MOVE, ATTACK]
  tankBody = @[TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH, MOVE, MOVE, MOVE, MOVE, MOVE]
  healerBody = @[MOVE, MOVE, MOVE, MOVE,HEAL, HEAL]
  claimBody = @[CLAIM, CLAIM, CLAIM, CLAIM, CLAIM, MOVE]

  harvestBody = @[WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]
  uplinkBody = @[WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]
  haulBody = @[CARRY, CARRY, CARRY, CARRY, CARRY, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]

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
    workBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, CARRY, CARRY, CARRY, CARRY,
      CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
    #workBody = @[WORK, WORK, WORK, WORK, WORK, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[TOUGH, TOUGH, TOUGH, TOUGH, MOVE, MOVE, MOVE, RANGED_ATTACK, RANGED_ATTACK, MOVE]
    pirateBody = @[TOUGH, TOUGH, TOUGH, MOVE, MOVE, MOVE, MOVE, ATTACK, ATTACK, MOVE]

  var needCreeps = 0
  var maxUpgraders = 8
  var minUpgraders = 2
  if stats.uplinkers.len > 0:
    maxUpgraders = 0
  #var intrudersDetected = false

  # counting of needed creeps is not yet really ok but better than before
  var spawns = room.findMy(StructureSpawn)
  if spawns.len == 0:
    logH "Room has no (owned) spawns"
  else:
    let wantWorkers = if stats.uplinkers.len > 0: 6 else: 10
    if stats.workers.len < wantWorkers:
      needCreeps += wantWorkers - stats.workers.len
      mySpawn Worker, workBody, needCreeps

    let wantDefenders = if clevel >= 2: 3 else: 2
    if stats.defenders.len < wantDefenders:
      needCreeps += wantDefenders - stats.defenders.len
      if stats.workers.len >= wantWorkers:
        mySpawn Defender, fightBody, needCreeps

    # we count pirates global (and currently spwan in any room we own)
    let wantPirates = if clevel >= 3: 2 else: 0
    if globalPirates.len < wantPirates:
      needCreeps += wantPirates - globalPirates.len
      if stats.workers.len >= wantWorkers:
        mySpawn Pirate, tankBody, needCreeps

    # claimers (global)
    let wantClaimers = 0
    if globalClaimers.len < wantClaimers:
      needCreeps += wantClaimers - globalClaimers.len
      mySpawn Claimer, claimBody, needCreeps

    let sources = room.find(Source)

    if stats.harvesters.len < sources.len:
      needCreeps += sources.len - stats.harvesters.len
      mySpawn Harvester, harvestBody, needCreeps

    let containers = room.find(StructureContainer) do (structure: Structure) -> bool:
      structure.structureType == STRUCTURE_TYPE_CONTAINER

    let wantHaulers = containers.len  # seems to be enough
    if stats.haulers.len < wantHaulers:
      needCreeps += wantHaulers - stats.haulers.len
      mySpawn Hauler, haulBody, needCreeps

    let wantUplinkers = 1 # seems to be enough
    if stats.uplinkers.len < wantUplinkers:
      needCreeps += sources.len - stats.harvesters.len
      mySpawn Uplinker, uplinkBody, needCreeps

    for spawn in spawns:
      if spawn.spawning != nil:
        let m = memory.creeps[spawn.spawning.name].CreepMemory
        if m != nil:
          #log "Spawning", $$m.role, spawn.spawning.remainingTime
          discard
        else:
          logS "Missing memory for spawning creep", error
        dec needCreeps

  if needCreeps > 0:
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
    # log "having", csites.len, "construction sites"
    #for site in csites:
    #  echo site.id, " ", site.progressTotal - site.progress

    # shrink the number of repair sites to 4
    if csites.len > 2:
      csites = csites[0..2]

    # for site in csites:
    #   log site.id, site.progressTotal - site.progress, site.structureType

    if stats.building.len < 6: # never more than 6

      if stats.idle.len > 0:
        changeActionToClosest(stats, Idle, Build, csites)

      elif stats.upgrading.len > minUpgraders:
        changeActionToClosest(stats, Upgrade, Build, csites)

      elif stats.charging.len > 4:
        changeActionToClosest(stats, Charge, Build, csites)

      elif stats.building.len < 3 and stats.repairing.len > 3:
        changeActionToClosest(stats, Repair, Build, csites)


  # charge handling
  var totalEnergyNeeded = energyNeededTotal(room)

  var minChargers = if totalEnergyNeeded.len <= 3: 1 else: totalEnergyNeeded.len div 6
  var maxChargers = if totalEnergyNeeded.len <= 3: 3 else: totalEnergyNeeded.len div 2

  if stats.uplinkers.len > 0:
    minChargers = totalEnergyNeeded.len
    maxChargers = totalEnergyNeeded.len

  log $$minChargers, maxChargers, totalEnergyNeeded.len, needCreeps, stats.upgrading.len
  #logS "needEnergy " & needEnergy.len, debug
  if totalEnergyNeeded.len > 0 and stats.charging.len < maxChargers: # never less than 2
    # prioritized answers
    var needEnergy = energyNeeded(room)
    #logS "changing to chargers", debug

    if stats.idle.len > 0:
      changeActionToClosest(stats, Idle, Charge, needEnergy)

    if (needCreeps > 0 and stats.upgrading.len > 0) or stats.charging.len < minChargers:
      changeActionToClosest(stats, Upgrade, Charge, needEnergy)

    if (stats.building.len > 0 and stats.charging.len < minChargers) or stats.building.len > 3:
      changeActionToClosest(stats, Build, Charge, needEnergy)

  if clevel >= 2:
    handleRepairs(room, creeps, stats, needCreeps)

  # if we have idle creeps let them upgrade
  if stats.idle.len > 0 and stats.upgrading.len < maxUpgraders:
    changeAction(stats, Idle, Upgrade)

  # no creeps needed and enough chargers available. move others to Upgrader
  if needCreeps == 0 and
    stats.charging.len > minChargers and stats.upgrading.len < minUpgraders:
      changeAction(stats, Charge, Upgrade)

  if stats.upgrading.len > maxUpgraders:
    changeAction(stats, Upgrade, Idle)

  if stats.charging.len > maxChargers:
    changeAction(stats, Charge, Idle)

  #let workers = filterCreeps() do (creep: Creep) -> bool:
  #  #echo creep.name
  #  creep.mem(CreepMemory).role == Worker

  # Handle towers if available
  var towers = room.find(StructureTower) do(a: Structure) -> bool:
    a.structureType == STRUCTURE_TYPE_TOWER

  #logS "have " & towers.len & " towers", info
  for tower in towers:
    handleTower(tower)

  var links = room.find(StructureLink) do(a: Structure) -> bool:
    a.structureType == STRUCTURE_TYPE_LINK

  #logS "have " & towers.len & " towers", info
  for link in links:
    handleLink(link)

  var gm = memory.GameMemory
  if  gm.cmd == "toggle stats":
    gm.cmd = nil
    gm.logStats = not gm.logStats

  if gm.logStats or gm.cmd == "show stats":
    if gm.cmd == "show stats":
      gm.cmd = nil
    stats.log globalPirates, globalClaimers

  # check for dropped resources
  let drops = room.find(Resource)
  for resource in drops:
    # need at least be "something"
    if resource.amount < 5: continue
    # who wants it? vultures :)
    let slurper = resource.pos.findClosestByPath(creeps) do (creep: Creep) -> bool:
      let cm = creep.memory.CreepMemory
      # workers only of course
      if cm.role != Worker: return false
      let free = creep.carryCapacity - creep.carry.energy
      if free == 0: return false
      #let distance = resource.pos.getRangeTo(creep.pos)
      # get the path and check its lenght
      let path = resource.pos.findPathTo(creep.pos)
      let distance = path.len
      # no grannies please
      if creep.ticksToLive < distance + 200: return false
      # estimate if there will be something left
      let estimate = resource.amount - (distance + distance div 2)
      if estimate > 0 and (free >= estimate or (creep.carryCapacity > 0 and estimate > creep.carryCapacity)):
        logH creep.name & " " & distance & " " & resource.amount & " " & free & " " & estimate
        true
      else:
        logS creep.name & " " & distance & " " & resource.amount & " " & free & " " & estimate, debug
        false

    if slurper != nil:
      let cm = slurper.memory.CreepMemory
      cm.refilling = true
      cm.slurpId = resource.id
      log slurper.name, "is Vulture"
      slurper.say "Vulture"
    else:
      log "no slurper"

    log "on the floor is ", resource.amount, "of", resource.resourceType
