import lexer, strutils

proc parse*(tokens: seq[Token]): (seq[TaskDef], seq[string]) =
    var tasks: seq[TaskDef] = @[]
    var execTargets: seq[string] = @[]
    var i = 0

    while i < tokens.len:
        case tokens[i].t_type
        of TokenKind.Task:
            if i + 1 >= tokens.len:
                write(stderr, "Unexpected end of tokens after Task\n")
                quit 1

            var taskName: string
            if tokens[i+1].t_type == StringLiteral:
                taskName = tokens[i+1].value
            elif tokens[i+1].t_type == Identifier:
                taskName = tokens[i+1].value
            else:
                write(stderr, "Expected task name after 'task'\n")
                quit 1

            i += 2

            var dependencies: seq[string] = @[]

            while i < tokens.len and tokens[i].t_type != Newline and tokens[i].t_type != Do:
                if tokens[i].t_type == Colon:
                    i += 1
                    while i < tokens.len and tokens[i].t_type != Newline and tokens[i].t_type != Do:
                        var depPattern: string
                        if tokens[i].t_type == StringLiteral:
                            depPattern = tokens[i].value
                        elif tokens[i].t_type == Identifier:
                            depPattern = tokens[i].value
                        else:
                            i += 1
                            continue

                        let expanded = expandGlob(depPattern)
                        if expanded.len > 0:
                            dependencies.add(expanded)
                        else:
                            dependencies.add(depPattern)

                        i += 1
                    break
                i += 1

            while i < tokens.len and tokens[i].t_type == Newline:
                i += 1

            if i >= tokens.len or tokens[i].t_type != Do:
                write(stderr, "Expected 'do' after task declaration\n")
                quit 1

            i += 1

            var commands: seq[string] = @[]
            var currentCmd: seq[string] = @[]

            while i < tokens.len and tokens[i].t_type != End:
                if tokens[i].t_type == Newline:
                    if currentCmd.len > 0:
                        commands.add(currentCmd.join(" "))
                        currentCmd = @[]
                else:
                    currentCmd.add(tokens[i].value)
                i += 1

            if currentCmd.len > 0:
                commands.add(currentCmd.join(" "))

            if i < tokens.len and tokens[i].t_type == End:
                i += 1

            tasks.add(TaskDef(name: taskName, commands: commands,
                            dependencies: dependencies))

        of TokenKind.Exec:
            i += 1
            while i < tokens.len and tokens[i].t_type != Newline:
                if tokens[i].t_type == StringLiteral:
                    execTargets.add(tokens[i].value)
                elif tokens[i].t_type == Identifier:
                    execTargets.add(tokens[i].value)
                i += 1

        else:
            i += 1

    return (tasks, execTargets)
