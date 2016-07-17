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
#include piratetarget
when not declared(piratetarget):
  const pirateTarget = NOROOM

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
  logS "received cmd: " & txt, info

screepsLoop: # this conaints the main loop which is exported to the game
  #logS game.time & " ticks (compiled at " & compiletime & ")", info

  #echo CONSTRUCTION_COST["road"]
  registerCmd("cmd", cmdTester)

  # initialize room memory (once)
  for name, rm in memory.rooms:
    if rm.isEmpty:
      log "init room", name
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
      log "Clearing non-existing creep memory:", name

  if deads > 0:
    log "R.I.P.", deads

  # we need to handle pirates and claimers global
  var pirates: seq[Creep] = @[]
  var claimers: seq[Creep] = @[]
  for creep in game.creeps:
    let cm = creep.memory.CreepMemory
    case cm.role:
      of Pirate:
        pirates.add creep
      of Claimer:
        claimers.add creep
      else: discard

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
        let cm = creep.memory.CreepMemory
        if cm.role == Worker:
          cm.sourceId = sources[idx mod sources.len].id
          inc idx
    # the main room controler logic
    roomControl(room, pirates, pirateTarget, claimers)

  var minTicks = 999999
  # let the creeps do their jobs
  for creep in game.creeps:
    if creep.ticksToLive < minTicks:
      minTicks = creep.ticksToLive
    var cm = creep.memory.CreepMemory

    # if pirateTarget != NOROOM:
    #   if cm.role == Defender:
    #     cm.action = Charge
    #     cm.role = Pirate
    # elif cm.role == Pirate and cm.action == Charge:
    #     cm.role = Defender # going home

    case cm.role:
      of Worker:
        creep.roleWorker
        #creep.say actionNames[cm.action.int].cstring
      of Defender:
        creep.roleDefender
        #creep.say "Defender"
      of Pirate:
        creep.rolePirate pirateTarget
        #creep.say "Hoho!"
      of Claimer:
        creep.roleClaimer
        #creep.say "JoinMe!"
      of Harvester:
        creep.roleHarvester
        #creep.say "Schaffe!"
      of Hauler:
        creep.roleHauler
        #creep.say "Brum!"
      of Uplinker:
        creep.roleUplinker
        #creep.say "Schaffe!"
      of Tank:
        creep.roleTank
        #creep.say "Tank"
      of Healer:
        creep.roleHealer
        #creep.say "Healer"
      else:
        log "unknown creep role", creep.name
        creep.say "???"

  if minTicks < 4:
    logS "Next death in " & minTicks & " ticks."
