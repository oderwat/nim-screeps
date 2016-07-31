# nim js --d:nodejs --d:release
# Some stuff to extend how to deal with javascript from nim

# About "console.log" logging from Nim code:
#
# You should use log() and keep in mind that it adds spaces between parameter in the output

# standard console log
proc consoleLog*(s: cstring) {.importc: "console.log", varargs.}
proc stringify*[T](x: T): cstring {.importc: "JSON.stringify".}

proc isUndefined*[T](x: T): bool {.importcpp: "((#)==undefined)".}
proc isEmpty*[T](x: T): bool {.importcpp: "((#)=={})".}
proc isUndefinedOrEmpty*[T](x: T): bool = isUndefined(x) or isEmpty(x)

type JsObj* = ref object ## can be a string, an int etc.

#
# JSAssoc Type
#

type  JSAssoc*[Key, Val] = ref object
proc `[]`*[K,V](d: JSAssoc[K,V]; k: K): V {.importcpp: "#[#]".}
proc `[]=`*[K,V](d: JSAssoc[K,V]; k: K; v: V) {.importcpp: "#[#] = #".}
proc del*[K,V](d: JSAssoc[K,V]; k: K) {.importcpp: "delete #[#]".}
proc hasKey*[K,V](d: JSAssoc[K,V]; k: K): bool {.importcpp: "((#).hasOwnProperty(#))".}
template `.?`*(a: JSAssoc, f: untyped): untyped = a[astToStr(f)]

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

#
# JSArray Type
#

type JSArray*[T] = ref object
proc newJSArray*(T: typedesc): JSArray[T] {.importcpp: "[]@".}
proc `[]`*[T](d: JSArray[T]; idx: int): T {.importcpp: "#[#]".}
proc `[]=`*[T](d: JSArray[T]; idx: int; val: T) {.importcpp: "#[#] = #".}
proc del*[T](d: JSArray[T]; idx: int) {.importcpp: "delete #[#]".}
proc len*[T](d: JSArray[T]): int {.importcpp: "#.length".}
proc add*[T](d: var JSArray[T], val: T) {.importcpp: "#.push(#)".}

proc uniqueAdd*[T](s: JSArray[T], id: T): bool {.discardable.} =
  for old in s:
    if old == id:
      return true
  s.add id
  false

{.push warning[Uninit]:off.}

iterator items*[T](d: JSArray[T]): T =
  var v: T
  {.emit: "for (var k in `d`) {".}
  {.emit: "  `v`=`d`[k];".}
  yield v
  {.emit: "}".}

iterator pairs*[T](d: JSArray[T]): (int,T) =
  var k: int
  var v: T
  {.emit: "for (var `k` in `d`) {".}
  {.emit: "  `v`=`d`[`k`];".}
  yield (k, v)
  {.emit: "}".}

{.pop.}

proc sort* [T](objs: JSArray[T], sortcm: proc(a, b: T): int) {.importcpp: "#.sort(#)".}

#template `.?`*[T](a: T, f: untyped): untyped = a[astToStr(f)]

# cstring optimizations

converter stringToCString*(txt: string): cstring = txt.cstring
proc `&`*(a, b: cstring): cstring {.importcpp: "#+#"}
proc `&`*(a: cstring, b: int): cstring {.importcpp: "(#)+(#)"}
proc `&`*(a: int, b: cstring): cstring {.importcpp: "(#)+(#)"}
proc `&`*(a: cstring, b: float): cstring {.importcpp: "(#)+(#)"}
proc `&`*(a: float, b: cstring): cstring {.importcpp: "(#)+(#)"}
proc `$$`*(txt: cstring): cstring {.importcpp: "#" .}
proc `$$`*(txt: string): cstring = txt.cstring
proc `$$`*(num: int | float): cstring {.importcpp: "(''+(#))" .}

proc uniqueAdd*[T](s: var seq[T], id: T): bool {.discardable.} =
  for old in s:
    if old == id:
      return true
  s.add id
  false

proc sort* [T](objs: seq[T], sortcm: proc(a, b: T): int) {.importcpp: "#.sort(#)".}

when isMainModule:
  proc test() =
    {.emit: "var jsAssocTest = { 'foo': 1, 'bar': 2 };".}

    var jsAssocTest {.importcpp, nodecl.}: JSAssoc[cstring, int]

    for a,b in jsAssocTest:
      echo a, " ", b

    {.emit: "var jsArrayTest = [ 'foo', 'bar' ];".}

    var jsArrayTest {.importcpp, nodecl.}: JSArray[cstring]

    var s: seq[int]; s.add 1

    echo jsArrayTest.len
    for a in jsArrayTest:
      echo a
    for i, a in jsArrayTest:
      echo i, " ", a

    # type CSList = JSArray[cstring]
    # var obj: CSList# = newJSArray(cstring)
    # obj.add "test".cstring
    # echo obj[0]

  test()
