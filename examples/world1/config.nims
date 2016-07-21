# nop
# run nim build --hint[conf]:off main.nim
import ospaths

# deploy location
let deployDir = thisDir() / "../../deploy/world1"

--d:logext # we use extened logging
--d:logci # logging with caller info (file / line)

--d:js # so nimsuggest has a clue that we build for js backend
--d:nodejs

hint("processing", off)
hint("successx", on)

#hint("conf", off)
#hint("path", off)

if fileExists(thisDir() / "../../src/screeps.nim"):
  switch("path",thisDir() / "../../src")

task build, "build":
  setCommand("js")

  var quick = false
  var release = true

  if quick or release: # -d:release
    --obj_checks:off
    --field_checks:off
    --range_checks:off
    --bound_checks:off
    --overflow_checks:off
    --assertions:off
    --stacktrace:off
    --linetrace:off
    --debugger:off
    --line_dir:off
    --dead_code_elim:on

  if release:
    --opt:speed

  mkdir(deployDir)
  switch("o", deployDir / "main.js")
