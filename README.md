# coc-rescript

[![npm version](https://badge.fury.io/js/coc-rescript.svg)](https://badge.fury.io/js/coc-rescript)
[![](https://github.com/believer/coc-rescript/workflows/Release/badge.svg)](https://github.com/believer/coc-rescript/actions?workflow=Release)

[coc.nvim](https://github.com/neoclide/coc.nvim) extension for [ReScript](http://rescript-lang.org/).

The server is a rewrite of the [VS Code server](https://github.com/rescript-lang/rescript-vscode/) in ReScript. For now only formatting works.

## Features

- Formatting

### Upcoming features

- Error highlighting (This works when using the `master` version of `bs-platform`
  which has added a compiler output log. Hopefully it'll be released soon)

## Installation

```
:CocInstall coc-rescript
```

In order to get automatic formatting you need to add the following in your `:CocConfig`:

```json
{
  "coc.preferences.formatOnSaveFiletypes": ["rescript"]
}
```
