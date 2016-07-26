# nop
# run nim build --hint[conf]:off main.nim
import ospaths

# deploy location
let deployDir = thisDir() / "../../deploy/world1"
# tool location
let toolDir = thisDir() / "../../tool"
# bin location
let binDir = thisDir() / "../../bin"

--d:logext # we use extened logging
#--d:logci # logging with caller info (file / line)

--d:js # so nimsuggest has a clue that we build for js backend
--d:nodejs

hint("processing", off)
hint("successx", on)

#hint("conf", off)
#hint("path", off)

if fileExists(thisDir() / "../../src/screeps.nim"):
  switch("path",thisDir() / "../../src")

task build, "build":
  # compiling our script
  try:
    exec("nim compile_js --hint[conf]:off main.nim")
  except:
    quit 5

  # compiling the upload tool if needed
  var buildTool = not fileExists(bindir / "scup")
  if not buildTool:
    withDir toolDir:
      # well.. there is no way to compare files timestamps yet for nimscript afaik
      let test = staticExec("find ../bin -name scup -not -mnewer scup.nim")
      if test != "":
        buildTool = true

  if buildTool:
    withDir toolDir:
      echo("Building upload tool...");
      try:
        exec("nim build --hint[conf]:off scup.nim")
        echo("ok!");
      except:
        quit 5

  try:
    exec(binDir / "scup \"" & deployDir / "main.js\" " & "world1")
  except:
    echo "error while sending script to server!"
    quit 5

task compile_js, "compileJS":
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
