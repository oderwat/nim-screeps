# Some stuff to extend how to deal with javascript from nim

type
  JSAssoc*[Key, Val] = ref object

  JsObj* = ref object ## can be a string, an int etc.

# About "console.log" logging from Nim code:
#
# You should use log() and keep in mind that it adds spaces between parameter in the output

{.emit: staticRead("jslog.js") & "\n" .}
# specialized for logging into console with tags in arguments
proc jsLog*(s: cstring) {.importc: "jslog", varargs.}
# standard console log
proc consoleLog*(s: cstring) {.importc: "console.log", varargs.}
proc stringify*[T](x: T): cstring {.importc: "JSON.stringify".}

proc isUndefined*[T](x: T): bool {.importcpp: "((#)==undefined)".}
proc isEmpty*[T](x: T): bool {.importcpp: "((#)=={})".}
proc isUndefinedOrEmpty*[T](x: T): bool = isUndefined(x) or isEmpty(x)

proc `[]`*[K,V](d: JSAssoc[K,V]; k: K): V {.importcpp: "#[#]".}
proc `[]=`*[K,V](d: JSAssoc[K,V]; k: K; v: V) {.importcpp: "#[#] = #".}
proc hasKey*[K,V](d: JSAssoc[K,V]; k: K): bool {.importcpp: "((#).hasOwnProperty(#))".}

proc delete*[K,V](d: JSAssoc[K,V]; k: K) {.importcpp: "delete #[#]".}
proc sort* [T](objs: seq[T], sortcm: proc(a, b: T): int) {.importcpp: "#.sort(#)".}

template `.?`*(a: JSAssoc, f: untyped): auto = a[astToStr(f)]

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
