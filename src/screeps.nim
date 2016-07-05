# nim check --verbosity:1 --hints:off
# run nim build --verbosity:1 --hints:off main.nim
# run done
#
# Screeps Nim module
#
# (c) 2016 by Hans Raaf of METATEXX GmbH

import macros

proc console*(txt: cstring) {.importc: "console.log".}
proc stringify*[T](x: T): cstring {.importc: "JSON.stringify".}

proc dump*[T](x: T) = console stringify x

template screepsLoop*(code: untyped): untyped =
  proc screepsLoop() {.exportc.} =
    code
  {.emit: "module.exports.loop = screepsLoop\n".}

type
  JSAssoc*[Key, Val] = ref object

  JsObj* = ref object ## can be a string, an int etc.

  # Types which are just "strings" in javscript
  BodyPart* = distinct cstring
  StructureType* = distinct cstring
  ResourceType* = distinct cstring
  ModeType* = distinct cstring
  LookType* = distinct cstring

  GlobalControlLevelObj {.exportc.} = object
    level*: int
    progress*: int
    progressTotal*: int

  GlobalControlLevel* = ref GlobalControlLevelObj

  MapObj* {.exportc.} = object
  Map* = ref MapObj

  GameObj*  {.exportc.} = object
    rooms*: JSAssoc[cstring, Room]
    spawns*: JSAssoc[cstring, StructureSpawn]
    creeps*: JSAssoc[cstring, Creep]
    flags*: JSAssoc[cstring, Flag]
    gcl*: GlobalControlLevel
    map*: Map

  Game* = ref GameObj

  #MemoryEntryObj* = object
  MemoryEntry* = ref object of RootObj #MemoryEntryObj

  MemoryObj*  {.exportc.} = object
    creeps*: JSAssoc[cstring, MemoryEntry]
    rooms*:  JSAssoc[cstring, MemoryEntry]

  Memory* = ref MemoryObj

  InvadersObj*  {.exportc.} = ref object
    bodies*: seq[cstring]

  Invaders* = ref InvadersObj

  SurvivalInfoObj* {.exportc.} = object
    mode*: cstring
    status*: cstring
    user*: cstring
    score*: int
    timeToWave*: int
    wave*: int
    survivalEnabled*: bool
    invaders*: Invaders

  SurvivalInfo* = ref SurvivalInfoObj

  UserObj* {.exportc.} = object
    username*: cstring

  User* = ref UserObj

  RoomObj* {.exportc.} = object
    name*: cstring
    mode*: cstring
    memory*: MemoryEntry
    controller*: StructureController
    storage*: pointer
    terminal*: pointer
    energyAvailable*: int
    energyCapacityAvailable*: int
    survivalInfo*: SurvivalInfo

  Room* = ref RoomObj

  RoomPositionObj* {.exportc.} = object
    x*: int
    y*: int
    roomName*: cstring

  RoomPosition* = ref RoomPositionObj

  RoomObjectObj* = object of RootObj
    room*: Room
    pos*: RoomPosition

  RoomObject* = ref RoomObjectObj

  ConstructionSiteObj* {.exportc.} = object of RoomObjectObj
    id*: cstring
    my*: bool
    owner*: User
    progress*: int
    progressTotal*: int
    structureType*: StructureType

  ConstructionSite* = ref ConstructionSiteObj

  CreepObj* {.exportc.} = object of RoomObjectObj
    name*: cstring
    body*: seq[BodyPart]
    memory*: MemoryEntry
    carry*: JSAssoc[ResourceType, int]
    carryCapacity*: int

  Creep* = ref CreepObj

  FlagObj* {.exportc.} =  object of RoomObjectObj
    name*: cstring
    color*: cstring
    secondaryColor*: cstring
    memory*: pointer

  Flag* = ref FlagObj

  # TODO: Mineral
  # TODO: Nuke
  # TODO: Resource

  SourceObj* {.exportc.} =  object of RoomObjectObj
    energy*: int
    energyCapacity*: int
    id*: cstring
    ticksToRegeneration*: int

  Source* = ref SourceObj

  StructureObj* {.exportc.} =  object of RoomObjectObj
    hits*: int
    hitsMax*: int
    id*: cstring
    structureType*: StructureType

  Structure* = ref StructureObj

  OwnedStructureObj* = object of StructureObj
    my*: bool
    owner*: User

  OwnedStructure* = ref OwnedStructureObj

  # we use this for stuff which carries energy
  EnergizedStructureObj* {.exportc.} = object of OwnedStructureObj
    energy*: int
    energyCapacity*: int

  EnergizedStructure* = ref EnergizedStructureObj

  StructureControllerObj* {.exportc.} = object of StructureObj
    progress*: int
    progressTotal*: int
    reservation*: pointer
    ticksToDowngrade*: int
    upgradeBlocked*: int

  StructureController* = ref StructureControllerObj

  StructureExtensionObj* = object of EnergizedStructureObj
  StructureExtension* = ref StructureExtensionObj

  # TODO: StructureExtractor
  # TODO: StructureKeeperLair
  # TODO: StructureLab
  # TODO: StructureLink
  # TODO: StructureNuker
  # TODO: StructureObserver
  # TODO: StructurePowerBank
  # TODO: StructurePoweSpawn
  # TODO: StructureRampart

  StructureSpawnObj* = object of EnergizedStructureObj
    name*: cstring
    spawning*: pointer

  StructureSpawn* = ref StructureSpawnObj

  # TODO: StructureStorage
  # TODO: StructureTerminal

  StructureTowerObj* = object of EnergizedStructureObj
  StructureTower* = ref StructureTowerObj

  # TODO: StructureContainer
  # TODO: StructurePortal
  # TODO: StructureRoad
  # TODO: StructureWall

  FindTargets* = enum
    FIND_EXIT_TOP = 1
    FIND_EXIT_RIGHT = 3
    FIND_EXIT_BOTTOM = 5
    FIND_EXIT_LEFT = 7
    FIND_EXIT = 10
    FIND_CREEPS = 101
    FIND_MY_CREEPS = 102
    FIND_HOSTILE_CREEPS = 103
    FIND_SOURCES_ACTIVE = 104
    FIND_SOURCES = 105
    FIND_DROPPED_ENERGY = 106
    FIND_STRUCTURES = 107
    FIND_MY_STRUCTURES = 108
    FIND_HOSTILE_STRUCTURES = 109
    FIND_FLAGS = 110
    FIND_CONSTRUCTION_SITES = 111
    FIND_MY_SPAWNS = 112
    FIND_HOSTILE_SPAWNS = 113
    FIND_MY_CONSTRUCTION_SITES = 114
    FIND_HOSTILE_CONSTRUCTION_SITES = 115
    FIND_MINERALS = 116
    FIND_NUKES = 117

  Directions* = enum
    TOP = 1
    TOP_RIGHT = 2
    RIGHT = 3
    BOTTOM_RIGHT = 4
    BOTTOM = 5
    BOTTOM_LEFT = 6
    LEFT = 7
    TOP_LEFT = 8

  Colors* = enum
    COLOR_RED = 1
    COLOR_PURPLE = 2
    COLOR_BLUE = 3
    COLOR_CYAN = 4
    COLOR_GREEN = 5
    COLOR_YELLOW = 6
    COLOR_ORANGE = 7
    COLOR_BROWN = 8
    COLOR_GREY = 9
    COLOR_WHITE = 10

template FIND_DROPPED_RESOURCES* = FIND_DROPPED_ENERGY

const OK* = 0
const ERR_NOT_OWNER* = -1
const ERR_NO_PATH* = -2
const ERR_NAME_EXISTS* = -3
const ERR_BUSY* = -4
const ERR_NOT_FOUND* = -5
const ERR_NOT_ENOUGH_ENERGY* = -6
const ERR_NOT_ENOUGH_RESOURCES* = -6
const ERR_NOT_ENOUGH_EXTENSIONS* = -6
const ERR_INVALID_TARGET* = -7
const ERR_FULL* = -8
const ERR_NOT_IN_RANGE* = -9
const ERR_INVALID_ARGS* = -10
const ERR_TIRED* = -11
const ERR_NO_BODYPART* = -12
const ERR_RCL_NOT_ENOUGH* = -14
const ERR_GCL_NOT_ENOUGH* = -15

proc `==`*(a, b: LookType): bool {.borrow.}
proc `$`*(a: LookType): string {.borrow.}

const LOOK_CREEPS* = "creep".LookType
const LOOK_ENERGY* = "energy".LookType
const LOOK_RESOURCES* = "resource".LookType
const LOOK_SOURCES* = "source".LookType
const LOOK_MINERALS* = "mineral".LookType
const LOOK_STRUCTURES* = "structure".LookType
const LOOK_FLAGS* = "flag".LookType
const LOOK_CONSTRUCTION_SITES* = "constructionSite".LookType
const LOOK_NUKES* = "nuke".LookType
const LOOK_TERRAIN* = "terrain".LookType

const OBSTACLE_OBJECT_TYPES* = ["spawn", "creep", "wall", "source", "constructedWall", "extension", "link", "storage", "tower", "observer", "powerSpawn", "powerBank", "lab", "terminal", "nuker"]

proc `==`*(a, b: BodyPart): bool {.borrow.}
proc `$`*(a: BodyPart): string {.borrow.}

const MOVE* = "move".BodyPart # 50
const WORK* = "work".BodyPart # 100
const CARRY* = "carry".BodyPart # 50
const ATTACK* = "attack".BodyPart # 80
const RANGED_ATTACK* = "ranged_attack".BodyPart # 150
const HEAL* = "heal".BodyPart # 250
const CLAIM* = "claim".BodyPart # 600
const TOUGH* = "tough".BodyPart # 10

proc `==`*(a, b: StructureType): bool {.borrow.}
proc `$`*(a: StructureType): string {.borrow.}

const STRUCTURE_TYPE_SPAWN* = "spawn".StructureType
const STRUCTURE_TYPE_EXTENSION* = "extension".StructureType
const STRUCTURE_TYPE_TOWER* = "toer".StructureType

proc `==`*(a, b: ResourceType): bool {.borrow.}
proc `$`*(a: ResourceType): string {.borrow.}

const RESOURCE_TYPE_ENERGY* = "energy".ResourceType

proc `==`*(a, b: ModeType): bool {.borrow.}
proc `$`*(a: ModeType): string {.borrow.}

const MODE_SIMULATION* = "simulation".ModeType
const MODE_SURVIVAL* = "survival".ModeType
const MODE_WORLD* = "world".ModeType
const MODE_ARENA* = "arena".ModeType

converter bodyPart(b: BodyPart): string = $(b.cstring)

proc isUndefined*[T](x: T): bool {.importcpp: "((#)==undefined)".}
proc isEmpty*[T](x: T): bool {.importcpp: "((#)=={})".}

proc `[]`*[K,V](d: JSAssoc[K,V]; k: K): V {.importcpp: "#[#]".}
proc `[]=`*[K,V](d: JSAssoc[K,V]; k: K; v: V) {.importcpp: "#[#] = #".}
proc hasKey*[K,V](d: JSAssoc[K,V]; k: K): bool {.importcpp: "((#).hasOwnProperty(#))".}

proc delete*[K,V](d: JSAssoc[K,V]; k: K) {.importcpp: "delete #[#]".}

iterator pairs*[K,V](d: JSAssoc[K,V]): (K,V) =
  var k: K
  var v: V
  {.emit: "for (var `k` in `d`) {".}
  {.emit: "  if (!`d`.hasOwnProperty(`k`)) continue;".}
  {.emit: "  `v`=`d`[`k`];".}
  yield (k, v)
  {.emit: "}".}

iterator items*[K,V](d: JSAssoc[K,V]): V =
  var v: V
  {.emit: "for (var k in `d`) {".}
  {.emit: "  if (!`d`.hasOwnProperty(k)) continue;".}
  {.emit: "  `v`=`d`[k];".}
  yield v
  {.emit: "}".}

iterator keys*[K,V](d: JSAssoc[K,V]): K =
  var k: K
  {.emit: "for (var `k` in `d`) {".}
  {.emit: "  if (!`d`.hasOwnProperty(`k`)) continue;".}
  yield k
  {.emit: "}".}

# screeps specials

proc createCreep*(spawn: StructureSpawn, body: openArray[BodyPart], name: cstring, memory: MemoryEntry): cstring =
  # I am hacking the inherit information from the object because screeps deadlocks
  # if its there and it is not needed for real (I think / TODO: I need to ask @araq about it!)
  {.emit: "delete `memory`.m_type; `result` = `spawn`.createCreep(`body`, `name`, `memory`);".}

proc describeExits*(map: Map, roomName: cstring): JSAssoc[cstring, cstring] {.importcpp.}
#  {.emit: "`map`.describeExits(`roomName`)\n".}

proc calcEnergyCost*(body: openArray[BodyPart]): int =
  for b in body:
    if b == MOVE:
      result += 50
    elif b == WORK:
      result += 100
    elif b == CARRY:
      result += 50
    elif b == ATTACK:
      result += 80
    elif b == RANGED_ATTACK:
      result += 250
    elif b == CLAIM:
      result += 600
    elif b == TOUGH:
      result += 10

#proc mem*(creep: Creep, ty: typedesc): ty =
#  result = cast[ty](creep.memory)

#proc creepsMem*(memory: Memory, ty: typedesc): JSAssoc[cstring, ty] =
#  result = cast[JSAssoc[cstring, ty]](memory.creeps)

proc carrySum*(creep: Creep): int =
  for kind, value in creep.carry:
    #console stringify kind
    result += value

# don't know if I like that
template `.`*(a: JSAssoc, f: untyped): auto =
  a[f]

template energy*(carry: JSAssoc[ResourceType, int]): int =
  carry[RESOURCE_TYPE_ENERGY]

var game* {.noDecl, importc: "Game".}: Game
var memory* {.noDecl, importc: "Memory".}: Memory

proc getObjectById*(game: Game, id: cstring, what: typedesc): what {.importcpp: "#.getObjectById(#)".}

proc findClosestByPath*[T](pos: RoomPosition, objs: seq[T]): T =
  {.emit: "`result` = `pos`.findClosestByPath(`objs`);\n".}

proc findClosestByRange*[T](pos: RoomPosition, objs: seq[T]): T =
  {.emit: "`result` = `pos`.findClosestByRange(`objs`);\n".}

proc find*(room: Room, what: typedesc): seq[what] =
  result = @[]
  when what is Source:
    {.emit: "`result` = `room`.find(FIND_SOURCES);\n".}
  elif what is Structure:
    {.emit: "`result` = `room`.find(FIND_STRUCTURES);\n".}
  elif what is ConstructionSite:
    {.emit: "`result` = `room`.find(FIND_CONSTRUCTION_SITES);\n".}
  elif what is Creep:
    {.emit: "`result` = `room`.find(FIND_CREEPS);\n".}
  else: {.error: "impossible find".}
  # wanna make some error or leave if with nothing found?

proc find*(room: Room, what: typedesc, filter: proc(s: what): bool): seq[what] =
  result = @[]
  when what is Source:
    {.emit: "`result` = `room`.find(FIND_SOURCES, { filter: `filter` });\n".}
  elif what is ConstructionSite:
    {.emit: "`result` = `room`.find(FIND_CONSTRUCTION_SITES, { filter: `filter` });\n".}
  elif what is Structure:
    {.emit: "`result` = `room`.find(FIND_STRUCTURES, { filter: `filter` });\n".}
  elif what is Creep:
    {.emit: "`result` = `room`.find(FIND_CREEPS, { filter: `filter` });\n".}
  else: {.error: "impossible find".}
  # wanna make some error or leave if with nothing found?

proc findMy*(room: Room, what: typedesc): seq[what] =
  result = @[]
  when what is Structure:
    {.emit: "`result` = `room`.find(FIND_MY_STRUCTURES);\n".}
  elif what is ConstructionSite:
    {.emit: "`result` = `room`.find(FIND_MY_CONSTRUCTION_SITES);\n".}
  elif what is Creep:
    {.emit: "`result` = `room`.find(FIND_MY_CREEPS);\n".}
  else: {.error: "impossible findMy".}

proc findMy*(room: Room, what: typedesc, filter: proc(s: what): bool): seq[what] =
  result = @[]
  when what is Structure:
    {.emit: "`result` = `room`.find(FIND_MY_STRUCTURES, { filter: `filter` });\n".}
  elif what is ConstructionSite:
    {.emit: "`result` = `room`.find(FIND_MY_CONSTRUCTION_SITES, { filter: `filter` });\n".}
  elif what is Creep:
    {.emit: "`result` = `room`.find(FIND_MY_CREEPS, { filter: `filter` });\n".}
  else: {.error: "impossible findMy".}

proc findHostile*(room: Room, what: typedesc): seq[what] =
  result = @[]
  when what is Structure:
    {.emit: "`result` = `room`.find(FIND_HOSTILE_STRUCTURES);\n".}
  elif what is Creep:
    {.emit: "`result` = `room`.find(FIND_HOSTILE_CREEPS);\n".}
  else: {.error: "impossible findHostile".}

proc findHostile*(room: Room, what: typedesc, filter: proc(s: what): bool): seq[what] =
  result = @[]
  when what is Structure:
    {.emit: "`result` = `room`.find(FIND_HOSTILE_STRUCTURES, { filter: `filter` });\n".}
  elif what is Creep:
    {.emit: "`result` = `room`.find(FIND_HOSTILE_CREEPS, { filter: `filter` });\n".}
  else: {.error: "impossible findHostile".}

#[ something like this would also work:

proc findStructures* [T: ref object | object | JSAssoc](room: Room, opts: T): seq[Structure] =
  result = @[]
  {.emit: "`result` = `room`.find(FIND_STRUCTURES, `opts`);\n".}

type SourceFilterOpts = ref object
  filter: proc(s: Structure): bool
var opts = SourceFilterOpts(filter: proc(struct: Structure): bool = struct.structureType == STRUCTURE_SPAWN)
var targets = creep.room.findStructures(opts)

]#

proc harvest*(creep: Creep, source: Source): int {.importcpp.}
proc transfer*(creep: Creep, structure: Structure, resource: ResourceType): int {.importcpp.}
proc transfer*(creep: Creep, structure: Creep, resource: ResourceType): int {.importcpp.}
proc build*(creep: Creep, site: ConstructionSite): int {.importcpp.}
proc repair*(creep: Creep, structure: Structure): int {.importcpp.}
proc attack*(creep: Creep, hostile: Creep): int {.importcpp.}
proc rangedAttack*(creep: Creep, hostile: Creep): int {.importcpp.}
proc upgradeController*(creep: Creep, ctrl: StructureController): int {.importcpp.}

proc moveTo*(creep: Creep, pos: RoomPosition): int {.importcpp, discardable.}
proc moveTo*(creep: Creep, obj: RoomObject): int {.importcpp, discardable.}

proc filterCreeps*(filter: proc(creep: Creep): bool): seq[Creep] =
  {.emit: "`result` = _.filter(Game.creeps, `filter`);\n".}

proc sort* [T](objs: seq[T], sortcm: proc(a, b: T): int) {.importcpp: "#.sort(#)".}

# A whole bunch of constant getting imported here
# I am not sure if I want it like this though...

var CONSTRUCTION_COST* {.noDecl, importc.}:  JSAssoc[cstring, int]
var CONSTRUCTION_COST_ROAD_SWAMP_RATIO* {.noDecl, importc.}: int

var CONTROLLER_LEVELS* {.noDecl, importc.}:  JSAssoc[int, int]
var CONSTROLLER_STRUCTURES* {.noDecl, importc.}:  JSAssoc[cstring, JSAssoc[int, int]]
var CONTROLLER_DOWNGRADE* {.noDecl, importc.}:  JSAssoc[int, int]
var CONTROLLER_CLAIM_DOWNGRADE* {.noDecl, importc.}: float
var CONTROLLER_RESERVE* {.noDecl, importc.}: int
var CONTROLLER_RESERVE_MAX* {.noDecl, importc.}: int
var CONTROLLER_MAX_UPGRADE_PER_TICK* {.noDecl, importc.}: int
var CONTROLLER_ATTACK_BLOCKED_UPGRADE* {.noDecl, importc.}: int

var TOWER_HITS* {.noDecl, importc.}: int
var TOWER_CAPACITY* {.noDecl, importc.}: int
var TOWER_ENERGY_COST* {.noDecl, importc.}: int
var TOWER_POWER_ATTACK* {.noDecl, importc.}: int
var TOWER_POWER_HEAL* {.noDecl, importc.}: int
var TOWER_POWER_REPAIR* {.noDecl, importc.}: int
var TOWER_OPTIMAL_RANGE* {.noDecl, importc.}: int
var TOWER_FALLOFF_RANGE* {.noDecl, importc.}: int
var TOWER_FALLOFF* {.noDecl, importc.}: float

var OBSERVER_HITS* {.noDecl, importc.}: int
var OBSERVER_RANGE* {.noDecl, importc.}: int

var POWER_BANK_HITS* {.noDecl, importc.}: int
var POWER_BANK_CAPACITY_MAX* {.noDecl, importc.}: int
var POWER_BANK_CAPACITY_MIN* {.noDecl, importc.}: int
var POWER_BANK_CAPACITY_CRIT* {.noDecl, importc.}: float
var POWER_BANK_DECAY* {.noDecl, importc.}: int
var POWER_BANK_HIT_BACK* {.noDecl, importc.}: float

var POWER_SPAWN_HITS* {.noDecl, importc.}: int
var POWER_SPAWN_ENERGY_CAPACITY* {.noDecl, importc.}: int
var POWER_SPAWN_POWER_CAPACITY* {.noDecl, importc.}: int
var POWER_SPAWN_ENERGY_RATIO* {.noDecl, importc.}: int

var EXTRACTOR_HITS* {.noDecl, importc.}: int

var LAB_HITS* {.noDecl, importc.}: int
var LAB_MINERAL_CAPACITY* {.noDecl, importc.}: int
var LAB_ENERGY_CAPACITY* {.noDecl, importc.}: int
var LAB_BOOST_ENERGY* {.noDecl, importc.}: int
var LAB_BOOST_MINERAL* {.noDecl, importc.}: int
var LAB_COOLDOWN* {.noDecl, importc.}: int

var GCL_POW* {.noDecl, importc.}: float
var GCL_MULTIPLY* {.noDecl, importc.}: int
var GCL_NOVICE* {.noDecl, importc.}: int

# tbc
