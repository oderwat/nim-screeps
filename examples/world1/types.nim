# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps

#const actionNames = [ "Idle", "Charge", "Build", "Upgrade", "Repair" ]

type
  Roles* = enum
    Worker    # 0
    Fighter   # 1
    Pirate    # 2

  Actions* = enum
    Idle      # 0
    Charge    # 1
    Build     # 2
    Upgrade   # 3
    Repair    # 4

  CreepMemory* = ref object of MemoryEntry
    role*: Roles
    action*: Actions
    refilling*: bool
    targetId*: cstring # Id of RoomObject
    sourceId*: cstring # which source to use

  RoomMemory* = ref object of MemoryEntry
    war*: bool

  GameMemory* = ref object of MemoryObj
    cmd*: cstring
    logStats*: bool

const NOROOM* = "".RoomName
