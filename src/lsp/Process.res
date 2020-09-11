module Params = {
  module TextDocument = {
    type t = {uri: string, text: string}
  }

  type t = {
    textDocument: TextDocument.t,
    contentChanges: array<TextDocument.t>,
  }

  let getTextDocument = params => params.textDocument
}

module Method = {
  type t =
    | DidChange
    | DidClose
    | DidOpen
    | Exit
    | Formatting
    | Initialize
    | Initialized
    | PublishDiagnostics
    | Shutdown
    | UnknownMethod

  let toString = method =>
    switch method {
    | DidChange => "textDocument/didChange"
    | DidClose => "textDocument/didClose"
    | DidOpen => "textDocument/didOpen"
    | Formatting => "textDocument/formatting"
    | PublishDiagnostics => "textDocument/publishDiagnostics"
    | Exit => "exit"
    | Initialize => "initialize"
    | Initialized => "initialized"
    | Shutdown => "shutdown"
    | UnknownMethod => ""
    }

  let make = method =>
    switch method {
    | "textDocument/didChange" => DidChange
    | "textDocument/didClose" => DidClose
    | "textDocument/didOpen" => DidOpen
    | "textDocument/formatting" => Formatting
    | "textDocument/publishDiagnostics" => PublishDiagnostics
    | "exit" => Exit
    | "initialize" => Initialize
    | "initialized" => Initialized
    | "shutdown" => Shutdown
    | _ => UnknownMethod
    }
}

module Message = {
  type t = {id: Js.Nullable.t<string>, method: string, params: Params.t}
}

@bs.module("process") external on: (string, Message.t => unit) => unit = "on"
@bs.module("process") external exit: int => unit = "exit"
@bs.module("process") external send: 'a => unit = "send"
@bs.module("process") external platform: string = "platform"
@bs.module("process") external cwd: unit => string = "cwd"
