open Node

let start = () => {
  let bsbCompilerLog = Path.join(["lib", "bs", ".compiler.log"])
  let nodeModulesParentPath = Formatting.findDirOfFileNearFile(
    Formatting.bscPartialPath,
    bsbCompilerLog,
  )

  switch nodeModulesParentPath {
  | Some(path) =>
    let log = Path.join([path, bsbCompilerLog])

    Fs.access(log, err => {
      switch Js.Nullable.toOption(err) {
      | None => Fs.watch(log, (_, _) => {
          let file = Fs.readFileSync(bsbCompilerLog, {"encoding": "utf-8"})

          switch Js.String2.length(file) {
          | 0 =>
            Process.send({
              "method": "textDocument/publishDiagnostics",
              "params": {
                "diagnostics": [],
              },
            })
          | _ =>
            let (uri, diagnostics) = Parser.parse(file)

            Process.send({
              "method": "textDocument/publishDiagnostics",
              "params": {
                "uri": uri,
                "diagnostics": diagnostics,
              },
            })
          }
        })
      | Some(_) => ()
      }
    })
  | None => ()
  }
}
