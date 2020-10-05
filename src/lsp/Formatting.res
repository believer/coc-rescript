@val("MAX_VALUE") @scope("Number") external maxValue: int = "MAX_VALUE"

module Tmp = {
  @module("tmp") external fileSync: unit => 'a = "fileSync"
}

let bscPartialPath = Node.Path.join(["node_modules", "bs-platform", Process.platform, "bsc.exe"])

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

let make = (~params, ~id, ~contentCache) => {
  let {Process.Params.TextDocument.uri: uri, _} = Process.Params.getTextDocument(params)
  let filePath = uri->Js.String2.replace("file://", "")

  switch Extension.isReScript(uri) {
  | false =>
    Some({
      "code": Rpc.ErrorCode.make(InvalidRequest),
      "message": "Not a .res or .resi file",
    })->Rpc.Error.send(~id)
  | true => {
      let nodeModulesParentPath = findDirOfFileNearFile(bscPartialPath, filePath)

      switch nodeModulesParentPath {
      | None =>
        Some({
          "code": Rpc.ErrorCode.make(InvalidRequest),
          "message": "Cannot find a nearby ${bscPartialPath}. It's needed for
          formatting.",
        })->Rpc.Error.send(~id)
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

                  Rpc.Message.send(~id, ~result, ())

                  Process.send({
                    "method": Process.Method.toString(PublishDiagnostics),
                    "params": {
                      "uri": uri,
                      "diagnostics": [],
                    },
                  })
                }

              | Error(_) => ()
              }
            }
          }
        }
      }
    }
  }
}
