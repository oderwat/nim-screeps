# Next are my Visual Studio Code - Runner Script commands.
#
# nim build --hint[conf]:off
## nim build --hint[conf]:off --d:screepsprofiler
#
# world1 example for Screep
#
# (c) 2016 by Hans Raaf of METATEXX GmbH

import system except echo, log

# screeps module
import screeps
import screeps_utils

# local stuff
import types
import utils_stats

# thats not in github... for reasons
include piratetarget
when not declared(piratetarget):
  const pirateTarget = NOROOM

#const claimTarget = "W38N8".RoomName
when not declared(claimTarget):
  const claimTarget = NOROOM

import room_control

import role_worker
import role_defender
import role_pirate
import role_claimer
import role_harvester
import role_hauler
import role_uplinker
import role_tank
import role_healer

#const compiletime = staticExec("date +'%Y-%m-%d %H:%M:%S'")

# would work but easier leads to errors I guess
#converter creepMemory(mem: MemoryEntry): CreepMemory = mem.CreepMemory
#converter roomMemory(mem: MemoryEntry): RoomMemory = mem.RoomMemory

proc cmdTester(txt: cstring): int =
  memory.GameMemory.cmd = txt
  log "received cmd: " & txt, info

screepsLoop: # this conaints the main loop which is exported to the game
  #log game.time & " ticks (compiled at " & compiletime & ")", info

  #echo CONSTRUCTION_COST["road"]
  registerCmd("cmd", cmdTester)

  # initialize room memory (once)
  for name, rm in memory.rooms:
    if rm.isEmpty:
      log "init room" & name
      var init: RoomMemory
      memory.rooms[name] = init

  var redistribute = false # when workers die
  # Delete for dead creeps from memory
  # Watch out: A new spawn appears first in memory, then in game
  # be careful not to delete memory for your "next" creep
  for name in keys(memory.creeps):
    if not game.creeps.hasKey name:
      if memory.creeps[name].CreepMemory.role == Worker:
        redistribute = true
      memory.creeps.delete name
      log "Clearing non-existing creep memory: " & name

  # we need to handle pirates and claimers global
  gmem.creepStats = game.creeps.stats()

  var wantImigrants = 0
  #if room.name == "W38N8".RoomName and clevel < 5:
    # do we want imigrant workers?
  wantImigrants = 0

  if wantImigrants > 0:
    var candidates: CreepList = @[]
    for creep in game.creeps:
      var cm = creep.memory.CreepMemory
      if cm.imigrant:
        dec wantImigrants
      elif cm.role == Worker:
        # only creeps from our main rooms
        if creep.room.name != "W39N7".RoomName and
            creep.room.name != "W39N8".RoomName and
            creep.room.name != "W38N7".RoomName:
          continue
        if creep.ticksToLive < 1000:
          # no granies
          continue
        candidates.add creep

    logH "imigration needs: " & wantImigrants

    if wantImigrants > 0 and candidates.len > 0:
      # need to send workers to imigration room
      for creep in candidates:
        if wantImigrants <= 0:
          break

        var cm = creep.memory.CreepMemory
        # if it is an imigrand .. ok
        # any creep for now
        cm.action = Migrate
        cm.targetId = nil
        cm.targetRoom = "W38N8".RoomName
        cm.refilling = true
        cm.imigrant = true
        dec wantImigrants
        log creep.name & " was hired"

      # this recalculates and replaces
      # the creepStats objects when
      # emigration hit our system
      gmem.creepStats = game.creeps.stats()


  #
  # Running some tasks and the room Controller for each room we pocess
  #
  for room in game.rooms:
    # skipping room control for rooms we don't own
    if room.controller == nil or room.controller.my == false: continue
    # if we have deads
    if redistribute:
      # redistribute sources
      logH "Distributing sources"
      let sources = room.find(Source)
      let creeps = room.findMy(Creep)
      var idx = 0
      for creep in creeps:
        let cm = creep.cmem
        if cm.role == Worker:
          cm.sourceId = sources[idx mod sources.len].id
          inc idx
    # the main room controler logic
    roomControl(room, pirateTarget, claimTarget)

  var minTicks = 999999
  # let the creeps do their jobs
  for creep in game.creeps:
    if creep.spawning: continue # still spawning
    if creep.ticksToLive < minTicks:
      minTicks = creep.ticksToLive

    case creep.cmem.role:
    of Worker: creep.roleWorker
    of Defender: creep.roleDefender
    of Pirate: creep.rolePirate pirateTarget
    of Claimer: creep.roleClaimer claimTarget
    of Harvester: creep.roleHarvester
    of Hauler: creep.roleHauler
    of Uplinker: creep.roleUplinker
    of Tank: creep.roleTank
    of Healer: creep.roleHealer

  #if minTicks < 4:
  #  log "Next death in " & minTicks & " ticks."
  log ""