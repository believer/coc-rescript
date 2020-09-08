import {
  ExtensionContext,
  LanguageClient,
  LanguageClientOptions,
  OutputChannel,
  ServerOptions,
  TransportKind,
  workspace,
} from 'coc.nvim'
import { resolve } from 'path'
import { TextDocument } from 'vscode-languageserver-textdocument'

export function activate(context: ExtensionContext) {
  const module = resolve(context.extensionPath, 'src', 'lsp', 'server.js')
  const outputChannel: OutputChannel = workspace.createOutputChannel('rescript')

  async function didOpenTextDocument(_document: TextDocument): Promise<void> {
    const serverOptions: ServerOptions = {
      run: { module, transport: TransportKind.ipc },
      debug: { module },
    }

    const clientOptions: LanguageClientOptions = {
      documentSelector: [{ language: 'rescript', scheme: 'file' }],
      outputChannel,
    }

    const client = new LanguageClient(
      'rescript',
      'ReScript',
      serverOptions,
      clientOptions
    )

    client.start()
  }

  workspace.onDidOpenTextDocument(didOpenTextDocument)
}
