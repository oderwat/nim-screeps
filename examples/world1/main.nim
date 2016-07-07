# Next are my Visual Studio Code - Runner Script commands.
#
# nim build --verbosity:1 --hint[processing]:off --hint[conf]:off
## nim build --verbosity:1 --hint[processing]:off --hint[conf]:off -d:screepsprofiler
#
# world1 example for Screep
#
# (c) 2016 by Hans Raaf of METATEXX GmbH

import system except echo # prevent me using echo instead of log

# screeps module
import screeps
import screeps_utils

# local stuff
import types
import utils_stats

# thats not in github... for reasons
#include piratetarget
when not declared(piratetarget):
  const pirateTarget="".RoomName

import room_control

import role_worker
import role_fighter
import role_pirate

# would work but easier leads to errors I guess
#converter creepMemory(mem: MemoryEntry): CreepMemory = mem.CreepMemory
#converter roomMemory(mem: MemoryEntry): RoomMemory = mem.RoomMemory

screepsLoop: # this conaints the main loop which is exported to the game
  log game.time & " ticks"
  #echo CONSTRUCTION_COST["road"]

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
    log "R.I.P. x", deads
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
        creep.rolePirate pirateTarget
        #creep.say "Hoho!"
      else:
        log "unknown creep role", creep.name
        creep.say "???"
