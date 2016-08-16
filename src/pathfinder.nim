# nim check --verbosity:2 --hints:off
#
# A Part of Screeps Nim module
#
# This contains objects and procs for the pathfinder
#
# (c) 2016 by Hans Raaf (METATEXX GmbH)
#

import screeps

type
  PathFinder* = ref object
  PFCostMatrix* = ref object

  PFGoal* = ref object
    pos: RoomPosition
    rng: int

  PFOpts* = ref object
    roomCallback: proc(roomName: RoomName): PFCostMatrix # default nil
    plainCost: int # 1 (cost for walking on plains)
    swampCost: int # 5 (cost for walking on swamp)
    flee: bool # false (run away to range from the goal)
    maxOps: int # 2000 (maximum allowed oprations 1 op ~ 0.001 CPU)
    maxRooms: int # 16 (maximum rooms to search)
    heuristicWeight: float # 1.2 (A* heuristics)

  PFResult* = ref object
    path: seq[RoomPosition]
    ops: int

var pf* {.noDecl, importc: "PathFinder".}: PathFinder

proc newPFOpts*(): PFOpts =
  result = PFOpts(roomCallback: nil, plainCost: 1, swampCost: 5,
      flee: false, maxOps: 2000, maxRooms: 16, heuristicWeight: 1.2)

proc search*(pf: PathFinder, goals: openArray[PFGoal], opts: PFOpts): PFResult {.importcpp.}
proc search*(pf: PathFinder, goals: openArray[PFGoal], flee: bool): PFResult {.importcpp.}
