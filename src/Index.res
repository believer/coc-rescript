open Coc

let activate = (context: ExtensionContext.t) => {
  let language = #rescript
  let lsp = Node.Path.resolve([context.extensionPath, "src", "lsp", "server.js"])
  let documentSelector = [Document.make(~language, ())]

  LanguageClient.make(
    language,
    "ReScript",
    Server.make(~lsp, ()),
    Client.make(~documentSelector, ~outputChannel="rescript"),
  ).start()
}
