task build, "build":
  try:
    exec "nim compile --hint[conf]:off scup.nim"
    exec "chmod +x ../bin/scup"
  except:
    echo "Build of scup failed!"
    quit 5

task compile, "compile":
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

  hint("processing", off)
  hint("link", off)
  hint("successx", on)

  switch("d","ssl")
  switch("d","release")
  switch("o","../bin/scup")
  setCommand("c")
