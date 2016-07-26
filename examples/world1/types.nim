# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps

#const actionNames = [ "Idle", "Charge", "Build", "Upgrade", "Repair" ]

type
  Roles* = enum
    Worker      # 0 # Multi purpose Creeps for early room development
    Defender    # 1 # Long Range defender to watch over the room
    Pirate      # 2 # Just some fun
    Claimer     # 3 # Attacks + Reservers + Claims a RoomController
    Tank        # 4 #
    Healer      # 5 #
    Harvester   # 6 # harvests source and deploys in link or container
    Uplinker    # 7 # uses link energy for upgrading
    Hauler      # 8 # Transports energy from containers to storage

  Actions* = enum
    Idle      # 0
    Charge    # 1 # also means defernders are pirates
    Build     # 2
    Upgrade   # 3
    Repair    # 4
    Migrate   # 5

  CreepStats* = ref object
    workers*: seq[Creep]
    defenders*: seq[Creep]
    pirates*: seq[Creep]
    claimers*: seq[Creep]
    harvesters*: seq[Creep]
    uplinkers*: seq[Creep]
    haulers*: seq[Creep]
    charging*: seq[Creep]
    building*: seq[Creep]
    upgrading*: seq[Creep]
    repairing*: seq[Creep]
    idle*: seq[Creep]
    refilling*: seq[Creep]
    migrating*: seq[Creep]
    error*: seq[Creep]

  CreepMemory* = ref object of MemoryEntry
    role*: Roles
    action*: Actions
    targetId*: ObjId # Id of RoomObject
    refilling*: bool
    sourceId*: ObjId # which (harvest) source to use
    slurpId*: ObjId # where to slurp (floor or container)
    imigrant*: bool # are we from a different rooms spawn?

  RoomMemory* = ref object of MemoryEntry
    creepStats*: CreepStats # contains creeps from this room
    sourceLinks*: seq[ObjId]
    sourceContainers*: seq[ObjId]

  GameMemory* = ref object of MemoryObj
    creepStats*: CreepStats # contains creeps from all rooms
    cmd*: cstring
    logStats*: bool

const NOROOM* = "".RoomName

# some helpers to make it easier to write and read memory access

template gmem*(): GameMemory = GameMemory(memory)
template rmem*(creep: Creep): RoomMemory = RoomMemory(creep.room.memory)
template rmem*(room: Room): RoomMemory = RoomMemory(room.memory)
template cmem*(creep: Creep): CreepMemory = CreepMemory(creep.memory)
