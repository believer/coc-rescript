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

module Error = {
  let send = (error, ~id) => {
    {
      "jsonrpc": "2.0",
      "id": id,
      "error": error,
    }->Process.send
  }
}

module Message = {
  let send = (~id, ~result=None, ~method=None, ~params=None, ()) => {
    {
      "jsonrpc": "2.0",
      "id": id,
      "result": Js.Nullable.fromOption(result),
      "method": Js.Nullable.fromOption(method),
      "params": Js.Nullable.fromOption(params),
    }->Process.send
  }
}
