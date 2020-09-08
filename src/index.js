const { LanguageClient } = require("coc.nvim");

exports.activate = (context) => {
  const serverOptions = {
    module: context.asAbsolutePath("./lsp/server.js"),
  };

  const documentSelector = [{ language: "rescript", scheme: "file" }];
  const synchronize = {
    configurationSection: "reason_language_server",
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
