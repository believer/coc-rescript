open TestFramework
open Parser

describe("#parseLocation", ({test}) => {
  test("handle locations", ({expect}) => {
    expect.value(Range.make("13:3-14:1")).toEqual(
      Some({
        "start": {"line": 12, "character": 2},
        "end": {"line": 13, "character": 1},
      }),
    )

    expect.value(Range.make("13:3")).toEqual(
      Some({
        "start": {"line": 12, "character": 2},
        "end": {"line": 12, "character": 3},
      }),
    )

    expect.value(Range.make("32:16-20")).toEqual(
      Some({
        "start": {"line": 31, "character": 15},
        "end": {"line": 31, "character": 20},
      }),
    )
  })
})

describe("#parse", ({test}) => {
  let createDiagnostic = (~message, ~start, ~end) => {
    let (startChar, startLine) = start
    let (endChar, endLine) = end

    Some({
      "message": message,
      "range": {
        "end": {
          "character": endChar,
          "line": endLine,
        },
        "start": {
          "character": startChar,
          "line": startLine,
        },
      },
      "severity": 1,
      "source": "rescript",
    })
  }
  test("handles syntax errors", ({expect}) => {
    let error = `
  Syntax error!
  /coc-rescript/src/Parser.res:32:16-20
  
  30 │ module Severity = {
  31 │   let warning = "Warning number
  32 │   let error = "We've found a bug for you!"
  33 │   let syntax = "Syntax error!"
  34 │ }
  
  consecutive statements on a line must be separated by ';' or a newline
    `

    expect.value(parse(error)).toEqual((
      "/coc-rescript/src/Parser.res",
      [
        createDiagnostic(
          ~message="consecutive statements on a line must be separated by ';' or a newline",
          ~start=(15, 31),
          ~end=(20, 31),
        ),
      ],
    ))
  })

  test("handles warnings", ({expect}) => {
    let error = `
  Warning number 26
  /coc-rescript/src/Parser.res:67:9
  
  65 ┆ 
  66 ┆ let diagnostics = errors->Belt.Array.map(error => {
  67 ┆   let t = ""
  68 ┆   let fileAndLocation = error->Belt.Array.get(0)
  69 ┆   let message = error->Belt.Array.sliceToEnd(1)
  
  unused variable t.
    `

    expect.value(parse(error)).toEqual((
      "/coc-rescript/src/Parser.res",
      [createDiagnostic(~message="unused variable t.", ~start=(8, 66), ~end=(9, 66))],
    ))
  })

  test("handles error", ({expect}) => {
    let error = `
  We've found a bug for you!
  /coc-rescript/src/Parser.res:67:11
  
  65 ┆ 
  66 ┆ let t = ""
  67 ┆ let i = t + 1
  68 ┆ 
  69 ┆ let diagnostics = errors->Belt.Array.map(error => {
  
  This has type:
    string

  But somewhere wanted:
    int


  You can convert string to int with Belt.Int.fromString.
    `

    expect.value(parse(error)).toEqual((
      "/coc-rescript/src/Parser.res",
      [
        createDiagnostic(
          ~message=`This has type:
string
But somewhere wanted:
int
You can convert string to int with Belt.Int.fromString.`,
          ~start=(10, 66),
          ~end=(11, 66),
        ),
      ],
    ))
  })

  test("handles multiple errors", ({expect}) => {
    let error = `
  Syntax error!
  /coc-rescript/src/Parser.res:38:16-20
  
  36 │ module Severity = {
  37 │   let warning = "Warning number
  38 │   let error = "We've found a bug for you!"
  39 │   let syntax = "Syntax error!"
  40 │ 
  
  consecutive statements on a line must be separated by ";" or a newline

  Syntax error!
  /coc-rescript/src/Parser.res:38:41
  
  36 │ module Severity = {
  37 │   let warning = "Warning number
  38 │   let error = "We've found a bug for you!"
  39 │   let syntax = "Syntax error!"
  40 │ 
  
  Did you forget a "in" here? 

  Syntax error!
  /coc-rescript/src/Parser.res:45:25
  
  43 │ 
  44 │ module Regex = {
  45 │   let filePath = %re("test")
  46 │   let codeLocation = %re("test")
  47 │   let codeDisplay = %re("test")
  
  Hmm, not sure what I should do here with this character.
If you're trying to deref an expression, use "foo.contents" instead.
    `

    expect.value(parse(error)).toEqual((
      "/coc-rescript/src/Parser.res",
      [
        createDiagnostic(
          ~message=`consecutive statements on a line must be separated by ";" or a newline`,
          ~start=(15, 37),
          ~end=(20, 37),
        ),
        createDiagnostic(~message=`Did you forget a "in" here?`, ~start=(40, 37), ~end=(41, 37)),
        createDiagnostic(
          ~message=`Hmm, not sure what I should do here with this character.
If you're trying to deref an expression, use "foo.contents" instead.`,
          ~start=(24, 44),
          ~end=(25, 44),
        ),
      ],
    ))
  })

  test("handles type errors", ({expect}) => {
    let error =
      [
        "  Syntax error!",
        "  /coc-rescript/src/Parser.res:80:3-6",
        "  ",
        "  78 │ ",
        "  79 │ module Question = ",
        "  80 │   type t = Question(string)",
        "  81 │   type error<'a> = [> #QuestionTooShortError(int) | #QuestionMissingQu",
        "       estionMarkError] as 'a",
        "  82 │ }",
        "  ",
        "  `type` is a reserved keyword. Keywords need to be escaped: \\\"type\"",
      ]->Js.Array2.joinWith("\n")

    expect.value(parse(error)).toEqual((
      "/coc-rescript/src/Parser.res",
      [
        createDiagnostic(
          ~message="`type` is a reserved keyword. Keywords need to be escaped: \\\"type\"",
          ~start=(2, 79),
          ~end=(6, 79),
        ),
      ],
    ))
  })

  test("handles malformed errors", ({expect}) => {
    let error = ["  Syntax error!"]->Js.Array2.joinWith("\n")

    expect.value(parse(error)).toEqual(("", []))
  })
})
