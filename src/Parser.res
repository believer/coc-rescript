let parseLocation: string => 'a = %raw(
  `
function parseLocation (location) {
  if (location.includes('-')) {
    let [from, to] = location.split('-')
    let [fromLine, fromChar] = from.split(':')
    let isSingleLine = to.includes(':')
    let [toLine, toChar] = isSingleLine ? to.split(':') : [fromLine, to]

    return {
      start: {
        line: parseInt(fromLine) - 1,
        character: parseInt(fromChar) - 1,
      },
      end: { line: parseInt(toLine) - 1, character: parseInt(toChar) },
    }
  } else {
    let [line, char] = location.split(':')
    let end = { line: parseInt(line) - 1, character: parseInt(char) }

    return {
      start: { ...end, character: end.character - 1 },
      end,
    }
  }
}
`
)

module Severity = {
  let warning = "Warning number"
  let error = "We've found a bug for you!"
  let syntax = "Syntax error!"
}

let parse = file => {
  let lines = file->Js.String2.split("\n")
  let errors = []
  let uriRef = ref("")

  for i in 0 to Belt.Array.length(lines) {
    let line = lines->Belt.Array.get(i)

    switch line {
    | Some(line) =>
      switch line {
      | line when line->Js.String2.trim->Js.String2.startsWith(Severity.warning) =>
        errors->Js.Array2.push([])->ignore
      | line when line->Js.String2.trim->Js.String2.startsWith(Severity.error) =>
        errors->Js.Array2.push([])->ignore
      | line when line->Js.String2.trim->Js.String2.startsWith(Severity.syntax) =>
        errors->Js.Array2.push([])->ignore

      | line when %re(`/(^ {2,}[0-9]+)|(^ {3,})/`)->Js.Re.test_(line) => ()
      | line when line->Js.String2.startsWith("  ") =>
        switch errors->Belt.Array.get(Belt.Array.length(errors) - 1) {
        | Some(arr) => arr->Js.Array2.push(line)->ignore
        | None => ()
        }
      | _ => ()
      }
    | None => ()
    }
  }

  let diagnostics = errors->Belt.Array.map(error => {
    let fileAndLocation = error->Belt.Array.get(0)
    let message = error->Belt.Array.sliceToEnd(1)

    switch (fileAndLocation, message) {
    | (Some(loc), message) => {
        let uri =
          loc
          ->Js.String2.match_(%re("/[^\s\d+:\d+(\d+(:\d+)?)?]+/"))
          ->Belt.Option.getWithDefault([])
          ->Belt.Array.get(0)
        let location =
          loc
          ->Js.String2.match_(%re("/\d+:\d+(-\d+(:\d+)?)?/"))
          ->Belt.Option.getWithDefault([])
          ->Belt.Array.get(0)

        switch (location, uri) {
        | (Some(location), Some(uri)) =>
          uriRef.contents = uri

          let range = parseLocation(location)
          let message =
            message
            ->Belt.Array.keep(msg => msg->Js.String2.trim != "")
            ->Belt.Array.map(msg => msg->Js.String2.trim)
            ->Js.Array2.joinWith("\n")

          Some({
            "range": range,
            "message": message,
            "severity": 1,
            "source": "rescript",
          })
        | _ => None
        }
      }
    | _ => None
    }
  })->Belt.Array.keep(Belt.Option.isSome)

  (uriRef.contents, diagnostics)
}
