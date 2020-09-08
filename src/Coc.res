module Language = {
  type t = [#rescript]
}

module Transport = {
  type t = IPC

  let make = transport =>
    switch transport {
    | IPC => 1
    }
}

module Server = {
  type run = {
    @bs.as("module") lsp: string,
    transport: int,
  }

  type debug = {@bs.as("module") lsp: string}

  type t = {run: run, debug: debug}

  let make = (~lsp, ~transport=Transport.IPC, ()) => {
    run: {
      lsp: lsp,
      transport: Transport.make(transport),
    },
    debug: {
      lsp: lsp,
    },
  }
}

module OutputChannel = {
  type t

  @bs.module("coc.nvim") @bs.scope("workspace") external make: string => t = "createOutputChannel"
}

module Document = {
  module Scheme = {
    type t = File

    let toString = file =>
      switch file {
      | File => "file"
      }
  }

  type t = {
    language: Language.t,
    scheme: string,
  }

  let make = (~language, ~scheme=Scheme.File, ()) => {
    language: language,
    scheme: Scheme.toString(scheme),
  }
}

module Client = {
  type t = {
    documentSelector: array<Document.t>,
    outputChannel: OutputChannel.t,
  }

  let make = (~documentSelector, ~outputChannel) => {
    documentSelector: documentSelector,
    outputChannel: OutputChannel.make(outputChannel),
  }
}

module LanguageClient = {
  type t 

  @bs.module("coc.nvim") @bs.new
  external make: (Language.t, string, Server.t, Client.t) => t = "LanguageClient"

  @bs.send external start: t => unit = "start"
}

module ExtensionContext = {
  type t = {extensionPath: string}
}
