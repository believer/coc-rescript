let initialized = ref(false)
let shutdownRequestAlreadyReceived = ref(false)
let contentCache = Js.Dict.empty()

module Handler = {
  open Process.Params

  let exit = () => {
    switch shutdownRequestAlreadyReceived.contents {
    | true => Process.exit(0)
    | false => Process.exit(1)
    }
  }

  let didOpen = params => {
    let {TextDocument.uri: uri, text} = getTextDocument(params)

    if Extension.isReScript(uri) {
      contentCache->Js.Dict.set(uri, text)
    }
  }

  let didChange = params => {
    let {contentChanges, _} = params
    let {TextDocument.uri: uri, _} = getTextDocument(params)

    if Extension.isReScript(uri) {
      switch Belt.Array.length(contentChanges) {
      | 0 => ()
      | len =>
        switch contentChanges->Belt.Array.get(len - 1) {
        | Some({TextDocument.text: text, _}) => contentCache->Js.Dict.set(uri, text)
        | None => ()
        }
      }
    }
  }

  let didClose = params => {
    let {Process.Params.TextDocument.uri: uri, _} = Process.Params.getTextDocument(params)

    Js.Dict.unsafeDeleteKey(. contentCache, uri)
  }

  let initialize = id => {
    let result = Some({
      "capabilities": {
        "textDocumentSync": TextDocumentSyncKind.make(Full),
        "documentFormattingProvider": true,
      },
    })

    initialized.contents = true
    Rpc.Message.send(~id, ~result, ())
  }

  let shutdown = id => {
    switch shutdownRequestAlreadyReceived.contents {
    | true =>
      Some({
        "code": Rpc.ErrorCode.make(InvalidRequest),
        "message": "Language server already received the shutdown request",
      })->Rpc.Error.send(~id)
    | false =>
      shutdownRequestAlreadyReceived.contents = true

      Rpc.Message.send(~id, ())
    }
  }

  let unknownMethod = id => {
    Some({
      "code": Rpc.ErrorCode.make(InvalidRequest),
      "message": "Unrecognized editor request",
    })->Rpc.Error.send(~id)
  }
}

Process.on("message", ({id, method, params}) => {
  let method = Process.Method.make(method)

  switch Js.Nullable.toOption(id) {
  | None =>
    switch method {
    | Exit => Handler.exit()
    | DidOpen => Handler.didOpen(params)
    | DidChange => Handler.didChange(params)
    | DidClose => Handler.didClose(params)
    | PublishDiagnostics | Initialize | Initialized | Shutdown | Formatting | UnknownMethod => ()
    }
  | Some(id) =>
    switch method {
    | Initialize => Handler.initialize(id)
    | Initialized => Rpc.Message.send(~id, ())
    | Shutdown => Handler.shutdown(id)
    | Formatting => Formatting.make(~params, ~id, ~contentCache)
    | PublishDiagnostics | DidChange | DidOpen | Exit | DidClose | UnknownMethod =>
      Handler.unknownMethod(id)
    }
  }
})

Watcher.start()
