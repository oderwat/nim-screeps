# nim check --verbosity:2 --hints:off
#
# A Part of Screeps Nim module
#
# Some stuff to extend how to deal with javascript from nim
#
# (c) 2016 by Hans Raaf (METATEXX GmbH)

type
  JSAssoc*[Key, Val] = ref object

  JsObj* = ref object ## can be a string, an int etc.

# About "console.log" logging from Nim code:
#
# You should use log() and keep in mind that it adds spaces between parameter in the output

# standard console log
proc consoleLog*(s: cstring) {.importc: "console.log", varargs.}
proc stringify*[T](x: T): cstring {.importc: "JSON.stringify".}

proc isUndefined*[T](x: T): bool {.importcpp: "((#)==undefined)".}
proc isEmpty*[T](x: T): bool {.importcpp: "((#)=={})".}
proc isUndefinedOrEmpty*[T](x: T): bool = isUndefined(x) or isEmpty(x)

proc `[]`*[K,V](d: JSAssoc[K,V]; k: K): V {.importcpp: "#[#]".}
proc `[]=`*[K,V](d: JSAssoc[K,V]; k: K; v: V) {.importcpp: "#[#] = #".}
proc hasKey*[K,V](d: JSAssoc[K,V]; k: K): bool {.importcpp: "((#).hasOwnProperty(#))".}

proc uniqueAdd*[T](s: var seq[T], id: T): bool {.discardable.} =
  for old in s:
    if old == id:
      return true
  s.add id
  false

proc delete*[K,V](d: JSAssoc[K,V]; k: K) {.importcpp: "delete #[#]".}
proc sort* [T](objs: seq[T], sortcm: proc(a, b: T): int) {.importcpp: "#.sort(#)".}

template `.?`*(a: JSAssoc, f: untyped): untyped = a[astToStr(f)]
#template `.?`*[T](a: T, f: untyped): untyped = a[astToStr(f)]

{.push warning[Uninit]:off.}
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
{.pop.}

converter stringToCString*(txt: string): cstring = txt.cstring
proc `&`*(a, b: cstring): cstring {.importcpp: "#+#"}
proc `&`*(a: cstring, b: int): cstring {.importcpp: "(#)+(#)"}
proc `&`*(a: int, b: cstring): cstring {.importcpp: "(#)+(#)"}
proc `&`*(a: cstring, b: float): cstring {.importcpp: "(#)+(#)"}
proc `&`*(a: float, b: cstring): cstring {.importcpp: "(#)+(#)"}
proc `$$`*(txt: cstring): cstring {.importcpp: "#" .}
proc `$$`*(txt: string): cstring = txt.cstring
proc `$$`*(num: int | float): cstring {.importcpp: "(''+(#))" .}

when isMainModule:
  {.emit: "var jsTest = { 'foo': 1, 'bar': 2 };".}

  var jsTest {.importcpp, nodecl.}: JSAssoc[cstring, int]

  for a,b in jsTest:
    echo a, " ", b
