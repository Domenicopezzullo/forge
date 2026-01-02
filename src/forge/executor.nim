import osproc, times, os, lexer, tables, strutils

proc needsRebuild*(task: TaskDef, taskMap: Table[string, TaskDef]): bool =
    let targetIsFile = fileExists(task.name)

    if not targetIsFile and task.dependencies.len == 0:
        return true

    if not targetIsFile and task.dependencies.len > 0:
        return true

    if not fileExists(task.name):
        return true

    if task.dependencies.len == 0:
        return false

    let targetTime = getLastModificationTime(task.name)

    for dep in task.dependencies:
        if dep in taskMap:
            if fileExists(dep):
                let depTime = getLastModificationTime(dep)
                if depTime > targetTime:
                    return true
        elif fileExists(dep):
            let depTime = getLastModificationTime(dep)
            if depTime > targetTime:
                return true
        else:
            return true

    return false

proc executeTask*(taskName: string, taskMap: Table[string, TaskDef],
                executed: var seq[string], inProgress: var seq[string],
                anyExecuted: var bool) =

    if taskName in executed:
        return

    if taskName in inProgress:
        write(stderr, "Circular dependency detected: ", taskName, "\n")
        quit 1

    if taskName notin taskMap:
        write(stderr, "Unknown task: ", taskName, "\n")
        quit 1

    inProgress.add(taskName)
    let task = taskMap[taskName]

    for dep in task.dependencies:
        if dep in taskMap:
            executeTask(dep, taskMap, executed, inProgress, anyExecuted)

    if not needsRebuild(task, taskMap):
        let idx = inProgress.find(taskName)
        if idx >= 0:
            inProgress.delete(idx)
        executed.add(taskName)
        return

    anyExecuted = true
    echo "\n[", taskName, "]"

    for cmd in task.commands:
        echo "  $ ", cmd
        let (output, exitCode) = execCmdEx(cmd)
        if exitCode != 0:
            write(stderr, "Command failed: ", cmd, "\n")
            write(stderr, output)
            quit 1
        if output.len > 0 and output.strip().len > 0:
            for line in output.strip().splitLines():
                echo "    ", line

    let idx = inProgress.find(taskName)
    if idx >= 0:
        inProgress.delete(idx)
    executed.add(taskName)
