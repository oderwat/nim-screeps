# nim check --verbosity:2 --hints:off
#
# The Screeps Nim module
#
# This contains objects and procs for the pathfinder
#
# (c) 2016 by Hans Raaf (METATEXX GmbH)

import system except echo, log

import macros, strutils

import jsext
export jsext

when defined(logext):
  type LogSeverity* = enum
    reserved, # just keep that reserved
    debug,
    info,
    normal,
    error,
    syntax # don't use yourself. It is used with engine errors

  const colors: array[LogSeverity, cstring] = [
    "".cstring,
    "lightgreen",
    "cyan",
    "white",
    "red",
    "orange" ]

  template log*(message: cstring, severity: LogSeverity = normal) =
    when defined(logci):
      let ii = instantiationInfo(-1)
      let ci: cstring = ii.filename & "/" & ii.line & ": "
      consoleLog ci & "<font color='" & colors[severity] & "' " & """severity="""" &
        $ord(severity) & """"""" & ">" & message & "</font>"
    else:
      consoleLog "<font color='" & colors[severity] & "' " & """severity="""" &
        $ord(severity) & """"""" & ">" & message & "</font>"

  template logH*(message: cstring) =
    const highlight = "#ffff00".cstring
    when defined(logci):
      let ii = instantiationInfo(-1)
      let ci: cstring = ii.filename & "/" & ii.line & ": "
      consoleLog ci & "<font color=\"" & highlight & "\" type=\"highlight\">" & message & "</font>"
    else:
      consoleLog "<font color=\"" & highlight & "\" type=\"highlight\">" & message & "</font>"

  proc dump*(args: varargs[cstring, stringify]) =
    for x in args: log x, debug

else:
  proc log*(s: cstring) {.importc: "console.log", varargs.}

  proc dump*(args: varargs[cstring, stringify]) =
    for x in args: log x

when defined(screepsprofiler):
  {.emit: "function screepsProfiler() {\n".}
  {.emit: staticRead("screeps_profiler.js").
    replace("`","``").
    replace("module.exports =","return") & "\n" .}
  {.emit: "}; var profiler = screepsProfiler();\n".}

template screepsLoop*(code: untyped): untyped =
  proc screepsLoop() {.exportc.} =
    code
  when defined(screepsprofiler):
    {.emit: "profiler.enable()\n".}
    {.emit: "module.exports.loop = profiler.wrap(screepsLoop)\n".}
  else:
    {.emit: "module.exports.loop = screepsLoop\n".}

type
  # Types which are just "strings" in javscript
  BodyPart* = distinct cstring
  StructureType* = distinct cstring
  ResourceType* = distinct cstring
  ModeType* = distinct cstring
  LookType* = distinct cstring
  RoomName* = distinct cstring
  ObjId* = distinct cstring

  BodyObj* = object
    part* {.exportc: "type".}: BodyPart # same as below
    `type`*: BodyPart
    hits*: int

  Body* = ref BodyObj

  RouteEntryObj* = object
    exit*: FindTargets
    name*: cstring

  RouteEntry* = ref RouteEntryObj

  CPUObj* {.exportc.} = object
    limit*: int
    tickLimit*: int
    bucket*: int
  CPU* = ref CPUObj

  GlobalControlLevelObj {.exportc.} = object
    level*: int
    progress*: int
    progressTotal*: int

  GlobalControlLevel* = ref GlobalControlLevelObj

  MapObj* {.exportc.} = object
  Map* = ref MapObj

  GameObj*  {.exportc.} = object
    constructionSites: JSAssoc[cstring, ConstructionSite]
    cpu*: CPU
    creeps*: JSAssoc[cstring, Creep]
    flags*: JSAssoc[cstring, Flag]
    gcl*: GlobalControlLevel
    map*: Map
    market*: pointer
    rooms*: JSAssoc[RoomName, Room]
    spawns*: JSAssoc[cstring, StructureSpawn]
    structures*: JSAssoc[cstring, Structure]
    time*: int

  Game* = ref GameObj

  #MemoryEntryObj* = object
  MemoryEntry* = ref object of RootObj #MemoryEntryObj

  MemoryObj*  {.exportc.} = object of RootObj
    creeps*: JSAssoc[cstring, MemoryEntry]
    rooms*:  JSAssoc[cstring, MemoryEntry]

  Memory* = ref MemoryObj

  OptionsObj* = object of RootObj
  Options* = ref OptionsObj

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

  PathStepsObj* {.exportc.} = object
    x: int
    y: int
    dx: int
    dy: int
    direction: Directions

  PathSteps* = ref PathStepsObj

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
    id*: ObjId
    my*: bool
    owner*: User
    progress*: int
    progressTotal*: int
    structureType*: StructureType

  ConstructionSite* = ref ConstructionSiteObj

  CreepObj* {.exportc.} = object of RoomObjectObj
    body*: seq[Body]
    carry*: JSAssoc[ResourceType, int]
    carryCapacity*: int
    fatigue*: int
    hits*: int
    hitsMax*: int
    id*: ObjId
    memory*: MemoryEntry
    my*: bool
    name*: cstring
    owner*: User
    saying*: cstring
    spawning*: bool
    ticksToLive*: int

  Creep* = ref CreepObj

  FlagObj* {.exportc.} =  object of RoomObjectObj
    name*: cstring
    color*: Colors
    secondaryColor*: Colors
    memory*: pointer

  Flag* = ref FlagObj

  MineralObj* {.exportc.} = object of RoomObjectObj
    mineralAmount*: int
    mineralType*: ResourceType
    id*: ObjId
    ticksToRegeneration*: int

  Mineral* = ref MineralObj

  NukeObj* {.exportc.} = object of RoomObjectObj
    id*: ObjId
    launchRoomName*: RoomName
    timeToLand*: int

  Nuke* = ref NukeObj

  ResourceObj* {.exportc.} = object of RoomObjectObj
    id*: ObjId
    amount*: int
    resourceType*: ResourceType

  Resource* = ref ResourceObj

  SourceObj* {.exportc.} =  object of RoomObjectObj
    energy*: int
    energyCapacity*: int
    id*: ObjId
    ticksToRegeneration*: int

  Source* = ref SourceObj

  StructureObj* {.exportc.} =  object of RoomObjectObj
    hits*: int
    hitsMax*: int
    id*: ObjId
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

  StructureControllerObj* {.exportc.} = object of OwnedStructureObj
    level*: int
    progress*: int
    progressTotal*: int
    reservation*: pointer
    ticksToDowngrade*: int
    upgradeBlocked*: int

  StructureController* = ref StructureControllerObj

  StructureExtensionObj* = object of EnergizedStructureObj
  StructureExtension* = ref StructureExtensionObj

  StructureExtractorObj* = object of OwnedStructureObj
  StructureExtractor* = ref StructureExtractorObj

  StructureKeeperLairObj* {.exportc.} = object of OwnedStructureObj
    ticksToSpawn*: int

  StructureKeeperLair* = ref StructureKeeperLairObj

  StructureLabObj* = object of OwnedStructureObj
  StructureLab* = ref StructureLabObj

  StructureLinkObj* {.exportc.} = object of EnergizedStructureObj
    cooldown*: int

  StructureLink* = ref StructureLinkObj

  # TODO: StructureNuker
  # TODO: StructureObserver
  # TODO: StructurePowerBank
  # TODO: StructurePoweSpawn
  # TODO: StructureRampart

  SpawningObj* {.exportc.} = object
    name*: cstring
    needTime*: int
    remainingTime*: int

  Spawning* = ref SpawningObj

  StructureSpawnObj* = object of EnergizedStructureObj
    name*: cstring
    spawning*: Spawning

  StructureSpawn* = ref StructureSpawnObj

  StructureStorageObj* {.exportc.} = object of StructureObj
    store*: JSAssoc[ResourceType, int] # has always: RESOURCE_TYPE_ENERGY
    storeCapacity*: int

  StructureStorage* = ref StructureStorageObj


  # TODO: StructureTerminal

  StructureTowerObj* = object of EnergizedStructureObj
  StructureTower* = ref StructureTowerObj

  StructureContainerObj* = object of StructureObj
    store*: JSAssoc[ResourceType, int] # has always: RESOURCE_TYPE_ENERGY
    storeCapacity*: int

  StructureContainer* = ref StructureContainerObj

  # TODO: StructurePortal
  # TODO: StructureRoad

  StructureWallObj* = object of StructureObj
    ticksToLive: int # only when room protection is active
  StructureWall* = ref StructureWallObj

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

converter objId*(a: ObjId): cstring {.importcpp: "#".}
converter roomName*(a: RoomName): cstring {.importcpp: "#".}
converter bodyPart*(a: BodyPart): cstring {.importcpp: "#".}
converter structureType*(a: StructureType): cstring {.importcpp: "#".}
converter modeType*(a: ModeType): cstring {.importcpp: "#".}
converter resourceType*(a: ResourceType): cstring {.importcpp: "#".}
converter lookType*(a: LookType): cstring {.importcpp: "#".}

const FIND_DROPPED_RESOURCES* = FIND_DROPPED_ENERGY

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

const OBSTACLE_OBJECT_TYPES* = ["spawn".cstring, "creep", "wall", "source",
  "constructedWall", "extension", "link", "storage", "tower", "observer",
  "powerSpawn", "powerBank", "lab", "terminal", "nuker"]

const MOVE* = "move".BodyPart # 50
const WORK* = "work".BodyPart # 100
const CARRY* = "carry".BodyPart # 50
const ATTACK* = "attack".BodyPart # 80
const RANGED_ATTACK* = "ranged_attack".BodyPart # 150
const HEAL* = "heal".BodyPart # 250
const CLAIM* = "claim".BodyPart # 600
const TOUGH* = "tough".BodyPart # 10

const STRUCTURE_TYPE_SPAWN* = "spawn".StructureType
const STRUCTURE_TYPE_EXTENSION* = "extension".StructureType
const STRUCTURE_TYPE_TOWER* = "tower".StructureType
const STRUCTURE_TYPE_WALL* = "constructedWall".StructureType
const STRUCTURE_TYPE_ROAD* = "road".StructureType
const STRUCTURE_TYPE_RAMPART* = "rampart".StructureType
const STRUCTURE_TYPE_CONTROLLER* = "controller".StructureType
const STRUCTURE_TYPE_STORAGE* = "storage".StructureType
const STRUCTURE_TYPE_CONTAINER* = "container".StructureType
const STRUCTURE_TYPE_LINK* = "link".StructureType

const RESOURCE_TYPE_ENERGY* = "energy".ResourceType

const MODE_SIMULATION* = "simulation".ModeType
const MODE_SURVIVAL* = "survival".ModeType
const MODE_WORLD* = "world".ModeType
const MODE_ARENA* = "arena".ModeType

# screeps specials

proc createCreep*(spawn: StructureSpawn, body: openArray[BodyPart], name: cstring, memory: MemoryEntry): tuple[ret: int, name: cstring]=
  # I am hacking the inherit information from the object because screeps deadlocks
  # if its there and it is not needed for real (I think / TODO: I need to ask @araq about it!)
  # I also don't return the name but OK if spawning worked
  {.emit: "if(`memory` != undefined && `memory`.m_type != undefined) delete `memory`.m_type;\n".}
  {.emit: "{ var r = `spawn`.createCreep(`body`, `name`, `memory`);\n".}
  {.emit: "if(_.isString(r)) `result` = { Field0: 0, Field1: r}; else `result` = { Field0: r, Field1: ''};".}
  {.emit: "\n}\n".}

proc describeExits*(map: Map, roomName: cstring): JSAssoc[cstring, cstring] {.importcpp.}
#  {.emit: "`map`.describeExits(`roomName`)\n".}

proc calcEnergyCost*(body: openArray[BodyPart]): int =
  result = 0
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

template energy*(carry: JSAssoc[ResourceType, int]): int =
  carry[RESOURCE_TYPE_ENERGY]

var game* {.noDecl, importc: "Game".}: Game
var memory* {.noDecl, importc: "Memory".}: Memory

proc getObjectById*[T](game: Game, id: ObjId, what: typedesc[T]): T {.importcpp: "#.getObjectById(#)".}

proc findClosestByPath*[T](pos: RoomPosition, objs: seq[T]): T =
  {.emit: "`result` = `pos`.findClosestByPath(`objs`);\n".}

proc findClosestByPath*[T](pos: RoomPosition, objs: seq[T], filter: proc(s: auto): bool): T =
  {.emit: "`result` = `pos`.findClosestByPath(`objs`, { filter: `filter` });\n".}

proc findClosestByPath*[T](pos: RoomPosition, objs: seq[T], opts: Options): T =
  {.emit: "`result` = `pos`.findClosestByPath(`objs`, `opts` });\n".}

proc findClosestByRange*[T](pos: RoomPosition, objs: seq[T]): T =
  {.emit: "`result` = `pos`.findClosestByRange(`objs`);\n".}

template typeToFind*(what: typedesc): FindTargets =
  when what is Source: FIND_SOURCES
  elif what is ConstructionSite: FIND_CONSTRUCTION_SITES
  elif what is StructureSpawn: {.error: "Use find with my or hostile".}
  elif what is Structure: FIND_STRUCTURES
  elif what is Creep: FIND_CREEPS
  elif what is Resource: FIND_DROPPED_RESOURCES
  elif what is ConstructionSite: FIND_CONSTRUCTION_SITES
  else: {.error: "impossible find".}

template typeToFindHostile*(what: typedesc): FindTargets =
  when what is Creep: FIND_HOSTILE_CREEPS
  elif what is StructureSpawn: FIND_HOSTILE_SPAWNS
  elif what is Structure: FIND_HOSTILE_STRUCTURES
  else: {.error: "impossible find".}

template typeToFindMy*(what: typedesc): FindTargets =
  when what is Creep: FIND_MY_CREEPS
  elif what is StructureSpawn: FIND_MY_SPAWNS
  elif what is StructureContainer: {.error: "use Structure + Filter".}
  elif what is Structure: FIND_MY_STRUCTURES
  elif what is ConstructionSite: FIND_MY_CONSTRUCTION_SITES
  else: {.error: "impossible find".}

# just to make it even more crazy
converter towerToPos*(obj: StructureTower): RoomPosition = obj.pos
converter roomName*(rname: cstring | string): RoomName = rname.RoomName
#converter roomName*(rname: string): RoomName = rname.RoomName

proc findClosestByRange*[T](pos: RoomPosition, what: typedesc[T]): T =
  {.emit: "`result` = `pos`.findClosestByRange(" & $typeToFind(what) & ");\n".}

proc findClosestByRange*[T](pos: RoomPosition, what: typedesc[T], filter: proc(s: auto): bool): T =
  {.emit: "`result` = `pos`.findClosestByRange(" & $typeToFind(what) & ", { filter: `filter` });\n".}

proc findClosestHostileByRange*[T](pos: RoomPosition, what: typedesc[T]): T =
  {.emit: "`result` = `pos`.findClosestByRange(" & $typeToFindHostile(what) & ");\n".}

proc findClosestHostileByRange*[T](pos: RoomPosition, what: typedesc[T], filter: proc(s: auto): bool): T =
  {.emit: "`result` = `pos`.findClosestByRange(" & $typeToFindHostile(what) & ", { filter: `filter` });\n".}

proc findMyClosestByRange*[T](pos: RoomPosition, what: typedesc[T]): T =
  {.emit: "`result` = `pos`.findClosestByRange(" & $typeToFindMy(what) & ");\n".}

proc findMyClosestByRange*[T](pos: RoomPosition, what: typedesc[T], filter: proc(s: auto): bool): T =
  {.emit: "`result` = `pos`.findClosestByRange(" & $typeToFindMy(what) & ", { filter: `filter` });\n".}

proc findClosestByPath*[T](pos: RoomPosition, what: typedesc[T]): T =
  {.emit: "`result` = `pos`.findClosestByPath(" & $typeToFind(what) & ");\n".}

proc findClosestByPath*[T](pos: RoomPosition, what: typedesc[T], filter: proc(s: auto): bool): T =
  {.emit: "`result` = `pos`.findClosestByPath(" & $typeToFind(what) & ", { filter: `filter` });\n".}

proc findMyClosestByPath*[T](pos: RoomPosition, what: typedesc[T]): T =
  {.emit: "`result` = `pos`.findClosestByPath(" & $typeToFindMy(what) & ");\n".}

proc findMyClosestByPath*[T](pos: RoomPosition, what: typedesc[T], filter: proc(s: auto): bool): T =
  {.emit: "`result` = `pos`.findClosestByPath(" & $typeToFindMy(what) & ", { filter: `filter` });\n".}

proc find*[T](room: Room, what: typedesc[T]): seq[T] =
  result = @[]
  {.emit: "`result` = `room`.find(" & $typeToFind(what) & ");\n".}

proc find*[T](room: Room, what: typedesc[T], filter: proc(s: auto): bool): seq[T] =
  result = @[]
  {.emit: "`result` = `room`.find(" & $typeToFind(what) & ", { filter: `filter` });\n".}

proc findMy*[T](room: Room, what: typedesc[T]): seq[T] =
  result = @[]
  {.emit: "`result` = `room`.find(" & $typeToFindMy(what) & ");\n".}

proc findMy*[T](room: Room, what: typedesc[T], filter: proc(s: auto): bool): seq[T] =
  result = @[]
  {.emit: "`result` = `room`.find(" & $typeToFindMy(what) & ", { filter: `filter` });\n".}

proc findHostile*[T](room: Room, what: typedesc[T]): seq[T] =
  result = @[]
  {.emit: "`result` = `room`.find(" & $typeToFindHostile(what) & ");\n".}

proc findHostile*[T](room: Room, what: typedesc[T], filter: proc(s: auto): bool): seq[T] =
  result = @[]
  {.emit: "`result` = `room`.find(" & $typeToFindHostile(what) & ", { filter: `filter` });\n".}

proc find*(room: Room, find: FindTargets): seq[RoomPosition] {.importcpp.}

proc findRoute*(map: Map, src: Room | RoomName, dst: Room | RoomName): seq[RouteEntry] {.importcpp.}

proc newRoomPosition*(x, y: int, name: RoomName): RoomPosition {.importcpp: "new RoomPosition(#,#,#)".}

proc say*(creep: Creep, txt: cstring, public: bool = false) {.importcpp.}
proc harvest*(creep: Creep, source: Source): int {.importcpp.}
proc pickup*(creep: Creep, resource: Resource): int {.importcpp.}
proc suicide*(creep: Creep) {.importcpp.}
proc drop*(creep: Creep, resource: ResourceType): int {.discardable,importcpp.}
proc drop*(creep: Creep, resource: ResourceType, ammount: int): int {.discardable,importcpp.}
proc transfer*(creep: Creep, structure: Structure, resource: ResourceType): int {.importcpp.}
proc transfer*(creep: Creep, structure: Creep, resource: ResourceType): int {.importcpp.}
proc build*(creep: Creep, site: ConstructionSite): int {.importcpp.}
proc dismantle*(creep: Creep, structure: Structure): int {.discardable,importcpp.}
proc repair*(creep: Creep, structure: Structure): int {.importcpp.}
proc attack*(creep: Creep, hostile: RoomObject): int {.importcpp.}
proc rangedAttack*(creep: Creep, hostile: RoomObject): int {.importcpp.}
proc upgradeController*(creep: Creep, ctrl: StructureController): int {.importcpp.}
proc attackController*(creep: Creep, ctrl: StructureController): int {.importcpp.}
proc claimController*(creep: Creep, ctrl: StructureController): int {.importcpp.}
proc reserveController*(creep: Creep, ctrl: StructureController): int {.importcpp.}
proc moveTo*(creep: Creep, target: RoomPosition | RoomObject): int {.importcpp, discardable.}
proc moveTo*(creep: Creep, x,y: int): int {.importcpp, discardable.}
proc heal*(src, dst: Creep): int {.discardable, importcpp.}
proc rangedHeal*(src, dst: Creep): int {.discardable, importcpp.}
proc withdraw*(creep: Creep, where: EnergizedStructure | StructureStorage | StructureContainer, what: ResourceType): int {.discardable,importcpp.}
proc withdraw*(creep: Creep, where: EnergizedStructure | StructureStorage | StructureContainer, what: ResourceType, ammount: int): int {.discardable,importcpp.}

proc transferEnergy*(src, dst: StructureLink): int {.discardable,importcpp.}
proc transferEnergy*(src, dst: StructureLink, ammount: int): int {.discardable,importcpp.}

proc repair*(tower: StructureTower, structure: Structure): int {.discardable, importcpp.}
proc heal*(tower: StructureTower, creep: Creep): int {.discardable, importcpp.}
proc attack*(tower: StructureTower, hostile: Creep): int {.discardable, importcpp.}

proc findPath*(room: Room, pos: RoomPosition, target: RoomPosition): seq[PathSteps] {.importcpp, discardable.}

proc findPathTo*(pos: RoomPosition, target: RoomPosition | RoomObject): seq[PathSteps] {.importcpp, discardable.}
proc getRangeTo*(pos: RoomPosition, target: RoomPosition | RoomObject): int {.importcpp, discardable.}
proc createConstructionSite*(pos: RoomPosition, structure: StructureType): int {.importcpp, discardable.}
proc createFlag*(pos: RoomPosition): int {.importcpp, discardable.}
proc createFlag*(pos: RoomPosition, name: cstring): int {.importcpp, discardable.}
proc createFlag*(pos: RoomPosition, name: cstring, col1: Colors): int {.importcpp, discardable.}
proc createFlag*(pos: RoomPosition, name: cstring, col1: Colors, col2: Colors): int {.importcpp, discardable.}
proc isNearTo*(pos: RoomPosition, x, y: int): bool {.importcpp.}
proc isNearTo*(pos: RoomPosition, target: RoomPosition | RoomObject): bool {.importcpp.}
proc inRangeTo*(pos: RoomPosition, x, y: int, distance: int): bool {.importcpp.}
proc inRangeTo*(pos: RoomPosition, target: RoomPosition | RoomObject, distance: int): bool {.importcpp.}
proc isEqualTo*(pos: RoomPosition, x, y: int): bool {.importcpp.}
proc isEqualTo*(pos: RoomPosition, target: RoomPosition | RoomObject): bool {.importcpp.}

proc filterCreeps*(filter: proc(creep: Creep): bool): seq[Creep] =
  {.emit: "`result` = _.filter(Game.creeps, `filter`);\n".}

proc filter*[T](src: seq[T], filter: proc(it: T): bool): seq[T] =
  {.emit: "`result` = _.filter(`src`, `filter`);\n".}

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
