# nim build --verbosity:1 --hints:off
## nim build --verbosity:1 --hints:off -d:screepsprofiler
# run done
#
# world1 example for Screep
#
# (c) 2016 by Hans Raaf of METATEXX GmbH

import screeps
import screepsutils

# thats not in github... for reasons
#include piratetarget

when not declared(piratetarget):
  const piratetarget="".RoomName

type Roles = enum
  Worker    # 0
  Fighter   # 1
  Pirate    # 2

type Actions = enum
  Idle      # 0
  Charge    # 1
  Build     # 2
  Upgrade   # 3
  Repair    # 4

#const actionNames = [ "Idle", "Charge", "Build", "Upgrade", "Repair" ]

type Stats = ref object
  workers: int
  fighters: int
  pirates: int
  charging: int
  building: int
  upgrading: int
  repairing: int
  idle: int
  refilling: int
  error: int

type
  CreepMemory = ref object of MemoryEntry
    role: Roles
    action: Actions
    refilling: bool
    targetId: cstring # Id of RoomObject
    sourceId: cstring # which source to use

  RoomMemory = ref object of MemoryEntry
    war: bool

# would work but easier leads to errors I guess
#converter creepMemory(mem: MemoryEntry): CreepMemory = mem.CreepMemory
#converter roomMemory(mem: MemoryEntry): RoomMemory = mem.RoomMemory

proc energyNeeded(creep: Creep): auto =
  result = creep.room.find(Structure) do (struct: Structure) -> bool:
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

proc handleRepairs(room: Room, creeps: seq[Creep], stats: var Stats) =
  var repairs = room.find(Structure) do (s: Structure) -> bool:
    s.hits < s.hitsMax

  # sort by structures with fewest health
  repairs.sort() do (a, b: Structure) -> int:
    a.hits - b.hits

  if repairs.len > 0:
    # we need at least one builder in this room
    echo "having ", repairs.len, " structures to repair"

    # shrink the number of repair sites to 4
    if repairs.len > 4:
      repairs = repairs[0..3]

    for site in repairs:
      echo site.id, " ", site.hits, " ", site.structureType

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
          echo "no closest for ", creep.name, " ?"
          m.action = Idle
          m.targetId = nil

proc roleWorker(creep: Creep) =
  var cm = creep.memory.CreepMemory # convert

  # so we can act on the same tick
  if creep.carry.energy == 0 and not cm.refilling:
    creep.say "Empty"
    cm.refilling = true

  if cm.refilling == true:
    if creep.carry.energy < creep.carryCapacity:
      var source = game.getObjectById(cm.sourceId, Source)
      let ret = creep.harvest(source)
      if ret == ERR_NOT_IN_RANGE:
        creep.moveTo(source)
      elif ret != OK and ret != ERR_BUSY:
        echo creep.name, " is lost: ", ret
    else:
      #echo creep.name, " is now full"
      creep.say "Full"
      cm.refilling = false
  else:
    var needEnergy = energyNeeded(creep)
    # need some kind of priority list here
    if cm.action == Charge:
      if needEnergy.len > 0:
        let target = needEnergy[0]
        #echo "Charging: ", target.structureType, at target.pos
        if creep.transfer(target, RESOURCE_TYPE_ENERGY) != OK:
          creep.moveTo(target)
      else:
        cm.action = Idle

    elif cm.action == Build:
      var target = game.getObjectById(cm.targetId, ConstructionSite)
      if creep.build(target) != OK:
        if creep.moveTo(target) == ERR_INVALID_TARGET:
          cm.targetId = nil
          cm.action = Idle
      elif target.progress == target.progressTotal:
        cm.targetId = nil
        cm.action = Idle

    elif cm.action == Repair:
      var target = game.getObjectById(cm.targetId, Structure)
      if creep.repair(target) != OK:
        if creep.moveTo(target) == ERR_INVALID_TARGET:
          cm.targetId = nil
          cm.action = Idle
      elif target.hits == target.hitsMax:
        cm.targetId = nil
        cm.action = Idle

    elif cm.action == Upgrade:
      # just for now
      if needEnergy.len > 0:
        cm.action = Charge
      else:
        if creep.upgradeController(creep.room.controller) != OK:
          creep.moveTo(creep.room.controller)

    if cm.action == Idle:
      if needEnergy.len > 0:
        cm.action = Charge
      else:
        cm.action = Upgrade

    #for target in targets:
    #  echo target.pos.x, " ", target.pos.y, " ", target.structureType, " ", target.id

proc roleFighter(creep: Creep) =
  #var cm = creep.mem(CreepMemory)

  var hostiles = creep.room.findHostile(CREEP)
  #echo "Have ", hostiles.len, " hostiles"
  if hostiles.len > 0:
    var closest = creep.pos.findClosestByPath(hostiles)
    if closest == nil:
      #echo "hostile direct path"
      closest = creep.pos.findClosestByRange(hostiles)

    if closest == nil:
      echo "this should not happen (155)"
      closest = hostiles[0]

    if creep.rangedAttack(closest) != OK:
      var ret = creep.moveTo(closest)
      echo creep.name, " moves to attack (", ret, ")"

  else:
    creep.moveTo(game.flags.Flag1)

proc rolePirate(creep: Creep) =
  #var cm = creep.mem(CreepMemory)

  var hostiles = creep.room.findHostile(CREEP)
  #echo "Have ", hostiles.len, " hostiles"
  if hostiles.len > 0:
    var closest = creep.pos.findClosestByPath(hostiles)
    if closest == nil:
      #echo "hostile direct path"
      closest = creep.pos.findClosestByRange(hostiles)

    if closest == nil:
      echo "this should not happen (155)"
      closest = hostiles[0]

    if creep.rangedAttack(closest) != OK:
      var ret = creep.moveTo(closest)
      echo creep.name, " moves to attack (", ret, ")"

  else:
    if pirateTarget != "":
      echo travel(creep, pirateTarget)
    else:
      creep.moveTo(game.flags.Flag1)

proc roomControl(room: Room) =
  # is null for sim
  #let exits = game.map.describeExits(room.name)
  #for k, v in exits:
  #  echo "Exit: ", k, " > ", v

  var rm = room.memory.RoomMemory
  #rm.war = true
  let war = true

  let cinfo = room.controller.info()

  echo "Room Capacity: ", room.energyAvailable, " / ", room.energyCapacityAvailable

  var stats = new Stats
  let sources = room.find(Source)
  let creeps = room.findMy(Creep)
  var idx = 0
  for creep in creeps:
    let cm = creep.memory.CreepMemory
    if cm.role == Worker:
      # naive sources "assignment"
      if cm.sourceId == nil:
        cm.sourceId = sources[idx mod sources.len].id
      inc stats.workers
      inc idx

      if cm.action == Charge:
        inc stats.charging
      elif cm.action == Build:
        inc stats.building
      elif cm.action == Upgrade:
        inc stats.upgrading
      elif cm.action == Repair:
        inc stats.repairing
      elif cm.action == Idle:
        inc stats.idle
      else:
        inc stats.error
      if cm.refilling:
        inc stats.refilling

    elif cm.role == Fighter:
      inc stats.fighters

    elif cm.role == Pirate:
      inc stats.pirates

  var workBody: seq[BodyPart]
  var fightBody: seq[BodyPart]
  var pirateBody: seq[BodyPart]

  # just for fun :)
  pirateBody = @[ATTACK, ATTACK, MOVE, MOVE]

  # level 1 or all workers gone?
  if room.energyCapacityAvailable < 450 or stats.workers < 2:
    #body = @[WORK, WORK, CARRY, MOVE]
    workBody = @[WORK, CARRY, CARRY, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  elif room.energyCapacityAvailable < 550:
    workBody = @[WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[MOVE, RANGED_ATTACK]
  else:
    workBody = @[WORK, WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE]
    fightBody = @[RANGED_ATTACK, MOVE, RANGED_ATTACK]

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
    echo "having ", csites.len, " construction sites"
    #for site in csites:
    #  echo site.id, " ", site.progressTotal - site.progress

    # shrink the number of repair sites to 4
    if csites.len > 2:
      csites = csites[0..2]

    for site in csites:
      echo site.id, " ", site.progressTotal - site.progress, " ", site.structureType

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

    if stats.charging < 3: # never less than 3

      if stats.idle > 0:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Idle:
            m.action = Charge
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.charging
            dec stats.idle
            break;

      elif stats.upgrading > 2:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Upgrade:
            m.action = Charge
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.charging
            dec stats.upgrading
            break;

      elif stats.building > 3:
        for creep in creeps:
          let m = creep.memory.CreepMemory
          if m.action == Build:
            m.action = Charge
            var closest = creep.pos.findClosestByPath(csites)
            m.targetId = closest.id
            inc stats.charging
            dec stats.building
            break;

  if cinfo.level >= 2:
    handleRepairs(room, creeps, stats)

  #let workers = filterCreeps() do (creep: Creep) -> bool:
  #  #echo creep.name
  #  creep.mem(CreepMemory).role == Worker

  if cinfo.level >= 2 and stats.fighters < 4 and stats.workers >= 2:
    echo "need fighters (", fightBody.calcEnergyCost, " / ", room.energyAvailable, ")"
    if room.energyAvailable >=  fightBody.calcEnergyCost:
      for spawn in game.spawns:
        let rm = CreepMemory(role: Fighter, refilling: true, action: Charge)
        var name = spawn.createCreep(fightBody, nil, rm)
        dump name
        echo "New Fighter ", name, " is spawning"
  elif stats.workers < 14:
    echo "need workers (", workBody.calcEnergyCost, " / ", room.energyAvailable, ")"
    if room.energyAvailable >=  workBody.calcEnergyCost:
      for spawn in game.spawns:
        let rm = CreepMemory(role: Worker, refilling: true, action: Idle)
        var name = spawn.createCreep(workBody, nil, rm)
        dump name
        echo "New Worker ", name, " is spawning"
  elif cinfo.level >= 3 and stats.pirates < 1:
    echo "need pirates (", fightBody.calcEnergyCost, " / ", room.energyAvailable, ")"
    if room.energyAvailable >=  pirateBody.calcEnergyCost:
      for spawn in game.spawns:
        let rm = CreepMemory(role: Pirate, refilling: true, action: Idle)
        var name = spawn.createCreep(pirateBody, nil, rm)
        dump name
        echo "New Pirate ", name, " is spawning"

  # Handle towers if available
  var towers = room.find(StructureTower) do(a: StructureTower) -> bool:
    a.structureType == STRUCTURE_TYPE_TOWER

  echo "have ", towers.len, " towers"
  for tower in towers:
    var closestHostile = tower.findClosestHostileByRange(Creep)
    if closestHostile != nil:
      tower.attack(closestHostile)
    elif tower.energy > tower.energyCapacity div 2:
      var closestDamagedStructure = tower.findClosestByRange(Structure) do(structure: Structure) -> bool:
        # Tower repairs if hits are below 20 percent
        if structure.structureType == STRUCTURE_TYPE_TOWER:
          return false

        if structure.structureType == STRUCTURE_TYPE_CONTROLLER:
          return structure.hits < structure.hitsMax

        if structure.structureType == STRUCTURE_TYPE_SPAWN:
          return structure.hits < structure.hitsMax

        if structure.structureType == STRUCTURE_TYPE_EXTENSION:
          return structure.hits < structure.hitsMax

        if structure.structureType == STRUCTURE_TYPE_WALL:
          return structure.hits < 20000

        if structure.structureType == STRUCTURE_TYPE_RAMPART:
          return structure.hits < 30000

        if structure.structureType == STRUCTURE_TYPE_ROAD:
          return structure.hits < structure.hitsMax div 2

        dump structure.structureType
        structure.hits < structure.hitsMax div 5

      if closestDamagedStructure != nil:
        tower.repair(closestDamagedStructure)

  # show what we have right now
  dump stats

screepsLoop: # this conaints the main loop which is exported to the game
  console "tick " & $game.time
  #echo CONSTRUCTION_COST["road"]

  # initialize room memory (once)
  for name, rm in memory.rooms:
    if rm.isEmpty:
      echo "init room ", name
      var init: RoomMemory
      memory.rooms[name] = init

  var deads = 0
  var redistribute = false # when workers die
  # Delete for dead creeps from memory
  # Watch out: A new spawn appears first in memory, then in game
  # be careful not to delete memory for your "next" creep
  for name in keys(memory.creeps):
    #echo "memory: ", name
    #dump game.creeps[name]
    if not game.creeps.hasKey name:
      #var creepsmem = memory.creepsMem(CreepMemory)
      if memory.creeps[name].CreepMemory.role == Worker:
        redistribute = true
      memory.creeps.delete name
      inc deads
      echo "Clearing non-existing creep memory: ", name

  if deads > 0:
    echo "R.I.P. x ", deads
  #
  # Running some tasks and the room Controller for each room we pocess
  #
  for room in game.rooms:
    # if we have deads
    if redistribute:
      # redistribute sources
      let sources = room.find(Source)
      let creeps = room.findMy(Creep)
      var idx = 0
      for creep in creeps:
        let cm = creep.memory.CreepMemory
        if cm.role == Worker:
          cm.sourceId = sources[idx mod sources.len].id
          inc idx
    # the main room controler logic
    roomControl(room)


  # let the creeps do their jobs
  for creep in game.creeps:
    let cm = creep.memory.CreepMemory
    case cm.role:
      of Worker:
        creep.roleWorker
        #creep.say actionNames[cm.action.int].cstring
      of Fighter:
        creep.roleFighter
        #creep.say "Fighter"
      of Pirate:
        creep.rolePirate
        #creep.say "Hoho!"
      else:
        echo "unknown creep role ", creep.name
        creep.say "???"
