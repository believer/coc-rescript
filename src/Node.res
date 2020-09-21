module Path = {
  @module("path") @splice external join: array<string> => string = "join"
  @module("path") @splice external resolve: array<string> => string = "resolve"

  @module("path") external extName: string => string = "extname"
  @module("path") external dirname: string => string = "dirname"
}

module Fs = {
  @module("fs") external existsSync: string => bool = "existsSync"
  @module("fs") external writeFileSync: (string, string, 'a) => unit = "writeFileSync"
  @module("fs") external readFileSync: (string, 'a) => string = "readFileSync"
  @module("fs") external watch: (string, ('a, string) => unit) => unit = "watch"
  @module("fs") external access: (string, Js.Nullable.t<'a> => unit) => unit = "access"
}

module ChildProcess = {
  type result

  @module("child_process")
  external execFileSync: (string, array<string>, 'a) => result = "execFileSync"

  type fork

  @send external send: (fork, 'a) => unit = "send"

  @module("child_process")
  external fork: string => fork = "execFileSync"

  let resultToString: result => string = %raw(`function (result) { return result.toString() }`)
}
