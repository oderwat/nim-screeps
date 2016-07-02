task build, "build":
  setCommand("js")
  --d:nodejs
  --d:release
  switch("o","../../deploy/world1/main.js")
