import os, strutils, forge/[lexer, parser, executor], tables


let command_params = commandLineParams()
var forgefile_path = "Forgefile"
var cmdLineTargets: seq[string] = @[]

if command_params.len > 0:
    if fileExists(command_params[0]) and (command_params[0].contains("Forgefile") or command_params[0].endsWith("file")):
        forgefile_path = command_params[0]
        for i in 1..<command_params.len:
            cmdLineTargets.add(command_params[i])
    else:
        cmdLineTargets = command_params

if not fileExists(forgefile_path):
    write(stderr, "Forgefile not found: ", forgefile_path, "\n")
    quit 1

let forgefile = readFile(forgefile_path)
let tokens = lex(forgefile)
let (tasks, execTargets) = parse(tokens)

var taskMap = initTable[string, TaskDef]()
for task in tasks:
    taskMap[task.name] = task

var targetsToRun: seq[string]
if cmdLineTargets.len > 0:
    targetsToRun = cmdLineTargets
elif execTargets.len > 0:
    targetsToRun = execTargets
else:
    echo "\nNo targets specified. Available tasks:"
    for taskName in taskMap.keys:
        echo "  - ", taskName
    quit 0

var executed: seq[string] = @[]
var inProgress: seq[string] = @[]
var anyExecuted = false

for target in targetsToRun:
    executeTask(target, taskMap, executed, inProgress, anyExecuted)

if not anyExecuted:
    echo "Nothing to do."
