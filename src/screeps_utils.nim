# nim check --verbosity:2 --hints:off
#
# screeputils (test imports)
import screeps

proc transferAllCurrentCarry*(src, dst: Creep): int =
  if src.carry == nil:
    return ERR_NOT_ENOUGH_ENERGY

  result = OK;

  for stuff in keys(src.carry):
    result = src.transfer(dst, stuff)
    if result != OK and result != ERR_NOT_ENOUGH_RESOURCES:
      return result

type
  ControllerInfoObj* = object
    processTotal*: int
    roads*: int
    containers*: int
    spawns*: int
    extensions*: int
    rampants*: int
    walls*: int
    towers*: int
    storage*: int
    links*: int
    extractors*: int
    labs*: int
    terminals*: int
    observers*: int
    powerSpawns*: int

  ControllerInfo* = ref ControllerInfoObj

proc info*(controller: StructureController): ControllerInfo =
  result = new ControllerInfo
  result.roads = 1000000 # many
  result.containers = 5
  if controller.progressTotal < 200: return
  result.spawns = 1
  if controller.progressTotal < 45000: return
  result.extensions = 5
  result.rampants = 300000
  result.walls = 1000000
  if controller.progressTotal < 135000: return
  result.extensions = 10
  result.rampants = 1000000
  result.towers = 1
  # tbc
  return

template at*(pos: RoomPosition): cstring = "@(" & $pos.x & "," & $pos.y & ")"
template at*(obj: RoomObject): cstring = at obj.pos

proc travel_old*(creep: Creep, destRoom: RoomName | Room): int =
  # given destRoom and creep
  var route = game.map.findRoute(creep.room, destRoom)
  if route.len == 0:
    return -1

  var exit_dir = route[0].exit
  var exit_arr = creep.room.find(exit_dir)
  if exit_arr.len == 0:
    return -1
  var exit_target = exit_arr[0]
  #dump exit_target
  creep.moveTo(exit_target)

proc travel*(creep: Creep, destRoom: RoomName | Room): int =
  # given destRoom and creep
  when destRoom is Room:
    let roomName = destRoom.name
  else:
    let roomName = destRoom
  var rp = newRoomPosition(25, 25, roomName)
  creep.moveTo(rp)

proc carrySum*(creep: Creep): int =
  result = 0
  for kind, value in creep.carry:
    #console stringify kind
    result += value
