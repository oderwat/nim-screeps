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
  {.emit: "module.exports.loop = function () { screepsLoop() }\n".}

type
  JSAssoc*[Key, Val] = ref object

  JsObj* = ref object ## can be a string, an int etc.

  # Types which are just "strings" in javscript
  BodyPart* = distinct cstring
  StructureType* = distinct cstring
  ResourceType* = distinct cstring
  ModeType* = distinct cstring

  GlobalControlLevelObj {.exportc.} = object
    level: int
    progress: int
    progressTotal: int

  GlobalControlLevel* = ref GlobalControlLevelObj

  MapObj* {.exportc.} = object
  Map* = ref MapObj

  GameObj*  {.exportc.} = object
    rooms: JSAssoc[cstring, Room]
    spawns: JSAssoc[cstring, StructureSpawn]
    creeps: JSAssoc[cstring, Creep]
    flags: JSAssoc[cstring, Flag]
    gcl: GlobalControlLevel
    map: Map

  Game* = ref GameObj

  MemoryObj*  {.exportc.} = object
    creeps: JSAssoc[cstring, Creep]

  Memory* = ref MemoryObj

  InvadersObj*  {.exportc.} = ref object
    bodies: seq[cstring]

  Invaders* = ref InvadersObj

  SurvivalInfoObj* {.exportc.} = object
    mode: cstring
    status: cstring
    user: cstring
    score: int
    timeToWave: int
    wave: int
    survivalEnabled: bool
    invaders: Invaders

  SurvivalInfo* = ref SurvivalInfoObj

  RoomObj* {.exportc.} = object
    name: cstring
    mode: cstring
    memory: pointer
    controller: StructureController
    storage: pointer
    terminal: pointer
    energyAvailable: int
    energyCapacityAvailable: int
    survivalInfo: SurvivalInfo

  Room* = ref RoomObj

  RoomPositionObj* {.exportc.} = object
    x: int
    y: int
    roomName: cstring

  RoomPosition* = ref RoomPositionObj

  RoomObjectObj* = object of RootObj
    room: Room
    pos: RoomPosition

  RoomObject* = ref RoomObjectObj

  CreepObj* {.exportc.} = object of RoomObjectObj
    name: cstring
    body: seq[BodyPart]
    memory: pointer # access with creep.mem
    carry: JSAssoc[cstring, int]
    carryCapacity: int

  Creep* = ref CreepObj

  SourceObj* {.exportc.} =  object of RoomObjectObj
    energy: int
    energyCapacity: int
    id: cstring
    ticksToRegeneration: int

  Source* = ref SourceObj

  FlagObj* {.exportc.} =  object of RoomObjectObj
    name: cstring
    color: cstring
    secondaryColor: cstring
    memory: pointer

  Flag* = ref FlagObj

  StructureObj* {.exportc.} =  object of RoomObjectObj
    hits: int
    hitsMax: int
    id: cstring
    structureType: StructureType

  Structure* = ref StructureObj

  StructureEnergyObj* {.exportc.} = object of StructureObj
    energy: int
    energyCapacity: int

  StructureEnergy* = ref StructureEnergyObj

  StructureSpawnObj* = object of StructureEnergyObj
    name: cstring
    spawning: pointer
    owner: User
    my: bool

  StructureSpawn* = ref StructureSpawnObj

  StructureExtensionObj* = object of StructureEnergyObj
  StructureExtension* = ref StructureExtensionObj

  StructureTowerObj* = object of StructureEnergyObj
  StructureTower* = ref StructureTowerObj

  ConstructionSiteObj* {.exportc.} = object of RoomObjectObj
    id: cstring
    my: bool
    owner: User
    progress: int
    progressTotal: int
    structureType: StructureType

  ConstructionSite* = ref ConstructionSiteObj

  StructureControllerObj* {.exportc.} = object of StructureObj
    progress: int
    progressTotal: int
    reservation: pointer
    ticksToDowngrade: int
    upgradeBlocked: int

  StructureController* = ref StructureControllerObj

  UserObj* {.exportc.} = object
    username: cstring

  User* = ref UserObj

  FindTargets* = enum
    FIND_SOURCES = 105
    FIND_DROPPED_RESOURCES
    FIND_STRUCTURES

const OK* = 0
const ERR_NOT_OWNER* = -1
const ERR_NO_PATH* = -2
const ERR_BUSY* = -4
const ERR_INVALID_TARGET* = -7
const ERR_NOT_IN_RANGE* = -9
const ERR_TIRED* = -11
const ERR_NO_BODYPART* = -12

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

proc createCreep*[M](spawn: StructureSpawn, body: openArray[BodyPart], name: cstring, memory: M): cstring =
  {.emit: "`result` = `spawn`.createCreep(`body`, `name`, `memory`);".}

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

proc mem*(creep: Creep, ty: typedesc): ty =
  result = cast[ty](creep.memory)

proc carrySum*(creep: Creep): int =
  for kind, value in creep.carry:
    #console stringify kind
    result += value

# don't know if I like that
template `.`*(a: JSAssoc, f: untyped): auto =
  a[f]

# well
proc carryEnergy*(creep: Creep): int =
  result = creep.carry["energy"]

var game* {.noDecl, importc: "Game".}: Game
var memory* {.noDecl, importc: "Memory".}: Memory

proc getObjectById*(game: Game, id: cstring, what: typedesc): what {.importcpp: "#.getObjectById(#)".}

proc findClosestByPath*[T](pos: RoomPosition, objs: seq[T]): T =
  {.emit: "`result` = `pos`.findClosestByPath(`objs`);\n".}

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

proc findHostile*(room: Room, what: typedesc): seq[what] {.compiletime} =
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
    {.emit: "`result` = `room`.find(FIND_MY_CREEPS, { filter: `filter` });\n".}
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
proc build*(creep: Creep, site: ConstructionSite): int {.importcpp.}
proc repair*(creep: Creep, structure: Structure): int {.importcpp.}
proc upgradeController*(creep: Creep, ctrl: StructureController): int {.importcpp.}

proc moveTo*(creep: Creep, pos: RoomPosition): int {.importcpp, discardable.}
proc moveTo*(creep: Creep, obj: RoomObject): int {.importcpp, discardable.}

proc filterCreeps*(filter: proc(creep: Creep): bool): seq[Creep] =
  {.emit: "`result` = _.filter(Game.creeps, `filter`);\n".}

proc sort* [T](objs: seq[T], sortcm: proc(a, b: T): int) {.importcpp: "#.sort(#)".}
