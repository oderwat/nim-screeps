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
    level*: int
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
  result.level = 1
  result.spawns = 1
  if controller.progressTotal < 45000: return
  result.level = 2
  result.extensions = 5
  result.rampants = 300000
  result.walls = 1000000
  if controller.progressTotal < 135000: return
  result.level = 3
  result.extensions = 10
  result.rampants = 1000000
  result.towers = 1
  # tbc
  return
