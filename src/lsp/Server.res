let initialized = ref(false)
let shutdownRequestAlreadyReceived = ref(false)
let contentCache = Js.Dict.empty()

let bscPartialPath = Node.Path.join(["node_modules", "bs-platform", Process.platform, "bsc.exe"])

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
    let {contentChanges} = params
    let {TextDocument.uri: uri} = getTextDocument(params)

    if Extension.isReScript(uri) {
      switch Belt.Array.length(contentChanges) {
      | 0 => ()
      | len =>
        switch contentChanges->Belt.Array.get(len - 1) {
        | Some({TextDocument.text: text}) => contentCache->Js.Dict.set(uri, text)
        | None => ()
        }
      }
    }
  }

  let didClose = params => {
    let {Process.Params.TextDocument.uri: uri} = Process.Params.getTextDocument(params)

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
    JsonRpc.send(~id, ~result, ())
  }

  let shutdown = id => {
    switch shutdownRequestAlreadyReceived.contents {
    | true =>
      let error = Some({
        "code": JsonRpc.ErrorCode.make(InvalidRequest),
        "message": "Language server already received the shutdown request",
      })

      JsonRpc.send(~id, ~error, ())
    | false =>
      shutdownRequestAlreadyReceived.contents = true

      JsonRpc.send(~id, ())
    }
  }

  let unknownMethod = id => {
    let error = Some({
      "code": JsonRpc.ErrorCode.make(InvalidRequest),
      "message": "Unrecognized editor request",
    })

    JsonRpc.send(~id, ~error, ())
  }
}

Process.on("message", ({id, method, params} as message) => {
  // Log message to output log
  Js.log(message)

  let method = Process.Method.make(method)

  switch Js.Nullable.toOption(id) {
  | None =>
    switch method {
    | Exit => Handler.exit()
    | DidOpen => Handler.didOpen(params)
    | DidChange => Handler.didChange(params)
    | DidClose => Handler.didClose(params)
    | Initialize | Initialized | Shutdown | Formatting | UnknownMethod => ()
    }
  | Some(id) =>
    switch method {
    | Initialize => Handler.initialize(id)
    | Initialized => JsonRpc.send(~id, ())
    | Shutdown => Handler.shutdown(id)
    | Formatting => Formatting.make(~params, ~id, ~bscPartialPath, ~contentCache)
    | DidChange | DidOpen | Exit | DidClose | UnknownMethod => Handler.unknownMethod(id)
    }
  }
})
