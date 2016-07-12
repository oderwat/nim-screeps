# nop
# run nim build --hint[conf]:off main.nim
import ospaths

--d:logext # we use extened logging

hint("processing", off)
hint("successx", on)

#hint("conf", off)
#hint("path", off)


task build, "build":
  setCommand("js")
  --d:nodejs

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

  switch("o",thisDir() / "../../deploy/world1/main.js")
