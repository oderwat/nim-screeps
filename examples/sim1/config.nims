task build, "build":
  setCommand("js")
  --d:nodejs
  --d:release
  switch("o","../../deploy/sim1/main.js")
