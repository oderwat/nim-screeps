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
    if struct.structureType == STRUCTURE_TYPE_EXTENSION:
      let extension = struct.StructureExtension
      result = extension.energy < extension.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_TOWER:
      let tower = struct.StructureTower
      result = tower.energy < tower.energyCapacity

    elif struct.structureType == STRUCTURE_TYPE_SPAWN:
      let spawn = struct.StructureSpawn
      result = spawn.energy < spawn.energyCapacity

    else: result = false

proc energyNeeded(room: Room): auto =
  # udate spawn energy first
  result = room.find(Structure) do (struct: Structure) -> bool:
    if struct.structureType == STRUCTURE_TYPE_SPAWN:
      let spawn = struct.StructureSpawn
      return spawn.energy < spawn.energyCapacity
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
        let (ret, name) = spawn.createCreep(body, nil, rm)
        if ret == OK:
          log "New " & roleName & " " & name & " is spawning"
          dec needCreeps
          break
        else:
          log "Trying to spawn yields error " & ret, error # of course

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

  var spawns = room.findMy(StructureSpawn)
  if spawns.len == 0:
    logH "Room has no (owned) spawns"

  #let cinfo = room.controller.info()
  template clevel: int = room.controller.level

  logH "- " & room.name & " - CL: " & room.controller.level & " - EC: " &
    room.energyAvailable & "/" & room.energyCapacityAvailable & "-----#001"

  let sources = room.find(Source)
  let creeps = room.findMy(Creep)
  var csites = room.find(ConstructionSite)

  let containers = room.find(StructureContainer) do (structure: Structure) -> bool:
    structure.structureType == STRUCTURE_TYPE_CONTAINER

  let storages = room.find(StructureStorage) do (structure: Structure) -> bool:
    structure.structureType == STRUCTURE_TYPE_STORAGE

  let towers = room.find(StructureTower) do(a: Structure) -> bool:
    a.structureType == STRUCTURE_TYPE_TOWER
  let links = room.find(StructureLink) do(a: Structure) -> bool:
    a.structureType == STRUCTURE_TYPE_LINK

  var stats = creeps.stats()

  room.memory.RoomMemory.stats = stats

  let totalEnergyNeeded = energyNeededTotal(room)

  var wantImigrants = 0
  if room.name != "W39N7".RoomName:
    # do we want imigrant workers?
    wantImigrants = 0

  if wantImigrants > 0:
    for creep in creeps:
      var cm = creep.memory.CreepMemory
      if cm.imigrant:
        dec wantImigrants

    logH "imigration needs: " & wantImigrants
    if wantImigrants > 0:
      # need to send workers here
      for creep in game.creeps:
        if wantImigrants <= 0:
          break

        # only creeps from our main room
        if creep.room.name != "W39N7".RoomName:
          continue

        if creep.ticksToLive < 1000:
          # no granies
          continue

        var cm = creep.memory.CreepMemory
        # if it is an imigrand .. ok
        if cm.imigrant:
          cm.action = Migrate
          cm.refilling = true
          cm.targetId = room.controller.id
          dec wantImigrants
          log creep.name & " is migrating"
        elif cm.role == Worker:
          # any creep for now
          cm.action = Migrate
          cm.targetId = room.controller.id
          cm.refilling = true
          cm.imigrant = true
          dec wantImigrants
          log creep.name & " was hired"

      stats = creeps.stats()

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
  #pirateBody = @[WORK,WORK,WORK,WORK,WORK, WORK, WORK, WORK, WORK, WORK, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
  #pirateBody = @[ATTACK, ATTACK, ATTACK, ATTACK, ATTACK, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
  pirateBody = @[ATTACK, ATTACK, MOVE, MOVE, MOVE, ATTACK, MOVE]

  tankBody = @[TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH,TOUGH, MOVE, MOVE, MOVE, MOVE, MOVE]
  healerBody = @[MOVE, MOVE, MOVE, MOVE,HEAL, HEAL]
  claimBody = @[CLAIM, CLAIM, MOVE]

  # bodies for 800 at least
  # harves body
  if clevel < 3:
    # no carry so it only works with containers (not for links)
    # but there are not links with clevel < 3
    harvestBody = @[WORK, WORK, WORK, WORK, WORK, MOVE]
  else:
    # this also works for links as it can transfer the energy
    harvestBody = @[WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]
  #uplinkBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]
  uplinkBody = @[WORK, WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]

  # hauling up to 300 energy should be enough
  #haulBody = @[CARRY, CARRY, CARRY, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
  # maybe even 250 is enough. We also move on roads so we need one move less
  haulBody = @[CARRY, CARRY, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE]

  #if room.energyCapacityAvailable >= 1150:
  #  uplinkBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, CARRY, CARRY, MOVE]

  # level 1 or all workers gone, fallback to low energy ones?
  if room.energyCapacityAvailable < 450 or stats.workers.len < 2:
    #body = @[WORK, WORK, CARRY, MOVE]
    workBody = @[WORK, CARRY, CARRY, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 550:
    # 450 - 550
    workBody = @[WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 800:
    # 550 - 800
    workBody = @[WORK, WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE]
    fightBody = @[RANGED_ATTACK, MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 950:
    # 800
    workBody = @[WORK, WORK, WORK, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE]
    # 600
    fightBody = @[RANGED_ATTACK, MOVE, RANGED_ATTACK]
  else:
    # 1400
    #workBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, CARRY, CARRY, CARRY, CARRY,
    #  CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
    # 900
    workBody = @[WORK, WORK, WORK, CARRY, CARRY, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
    # 740
    fightBody = @[TOUGH, TOUGH, TOUGH, TOUGH, MOVE, MOVE, MOVE, RANGED_ATTACK, RANGED_ATTACK, MOVE]
    # 440
    #pirateBody = @[TOUGH, TOUGH, TOUGH, MOVE, MOVE, MOVE, MOVE, ATTACK, ATTACK, MOVE]
    #pirateBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, ATTACK, ATTACK, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]


  let wantWorkers = if stats.uplinkers.len > 0: 3 else: 5
  let wantDefenders = if clevel >= 4: 0 else: 0
  let wantPirates = if clevel >= 5: 0 else: 0
  let wantHaulers = if storages.len > 0: containers.len else: 0  # seems to be enough
  let wantUplinkers = if links.len > 0: 2 else: 0 # seems to be enough
  let wantHarvesters = if clevel >= 2 and containers.len > 0 and stats.workers.len > 2: sources.len else: 0
  #logH "wantHarvesters: " & wantHarvesters

  # this needs to be done differently (global list of rooms to claim for example)
  let wantClaimers = if room.energyCapacityAvailable >= claimBody.calcEnergyCost: 2 else: 0

  # charge handling
  var minChargers = if totalEnergyNeeded.len <= 3: 1 else: totalEnergyNeeded.len div 6
  var maxChargers = if totalEnergyNeeded.len <= 3: 3 else: totalEnergyNeeded.len div 2

  var needCreeps = 0
  var maxUpgraders = 20
  var minUpgraders = if spawns.len > 0: 2 else: 0
  if stats.uplinkers.len > 0:
    maxUpgraders = 4
  #var intrudersDetected = false

  # harvesters
  if stats.harvesters.len < wantHarvesters:
    needCreeps += wantHarvesters - stats.harvesters.len
    # if we have some workers (for charging) we prefer new harvesters
    mySpawn Harvester, harvestBody, needCreeps

  # counting of needed creeps is not yet really ok but better than before
  if stats.workers.len < wantWorkers:
    needCreeps += wantWorkers - stats.workers.len
    mySpawn Worker, workBody, needCreeps

  if stats.defenders.len < wantDefenders:
    needCreeps += wantDefenders - stats.defenders.len
    if stats.workers.len >= wantWorkers:
      mySpawn Defender, fightBody, needCreeps

  # we count pirates global (and currently spwan in any room we own)
  if globalPirates.len < wantPirates:
    needCreeps += wantPirates - globalPirates.len
    if stats.workers.len >= wantWorkers:
      mySpawn Pirate, pirateBody, needCreeps

  # claimers (global)
  if globalClaimers.len < wantClaimers:
    # if we need more than one we get one out if the oldest has only 100 ticks left
    if globalClaimers.len == 0 or globalClaimers[0].ticksToLive < 150:
      needCreeps += wantClaimers - globalClaimers.len
      mySpawn Claimer, claimBody, needCreeps

  if stats.haulers.len < wantHaulers:
    needCreeps += wantHaulers - stats.haulers.len
    mySpawn Hauler, haulBody, needCreeps

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
        log "Missing memory for spawning creep", error
      dec needCreeps

  if needCreeps > 0:
    log room.name & " needs " & needCreeps & " Creeps", info

  # Sort by smalles energy cost for finishing construction
  # Extensions are priorised above walls and rampants
  csites.sort() do (a, b: ConstructionSite) -> int:
    var ea, eb: int
    if a.structureType == STRUCTURE_TYPE_EXTENSION:
      ea = 6
    elif a.structureType == STRUCTURE_TYPE_CONTAINER:
      ea = 5
    elif a.structureType == STRUCTURE_TYPE_TOWER:
      ea = 4
    elif a.structureType == STRUCTURE_TYPE_STORAGE:
      ea = 3
    elif a.structureType == STRUCTURE_TYPE_LINK:
      ea = 2
    else:
      ea = a.progressTotal - a.progress

    if b.structureType == STRUCTURE_TYPE_EXTENSION:
      eb = 6
    elif b.structureType == STRUCTURE_TYPE_CONTAINER:
      eb = 5
    elif b.structureType == STRUCTURE_TYPE_TOWER:
      eb = 4
    elif b.structureType == STRUCTURE_TYPE_STORAGE:
      eb = 3
    elif b.structureType == STRUCTURE_TYPE_LINK:
      eb = 2
    else:
      eb = b.progressTotal - b.progress

    ea - eb

  if csites.len > 0:
    # we need at least one builder in this room
    #log "having", csites.len, "construction sites"
    #for site in csites:
    #  log site.id, " ", site.progressTotal - site.progress

    # shrink the number of repair sites to 4
    if csites.len > 2:
      csites = csites[0..2]

    #for site in csites:
    #  log site.id, site.progressTotal - site.progress, site.structureType

    if stats.building.len < 6: # never more than 6

      if stats.idle.len > 0:
        changeActionToClosest(stats, Idle, Build, csites)

      elif stats.upgrading.len > 0 and stats.upgrading.len > minUpgraders:
        changeActionToClosest(stats, Upgrade, Build, csites)

      elif stats.charging.len > 4:
        changeActionToClosest(stats, Charge, Build, csites)

      elif stats.building.len < 3 and stats.repairing.len > 3:
        changeActionToClosest(stats, Repair, Build, csites)
  elif stats.building.len > 0:
    changeAction(stats, Build, Idle)

  if stats.uplinkers.len > 0:
    minChargers = totalEnergyNeeded.len
    maxChargers = totalEnergyNeeded.len

  #log $$minChargers, maxChargers, totalEnergyNeeded.len, needCreeps, stats.upgrading.len
  #log "needEnergy " & totalEnergyNeeded.len, debug
  if totalEnergyNeeded.len > 0 and stats.charging.len < maxChargers: # never less than 2
    # prioritized answers
    var needEnergy = energyNeeded(room)
    #log "changing to chargers", debug

    if stats.idle.len > 0:
      changeActionToClosest(stats, Idle, Charge, needEnergy)

    if stats.upgrading.len > 1 and (needCreeps > 0 or stats.charging.len < minChargers):
      changeActionToClosest(stats, Upgrade, Charge, needEnergy)

    if stats.building.len > 0 and (stats.charging.len < minChargers or stats.building.len > 3):
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

  if stats.charging.len > minChargers and stats.upgrading.len < 1:
      changeAction(stats, Charge, Upgrade)

  if stats.upgrading.len > maxUpgraders:
    changeAction(stats, Upgrade, Idle)

  if stats.charging.len > maxChargers:
    changeAction(stats, Charge, Idle)

  #let workers = filterCreeps() do (creep: Creep) -> bool:
  #  #echo creep.name
  #  creep.mem(CreepMemory).role == Worker

  # Handle towers if available
  #log "have " & towers.len & " towers", info
  for tower in towers:
    handleTower(tower)

  #log "have " & towers.len & " towers", info
  for link in links:
    handleLink(link)

  var gm = memory.GameMemory
  if  gm.cmd == "toggle stats":
    gm.cmd = nil
    gm.logStats = not gm.logStats

  if gm.logStats or gm.cmd == "show stats":
    if gm.cmd == "show stats":
      gm.cmd = nil
    stats.logInfo globalPirates, globalClaimers

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
        #logH creep.name & " " & distance & " " & resource.amount & " " & free & " " & estimate
        true
      else:
        #log creep.name & " " & distance & " " & resource.amount & " " & free & " " & estimate, debug
        false

    if slurper != nil:
      let cm = slurper.memory.CreepMemory
      cm.refilling = true
      cm.slurpId = resource.id
      log slurper.name & " is Vulture"
      slurper.say "Vulture"
    else:
      log "no slurper"

    log "on the floor is " & resource.amount & " of " & resource.resourceType
