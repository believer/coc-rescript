module Range = {
  let createStart = (line, character) =>
    {
      "line": line->int_of_string - 1,
      "character": character->int_of_string - 1,
    }

  let createEnd = (line, character) =>
    {
      "line": line->int_of_string - 1,
      "character": character->int_of_string,
    }

  let make = location => {
    switch location->Js.String2.match_(%re("/\d+/g")) {
    | Some([fromLine, fromChar, toLine, toChar]) =>
      Some({
        "start": createStart(fromLine, fromChar),
        "end": createEnd(toLine, toChar),
      })
    | Some([fromLine, fromChar, toChar]) =>
      Some({
        "start": createStart(fromLine, fromChar),
        "end": createEnd(fromLine, toChar),
      })
    | Some([fromLine, fromChar]) =>
      Some({
        "start": createStart(fromLine, fromChar),
        "end": createEnd(fromLine, fromChar),
      })
    | _ => None
    }
  }
}

module Severity = {
  let warning = "Warning number"
  let error = "We've found a bug for you!"
  let syntax = "Syntax error!"

  let isSeverity = (line, error) => line->Js.String2.trim->Js.String2.startsWith(error)
}

module Regex = {
  let filePath = %re("/[^\d:\s]+/")
  let codeLocation = %re("/\d+:\d+(-\d+(:\d+)?)?/")
  let codeDisplay = %re("/(^ {2,}[0-9]+)|(^ {5,})/")
  let message = %re(`/(^ {2,})|(^\w)/`)

  let getFirstFromMatch = (input, regex) =>
    input->Js.String2.match_(regex)->Belt.Option.getWithDefault([])->Belt.Array.get(0)

  let test = (input, regex) => regex->Js.Re.test_(input)
}

module Message = {
  let make = message =>
    message
    ->Belt.Array.keep(msg => msg->Js.String2.trim != "")
    ->Belt.Array.map(msg => msg->Js.String2.trim)
    ->Js.Array2.joinWith("\n")
}

module Diagnostic = {
  let make = (location, message) => {
    switch Range.make(location) {
    | Some(range) =>
      Some({
        "range": range,
        "message": Message.make(message),
        "severity": 1,
        "source": "rescript",
      })
    | _ => None
    }
  }
}

let parse = file => {
  let lines = file->Js.String2.split("\n")
  let errors = []
  let uriRef = ref("")

  for i in 0 to Belt.Array.length(lines) {
    switch lines->Belt.Array.get(i) {
    | Some(line) =>
      switch line {
      // Title lines start an error
      | line when line->Severity.isSeverity(Severity.warning) => errors->Js.Array2.push([])->ignore
      | line when line->Severity.isSeverity(Severity.error) => errors->Js.Array2.push([])->ignore
      | line when line->Severity.isSeverity(Severity.syntax) => errors->Js.Array2.push([])->ignore

      // Code display, don't add them
      | line when line->Regex.test(Regex.codeDisplay) => ()

      // Error message
      | line when line->Regex.test(Regex.message) =>
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
    switch error->Belt.Array.length {
    | 0 | 1 => None
    | _ =>
      switch (error->Belt.Array.get(0), error->Belt.Array.sliceToEnd(1)) {
      | (Some(loc), message) =>
        switch (
          loc->Regex.getFirstFromMatch(Regex.codeLocation),
          loc->Regex.getFirstFromMatch(Regex.filePath),
        ) {
        | (Some(location), Some(uri)) =>
          uriRef.contents = uri
          Diagnostic.make(location, message)
        | _ => None
        }
      | _ => None
      }
    }
  })->Belt.Array.keep(Belt.Option.isSome)

  (uriRef.contents, diagnostics)
}
