const { LanguageClient } = require("coc.nvim");

exports.activate = (context) => {
  const serverOptions = {
    module: context.asAbsolutePath("./lsp/server.js"),
    args: ["--node-ipc"],
  };

  const documentSelector = [{ language: "rescript", scheme: "file" }];
  const synchronize = {
    configurationSection: "rescript",
  };
  const clientOptions = { documentSelector, synchronize };

  const languageClient = new LanguageClient(
    "rescript",
    "ReScript",
    serverOptions,
    clientOptions
  );

  context.subscriptions.push(services.registLanguageClient(languageClient));
};
