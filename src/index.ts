import {
  ExtensionContext,
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  services,
  workspace,
} from 'coc.nvim'

export const activate = (context: ExtensionContext) => {
  const serverOptions: ServerOptions = {
    args: ['--node-ipc'],
    module: context.asAbsolutePath('./lib/server.js'),
  }

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ language: 'rescript', scheme: 'file' }],
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

  workspace.showMessage('ReScript installed')
}
