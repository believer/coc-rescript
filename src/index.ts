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
    module: context.asAbsolutePath('./lib/server.js'),
    args: ['--node-ipc'],
  }

  const documentSelector = [{ language: 'rescript', scheme: 'file' }]
  const synchronize = {
    configurationSection: 'rescript',
  }
  const clientOptions: LanguageClientOptions = { documentSelector, synchronize }

  const languageClient = new LanguageClient(
    'rescript',
    'ReScript',
    serverOptions,
    clientOptions
  )

  context.subscriptions.push(services.registLanguageClient(languageClient))

  workspace.showMessage('ReScript installed')
}
