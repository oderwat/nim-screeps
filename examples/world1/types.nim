# nop
# run nim build --hint[conf]:off main.nim

import system except echo, log

import screeps

#const actionNames = [ "Idle", "Charge", "Build", "Upgrade", "Repair" ]

type
  Roles* = enum
    Worker      # 0
    Defender    # 1
    Pirate      # 2
    Claimer     # 3
    Tank        # 4
    Healer      # 5
    Harvester   # 6
    Transporter # 7

  Actions* = enum
    Idle      # 0
    Charge    # 1 # also means defernders are pirates
    Build     # 2
    Upgrade   # 3
    Repair    # 4


  CreepMemory* = ref object of MemoryEntry
    role*: Roles
    action*: Actions
    targetId*: cstring # Id of RoomObject
    refilling*: bool
    sourceId*: cstring # which (harvest) source to use
    slurpId*: cstring # where to slurp (floor or container)

  RoomMemory* = ref object of MemoryEntry
    war*: bool

  GameMemory* = ref object of MemoryObj
    cmd*: cstring
    logStats*: bool

const NOROOM* = "".RoomName
