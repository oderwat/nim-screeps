# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps

#const actionNames = [ "Idle", "Charge", "Build", "Upgrade", "Repair" ]

type
  Roles* = enum
    Worker    # 0
    Defender   # 1
    Pirate    # 2

  Actions* = enum
    Idle      # 0
    Charge    # 1 # also means defernders are pirates
    Build     # 2
    Upgrade   # 3
    Repair    # 4

  CreepMemory* = ref object of MemoryEntry
    role*: Roles
    action*: Actions
    refilling*: bool
    targetId*: cstring # Id of RoomObject
    sourceId*: cstring # which (harvest) source to use
    slurpId*: cstring # where to slurp

  RoomMemory* = ref object of MemoryEntry
    war*: bool

  GameMemory* = ref object of MemoryObj
    cmd*: cstring
    logStats*: bool

const NOROOM* = "".RoomName
