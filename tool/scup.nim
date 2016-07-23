# nim build --hint[conf]:off
#
# This is a little tool to upload the screeps code to the server
#
# It uses the same config file as the screeps-terminal and
# expects two parameters. The first one is the file to upload
# and the second one is the branchname (which must exists already)
#
# This tool is build and run automatically by my world1 config script!

import httpclient
import base64
import json
import os
import strutils
#import yaml

const endpoint = "https://screeps.com/api/user/code"

#let programName = paramStr(0)
let arguments = commandLineParams()

let branch = arguments[1]
let filepath = arguments[0]

echo "File: " & filepath
echo "Branch: " & branch

#var s = newFileStream("~/.screeps_settings.yaml", fmRead)
#let config = s.loadTojson()
#s.close()

var user: string
var password: string

# really hacky way to read the config as yaml is broken atm
let fh = open(getHomeDir() / ".screeps_settings.yaml")
if fh == nil:
  echo "Could not open $HOME/screeps_settings.yaml"
  quit 5

for line in fh.lines:
  if line.startsWith "screeps_username: ":
    let s = line.split ": "
    user = s[1]
  if line.startsWith "screeps_password: ":
    let s = line.split ": "
    password = s[1]

close(fh)

if user == nil or password == nil:
  echo "could not determine user or password from yaml config"
  quit 5

## Extra headers can be specified and must be separated by \c\L
var headers = ""

let authString = user & ":" & password
let auth = encode(authString, lineLen=1024)

headers &= "Content-Type: application/json; charset=utf-8\c\L"
headers &= "Authorization: Basic " & auth & "\c\L"

#echo(headers)

if not fileExists(filepath):
  echo "File '" & filepath & "' not found"
  quit 5

let mainjs = readFile(filepath)

var data = %* {
        "branch": branch,
        "modules": {
            "main": mainjs,
        }
    }

#echo data
# just returning the answer from the server as status
echo post(endpoint, headers, $data)
