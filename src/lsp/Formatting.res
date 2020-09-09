@bs.val("MAX_VALUE") @bs.scope("Number") external maxValue: int = "MAX_VALUE"
@bs.module external parseError: string => 'a = "../parser.js"

module Tmp = {
  @bs.module("tmp") external fileSync: unit => 'a = "fileSync"
}

let rec findDirOfFileNearFile = (fileToFind, source) => {
  open Node

  let dir = Path.dirname(source)

  if Fs.existsSync(Path.join([dir, fileToFind])) {
    Some(dir)
  } else if dir === source {
    None
  } else {
    findDirOfFileNearFile(fileToFind, dir)
  }
}

let usingValidBscPath = (code, bscPath, isInterface) => {
  open Node

  let tmpobj = Tmp.fileSync()

  let extension = isInterface ? Extension.resi : Extension.res
  let fileToFormat = tmpobj["name"] ++ extension

  Fs.writeFileSync(fileToFormat, code, {"encoding": "utf-8"})

  try {
    let result = ChildProcess.execFileSync(
      bscPath,
      ["-color", "never", "-format", fileToFormat],
      {"stdio": "pipe"},
    )

    Ok(ChildProcess.resultToString(result))
  } catch {
  | Js.Exn.Error(obj) =>
    switch Js.Exn.message(obj) {
    | Some(m) => Error(m)
    | None => Error("Unknown error")
    }
  }
}

let make = (~params, ~id, ~bscPartialPath, ~contentCache) => {
  let {Process.Params.TextDocument.uri: uri} = Process.Params.getTextDocument(params)
  let filePath = uri->Js.String2.replace("file://", "")

  switch Extension.isReScript(uri) {
  | false =>
    let error = Some({
      "code": JsonRpc.ErrorCode.make(InvalidRequest),
      "message": "Not a .res or .resi file",
    })

    JsonRpc.make(~id, ~error, ())->Process.send
  | true => {
      let nodeModulesParentPath = findDirOfFileNearFile(bscPartialPath, filePath)

      switch nodeModulesParentPath {
      | None =>
        let error = Some({
          "code": JsonRpc.ErrorCode.make(InvalidRequest),
          "message": "Cannot find a nearby ${bscPartialPath}. It's needed for
          formatting.",
        })

        JsonRpc.make(~id, ~error, ())->Process.send
      | Some(path) => {
          let code = contentCache->Js.Dict.get(uri)

          switch code {
          | None => ()
          | Some(code) => {
              let formatted = usingValidBscPath(
                code,
                Node.Path.join([path, bscPartialPath]),
                Extension.get(uri) == Extension.resi,
              )

              switch formatted {
              | Ok(formattedResult) => {
                  let result = Some([
                    {
                      "range": {
                        "start": {"line": 0, "character": 0},
                        "end": {"line": maxValue, "character": maxValue},
                      },
                      "newText": formattedResult,
                    },
                  ])

                  JsonRpc.send(~id, ~result, ())

                  Process.send({
                    "method": "textDocument/publishDiagnostics",
                    "params": {
                      "uri": uri,
                      "diagnostics": [],
                    },
                  })
                }

              | Error(fileErr) => {
                  Js.log2("Formatting failed", fileErr)

                  let diagnostics = parseError(fileErr)

                  Process.send({
                    "method": "textDocument/publishDiagnostics",
                    "params": {
                      "uri": uri,
                      "diagnostics": diagnostics,
                    },
                  })
                }
              }
            }
          }
        }
      }
    }
  }
}
