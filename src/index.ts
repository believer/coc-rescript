import {
  ExtensionContext,
  LanguageClient,
  LanguageClientOptions,
  OutputChannel,
  ServerOptions,
  TransportKind,
  Uri,
  workspace,
} from 'coc.nvim'
import { resolve } from 'path'
import { TextDocument } from 'vscode-languageserver-textdocument'

export function activate(context: ExtensionContext) {
  const module = resolve(context.extensionPath, 'src', 'lsp', 'server.js')
  const outputChannel: OutputChannel = workspace.createOutputChannel('rescript')

  async function didOpenTextDocument(document: TextDocument): Promise<void> {
    const uri = Uri.parse(document.uri)

    if (uri.scheme !== 'file') {
      return
    }

    const serverOptions: ServerOptions = {
      run: { module, transport: TransportKind.ipc },
      debug: { module },
    }

    const clientOptions: LanguageClientOptions = {
      documentSelector: [
        { language: 'rescript', scheme: 'file', pattern: '*.{res,resi}' },
      ],
      diagnosticCollectionName: 'rescript',
      outputChannel,
      synchronize: {
        configurationSection: 'rescript',
      },
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
