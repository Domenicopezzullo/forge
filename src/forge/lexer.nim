import strutils, os

proc expandGlob*(pattern: string): seq[string] =
    var results: seq[string] = @[]

    if '*' notin pattern:
        return @[pattern]

    let parts = pattern.split('/')
    var dirPath = ""
    var globPart = ""

    for i, part in parts:
        if '*' in part:
            globPart = part
            if i > 0:
                dirPath = parts[0..<i].join("/")
            break
        elif i < parts.len - 1:
            if dirPath.len > 0:
                dirPath &= "/"
            dirPath &= part

    if dirPath.len == 0:
        dirPath = "."

    if dirExists(dirPath):
        for kind, path in walkDir(dirPath):
            let filename = path.split('/')[^1]
            if globPart == "*" or
               (globPart.startsWith("*") and filename.endsWith(globPart[1..^1])) or
               (globPart.endsWith("*") and filename.startsWith(globPart[0..^2])):
                results.add(path)

    return results

type TokenKind* = enum
    Task, Do, End, Exec, Colon, Identifier, StringLiteral, Newline

type Token* = object
    t_type*: TokenKind
    value*: string

type TaskDef* = object
    name*: string
    commands*: seq[string]
    dependencies*: seq[string]

proc lexLine(input: string, inTaskDeclaration: bool): seq[Token] =
    var tokens: seq[Token] = @[]
    var i = 0
    let line = input.strip()

    if line.len == 0:
        return tokens

    while i < line.len:
        while i < line.len and line[i] in Whitespace:
            i += 1

        if i >= line.len:
            break

        if inTaskDeclaration and line[i] == ':':
            tokens.add(Token(t_type: Colon, value: ":"))
            i += 1
            continue

        if line[i] == '"':
            var str = ""
            i += 1
            while i < line.len and line[i] != '"':
                str.add(line[i])
                i += 1
            if i < line.len:
                i += 1
            tokens.add(Token(t_type: StringLiteral, value: str))
            continue

        var word = ""
        while i < line.len and line[i] notin Whitespace:
            if inTaskDeclaration and line[i] == ':':
                break
            word.add(line[i])
            i += 1

        if word.len > 0:
            var t: Token
            case word
            of "task": t.t_type = TokenKind.Task
            of "do": t.t_type = Do
            of "end": t.t_type = End
            of "exec": t.t_type = Exec
            else: t.t_type = Identifier
            t.value = word
            tokens.add(t)

    return tokens

proc lex*(content: string): seq[Token] =
    var alltokens: seq[Token] = @[]
    var inTaskBlock = false

    for line in content.splitLines():
        let trimmed = line.strip()

        if trimmed.startsWith("task "):
            inTaskBlock = true
        elif trimmed == "do":
            inTaskBlock = false

        let lineTokens = lexLine(line, inTaskBlock)
        if lineTokens.len > 0:
            alltokens.add(lineTokens)
        alltokens.add Token(t_type: Newline, value: "\n")

    return alltokens
