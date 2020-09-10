let createStart = (~line, ~character) =>
  {
    "line": line->int_of_string - 1,
    "character": character->int_of_string - 1,
  }

let createEnd = (~line, ~character) =>
  {
    "line": line->int_of_string - 1,
    "character": character->int_of_string,
  }

let parseLocation = location => {
  switch location->Js.String2.match_(%re("/\d+/g")) {
  | Some([fromLine, fromChar, toLine, toChar]) =>
    Some({
      "start": createStart(~line=fromLine, ~character=fromChar),
      "end": createEnd(~line=toLine, ~character=toChar),
    })
  | Some([fromLine, fromChar, toChar]) =>
    Some({
      "start": createStart(~line=fromLine, ~character=fromChar),
      "end": createEnd(~line=fromLine, ~character=toChar),
    })
  | Some([fromLine, fromChar]) =>
    Some({
      "start": createStart(~line=fromLine, ~character=fromChar),
      "end": createEnd(~line=fromLine, ~character=fromChar),
    })
  | _ => None
  }
}

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

      | line when %re(`/(^ {2,}[0-9]+)/`)->Js.Re.test_(line) => ()
      | line when %re(`/^ {2,}/`)->Js.Re.test_(line) =>
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
          ->Js.String2.match_(%re("/[^\d:\s]+/"))
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

          switch range {
          | Some(range) =>
            Some({
              "range": range,
              "message": message,
              "severity": 1,
              "source": "rescript",
            })
          | _ => None
          }

        | _ => None
        }
      }
    | _ => None
    }
  })->Belt.Array.keep(Belt.Option.isSome)

  (uriRef.contents, diagnostics)
}
