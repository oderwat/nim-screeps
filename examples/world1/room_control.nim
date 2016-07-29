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
          # need to update the stats immediatly
          # but we do not have a real entry for them this tick so I fake one
          room.rmem.creepStats.add rm, nil
          gmem.creepStats.add rm, nil
          break

        elif ret != ERR_BUSY:
          log "Trying to spawn yields error " & ret, error # of course

proc roomControl*(room: Room, pirateTarget, claimTarget: RoomName) =
  # is null for sim
  #let exits = game.map.describeExits(room.name)
  #for k, v in exits:
  #  echo "Exit: ", k, " > ", v

  var rm = room.rmem
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

  # initisl creepStats for the room
  room.rmem.creepStats = creeps.stats()

  let totalEnergyNeeded = energyNeededTotal(room)

  var wantImigrants = 0
  if room.name == "W39N8".RoomName and clevel < 4:
    # do we want imigrant workers?
    wantImigrants = 4

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

        # only creeps from our main rooms
        if creep.room.name != "W39N7".RoomName and creep.room.name != "W38N7".RoomName:
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

      # this recalculates and replaces
      # the creepStats objects when
      # emigration hit our system
      room.rmem.creepStats = creeps.stats()
      gmem.creepStats = game.creeps.stats()

  var idx = 0
  for creep in creeps:
    let cm = creep.memory.CreepMemory
    if cm.role == Worker:
      # naive sources "assignment"
      inc idx
      if cm.sourceId == nil:
        cm.sourceId = sources[idx mod sources.len].id

  # this is the real current creepStats after possible migrations
  let rstats = room.rmem.creepStats
  let gstats = gmem.creepStats

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
  #uplinkBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]
  uplinkBody = @[WORK, WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]

  # hauling up to 300 energy should be enough
  #haulBody = @[CARRY, CARRY, CARRY, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE, MOVE]
  # maybe even 250 is enough. We also move on roads so we need one move less
  haulBody = @[CARRY, CARRY, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE]

  #if room.energyCapacityAvailable >= 1150:
  #  uplinkBody = @[WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, WORK, CARRY, CARRY, MOVE]

  # level 1 or all workers gone, fallback to low energy ones?
  if room.energyCapacityAvailable < 450 or rstats.workers.len < 2:
    #body = @[WORK, WORK, CARRY, MOVE]
    workBody = @[WORK, CARRY, CARRY, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 700:
    # 550 upgrade (level 2)
    workBody = @[WORK, WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE]

    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 800:
    # 600
    workBody = @[WORK, WORK, WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE]
    # 550
    fightBody = @[RANGED_ATTACK, MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 900:
    # 700
    workBody = @[WORK, WORK, WORK, WORK, CARRY, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE, MOVE]
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


  var wantWorkers = if rstats.uplinkers.len > 0: 3 else: 5
  if clevel < 4:
    wantWorkers = 10

  let wantDefenders = if clevel >= 4: 0 else: 0
  let wantPirates = if clevel >= 5: 0 else: 0
  let wantHaulers = if storages.len > 0: containers.len else: 0  # seems to be enough
  let wantUplinkers = if links.len > 0: 2 else: 0 # seems to be enough
  let wantHarvesters = if clevel >= 2 and containers.len > 0 and rstats.workers.len >= 2: sources.len else: 0
  #logH "wantHarvesters: " & wantHarvesters

  if wantHarvesters > 0:
    #log "we want harvesters " & wantHarvesters
    # harvest body
    if clevel < 3:
      # check if we have a container building site near the sources
      var needCarryOnHarvester = false
      for source in sources:
        let near = source.pos.findClosestByPath(ConstructionSite) do(site: ConstructionSite) -> bool:
          site.structureType == STRUCTURE_TYPE_CONTAINER
        if near != nil:
          if not source.pos.inRangeTo(near,2): continue # no? check the next source
          needCarryOnHarvester = true

      if needCarryOnHarvester:
        # we need a carry part but only till we build our container
        harvestBody = @[WORK, WORK, WORK, WORK, CARRY, MOVE, MOVE]
      else:
        # no carry so it only works with containers (not for links)
        # but there are not links with clevel < 3
        harvestBody = @[WORK, WORK, WORK, WORK, WORK, MOVE]

    else:
      # this also works for links as it can transfer the energy
      harvestBody = @[WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]


  var wantClaimers = 0

  # @Araq: If I take the "RoomName" away the compiler crashes!
  # was "W39N8".RoomName
  let claimRoom = game.rooms[claimTarget]
  if claimRoom != nil:
    if claimRoom.controller.my == false:
      wantClaimers = if room.energyCapacityAvailable >= claimBody.calcEnergyCost: 2 else: 0

  #log "want Claimers: " & wantClaimers, debug

  # charge handling
  var minChargers = 0
  var maxChargers = 0
  if totalEnergyNeeded.len > 0:
    minChargers = if totalEnergyNeeded.len <= 6: 1 else: totalEnergyNeeded.len div 6
    maxChargers = if totalEnergyNeeded.len <= 2: 1 else: totalEnergyNeeded.len div 2
    # max what we have though
    if minChargers > wantWorkers: minChargers = wantWorkers
    if maxChargers > wantWorkers: maxChargers = wantWorkers

  var maxUpgraders = 10
  var minUpgraders = if spawns.len > 0: 2 else: 0
  if rstats.uplinkers.len > 0:
    maxUpgraders = 4
    minUpgraders = 0 # not needed anymore

  if minUpgraders > wantWorkers: minUpgraders = wantWorkers
  if maxUpgraders > wantWorkers: maxUpgraders = wantWorkers

  var minBuilders = 0 # normaly none
  var maxBuilders = 0

  var needCreeps = 0

  # harvesters
  if rstats.harvesters.len < wantHarvesters:
    needCreeps += wantHarvesters - rstats.harvesters.len
    # if we have some workers (for charging) we prefer new harvesters
    mySpawn Harvester, harvestBody, needCreeps

  # counting of needed creeps is not yet really ok but better than before
  if rstats.workers.len < wantWorkers:
    needCreeps += wantWorkers - rstats.workers.len
    mySpawn Worker, workBody, needCreeps

  if rstats.defenders.len < wantDefenders:
    needCreeps += wantDefenders - rstats.defenders.len
    if rstats.workers.len >= wantWorkers:
      mySpawn Defender, fightBody, needCreeps

  # we count pirates global (and currently spwan in any room we own)
  if gstats.pirates.len < wantPirates:
    needCreeps += wantPirates - gstats.pirates.len
    if rstats.workers.len >= wantWorkers:
      mySpawn Pirate, pirateBody, needCreeps

  # claimers (global)
  if gstats.claimers.len < wantClaimers:
    # if we need more than one we get one out if the oldest has only 100 ticks left
    if gstats.claimers.len == 0 or gstats.claimers[0].ticksToLive < 150:
      needCreeps += wantClaimers - gstats.claimers.len
      mySpawn Claimer, claimBody, needCreeps

  if rstats.haulers.len < wantHaulers:
    needCreeps += wantHaulers - rstats.haulers.len
    mySpawn Hauler, haulBody, needCreeps

  if rstats.uplinkers.len < wantUplinkers:
    needCreeps += sources.len - rstats.harvesters.len
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
    minBuilders = 1
    maxBuilders = wantWorkers - minChargers
    if maxBuilders < 0: maxBuilders = 0

    #log "Max Builder: " & maxBuilders

    #log "having", csites.len, "construction sites"
    #for site in csites:
    #  log $$site.id & " " & site.structureType & " " & site.progressTotal - site.progress

    # shrink the number of build sites to 4
    if csites.len > 4:
      csites = csites[0..4]
      minBuilders = 2

    #for site in csites:
    #  log $$site.id & " " & site.structureType & " " & site.progressTotal - site.progress

    if rstats.building.len < maxBuilders:

      if rstats.idle.len > 0:
        changeActionToClosest(rstats, Idle, Build, csites)

      # better build than upgrade
      elif rstats.upgrading.len > 0 and rstats.upgrading.len > minUpgraders and rstats.building.len < maxBuilders:
        changeActionToClosest(rstats, Upgrade, Build, csites)

      # better build than repair
      elif rstats.repairing.len > 0 and rstats.building.len < minBuilders:
        changeActionToClosest(rstats, Repair, Build, csites)

      # better charge but have minimum builders
      elif rstats.charging.len > 0 and
          ((rstats.charging.len > minChargers and rstats.building.len < minBuilders) or
          (minChargers == 0 and rstats.building.len < maxBuilders)):
        changeActionToClosest(rstats, Charge, Build, csites)

  elif rstats.building.len > 0:
    changeAction(rstats, Build, Idle)

  log "minChg: " &  minChargers & " maxChg: " & maxChargers & " totENeed: " & totalEnergyNeeded.len & " creepNeed: " & needCreeps & " minUpgr: " & minUpgraders & " upgraders: " & rstats.upgrading.len
  #log "needEnergy " & totalEnergyNeeded.len, debug
  if totalEnergyNeeded.len > 0 and rstats.charging.len < maxChargers:
    # prioritized answers
    var needEnergy = energyNeeded(room)
    #log "changing to chargers / needEnergy: " & needEnergy.len, debug

    if rstats.idle.len > 0:
      changeActionToClosest(rstats, Idle, Charge, needEnergy)

    if rstats.upgrading.len > 0 and (needCreeps > 0 or rstats.charging.len < minChargers):
      changeActionToClosest(rstats, Upgrade, Charge, needEnergy)

    if rstats.building.len > 0 and (needCreeps > 0 or rstats.charging.len < minChargers):
      changeActionToClosest(rstats, Build, Charge, needEnergy)

    if rstats.repairing.len > 0 and (needCreeps > 0 or rstats.charging.len < minChargers):
      changeActionToClosest(rstats, Repair, Charge, needEnergy)

  # we stop repairs if creeps are needed and there are to few chargers yet
  if clevel >= 2 and needCreeps == 0 and rstats.charging.len >= minChargers:
    handleRepairs(room, creeps, rstats, minUpgraders, minChargers, minBuilders)

  # no creeps needed and enough chargers available. move others to Upgrader
  if needCreeps == 0 and
    rstats.charging.len > minChargers and rstats.upgrading.len < minUpgraders:
      changeAction(gstats, Charge, Upgrade)

  if rstats.charging.len > minChargers and rstats.upgrading.len < minUpgraders:
      changeAction(gstats, Charge, Upgrade)

  if rstats.upgrading.len > maxUpgraders:
    changeAction(gstats, Upgrade, Idle)

  if rstats.charging.len > maxChargers:
    changeAction(gstats, Charge, Idle)

  # if we have idle creeps let them upgrade
  if rstats.idle.len > 0 and rstats.upgrading.len < maxUpgraders:
    changeAction(gstats, Idle, Upgrade)

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
    rstats.logInfo

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
      # todo:
      # for now we do not use creeps which are currently working
      # to temporarily fix problems with overflowing containers
      if cm.refilling == false: return false

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
      if resource.amount > 500:
        log "Energy amass laying around"
      log "no slurper"

    log "on the floor is " & resource.amount & " of " & resource.resourceType

  log ""