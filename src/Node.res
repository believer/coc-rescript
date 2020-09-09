module Path = {
  @bs.module("path") @bs.splice external join: array<string> => string = "join"
  @bs.module("path") @bs.splice external resolve: array<string> => string = "resolve"

  @bs.module("path") external extName: string => string = "extname"
  @bs.module("path") external dirname: string => string = "dirname"
}

module Fs = {
  @bs.module("fs") external existsSync: string => bool = "existsSync"
  @bs.module("fs") external writeFileSync: (string, string, 'a) => unit =
  "writeFileSync"
}

module ChildProcess = {
  type result

  @bs.module("child_process")
  external execFileSync: (string, array<string>, 'a) => result = "execFileSync"

  let resultToString: result => string = %raw(`function (result) { return result.toString() }`)
}
