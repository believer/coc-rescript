import {
  ExtensionContext,
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  services,
} from 'coc.nvim'

export const activate = (context: ExtensionContext) => {
  const serverOptions: ServerOptions = {
    args: ['--node-ipc'],
    module: context.asAbsolutePath('./src/lsp/server.js'),

    options: {},
  }

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ language: 'rescript' }],
    synchronize: {
      configurationSection: 'rescript',
    },
  }

  const languageClient = new LanguageClient(
    'rescript',
    'ReScript',
    serverOptions,
    clientOptions,
    true
  )

  context.subscriptions.push(services.registLanguageClient(languageClient))
}
