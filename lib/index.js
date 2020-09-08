"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = void 0;
const coc_nvim_1 = require("coc.nvim");
exports.activate = (context) => {
    const serverOptions = {
        module: context.asAbsolutePath('./src/lsp/server.js'),
        args: ['--node-ipc'],
    };
    const documentSelector = [{ language: 'rescript', scheme: 'file' }];
    const synchronize = {
        configurationSection: 'rescript',
    };
    const clientOptions = { documentSelector, synchronize };
    const languageClient = new coc_nvim_1.LanguageClient('rescript', 'ReScript', serverOptions, clientOptions);
    context.subscriptions.push(coc_nvim_1.services.registLanguageClient(languageClient));
    coc_nvim_1.workspace.showMessage('ReScript installed');
};
//# sourceMappingURL=index.js.map