type result = {
  code: string,
  message: string,
}

module ErrorCode = {
  type t = InvalidRequest

  let make = code => {
    switch code {
    | InvalidRequest => -32600
    }
  }
}

type t<'result, 'method, 'params, 'error> = {
  jsonrpc: string,
  id: string,
  result: Js.Nullable.t<'result>,
  method: Js.Nullable.t<'method>,
  params: Js.Nullable.t<'params>,
  error: Js.Nullable.t<'error>,
}

let make = (~id, ~result=None, ~error=None, ~method=None, ~params=None, ()) => {
  jsonrpc: "2.0",
  id: id,
  result: Js.Nullable.fromOption(result),
  method: Js.Nullable.fromOption(method),
  params: Js.Nullable.fromOption(params),
  error: Js.Nullable.fromOption(error),
}

let send = (~id, ~result=None, ~error=None, ~method=None, ~params=None, ()) => {
  make(~id, ~result, ~error, ~method, ~params, ())->Process.send
}
