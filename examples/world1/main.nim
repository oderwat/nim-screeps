# nim build --verbosity:1 --hints:off
# run done
#
# world1 example for Screep
#
# (c) 2016 by Hans Raaf of METATEXX GmbH

import screeps

type Roles = enum
  Worker

type Actions = enum
  Idle
  Charge
  Build
  Upgrade

type Stats = ref object
  workers: int
  charging: int
  building: int
  upgrading: int
  idle: int
  error: int

type
  CreepMemory = ref object
    role: Roles
    action: Actions
    refilling: bool
    targetId: cstring # Id of RoomObject
    sourceId: cstring # which source to use

screepsLoop: # this conaints the main loop which is exported to the game

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

  proc roleWorker(creep: Creep) =
    var cm = creep.mem(CreepMemory)

    # so we can act on the same tick
    if creep.carry.energy == 0:
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
        cm.refilling = false
    else:
      var needEnergy = energyNeeded(creep)

      if cm.action == Charge:

        if needEnergy.len > 0:
          if creep.transfer(needEnergy[0], RESOURCE_TYPE_ENERGY) != OK:
            creep.moveTo(needEnergy[0])
        else:
          cm.action = Idle

      elif cm.action == Build:
        var target = game.getObjectById(cm.targetId, ConstructionSite)
        if creep.build(target) != OK:
          creep.moveTo(target)
        else:
          cm.targetId = nil
          cm.action = Idle

      elif cm.action == Upgrade:
        if creep.upgradeController(creep.room.controller) != OK:
          creep.moveTo(creep.room.controller)

      if cm.action == Idle:
          creep.moveTo(game.flags["Flag1"])
          cm.action = Upgrade

      #for target in targets:
      #  echo target.pos.x, " ", target.pos.y, " ", target.structureType, " ", target.id

  proc roomControl(room: Room) =
    # is null for sim
    #let exits = game.map.describeExits(room.name)
    #for k, v in exits:
    #  echo "Exit: ", k, " > ", v

    var body: seq[BodyPart]
    if room.energyCapacityAvailable <= 500:
      #body = @[WORK, WORK, CARRY, MOVE]
      body = @[WORK, CARRY, CARRY, MOVE, MOVE]
    else:
      body = @[WORK, WORK, CARRY, CARRY, MOVE, MOVE, MOVE, MOVE]

    let cost = body.calcEnergyCost

    echo "Room Capacity: ", room.energyAvailable, " / ", room.energyCapacityAvailable

    var stats = new Stats
    let sources = room.find(Source)
    let creeps = room.findMy(Creep)
    var idx = 0
    for creep in creeps:
      let cm = creep.mem(CreepMemory)
      if cm.role == Worker:
        # naive sources "assignment"
        if cm.sourceId == nil:
          cm.sourceId = sources[idx mod sources.len].id
        inc stats.workers

      if cm.action == Charge:
        inc stats.charging
      elif cm.action == Build:
        inc stats.building
      elif cm.action == Upgrade:
        inc stats.upgrading
      elif cm.action == Idle:
        inc stats.idle
      else:
        inc stats.error
      inc idx

    var targets = room.find(ConstructionSite)
    # Sortieren nach "geringster notwendiger Energy zur Fertigstellung"
    targets.sort() do (a, b: ConstructionSite) -> int:
      (a.progressTotal - a.progress) - (b.progressTotal - b.progress)

    if targets.len > 0:
      # we need at least one builder in this room
      echo "having ", targets.len, " construction sites"
      if stats.building < 10: # never more than 10

        if stats.idle > 0:
          for creep in creeps:
            let m = creep.mem(CreepMemory)
            if m.action == Idle:
              m.action = Build
              m.targetId = targets[0].id
              inc stats.building
              dec stats.idle
              break;

        elif stats.upgrading > 2:
          for creep in creeps:
            let m = creep.mem(CreepMemory)
            if m.action == Upgrade:
              m.action = Build
              m.targetId = targets[0].id
              inc stats.building
              dec stats.upgrading
              break;

        elif stats.charging > 4:
          for creep in creeps:
            let m = creep.mem(CreepMemory)
            if m.action == Charge:
              m.action = Build
              m.targetId = targets[0].id
              inc stats.building
              dec stats.charging
              break;

    #for target in targets:
    #  echo target.progressTotal

    #let workers = filterCreeps() do (creep: Creep) -> bool:
    #  #echo creep.name
    #  creep.mem(CreepMemory).role == Worker

    if stats.workers < 10:
      if room.energyAvailable >= cost:
        for spawn in game.spawns:
          let rm = CreepMemory(role: Worker, refilling: true, action: Charge)
          var name = spawn.createCreep(body, nil, rm)
          if name != "":
            echo "New creep ", name, " is spawned"

    dump stats

  # Delete for dead creeps from memory
  # Watch out: A new spawn appears first in memory, then in game
  # be careful not to delete memory for your "next" creep
  for name in keys(memory.creeps):
    #echo "memory: ", name
    #dump game.creeps[name]
    if not game.creeps.hasKey name:
      memory.creeps.delete name
      echo "Clearing non-existing creep memory: ", name

  # Running the room Controller for each room we pocess
  for room in game.rooms:
    roomControl(room)

  # let the creeps do their jobs
  for creep in game.creeps:
    let cm = creep.mem(CreepMemory)
    case cm.role:
      of Worker: creep.roleWorker
      else: echo "unknown creep role ", creep.name
