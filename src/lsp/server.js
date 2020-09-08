"use strict";
var __createBinding =
  (this && this.__createBinding) ||
  (Object.create
    ? function(o, m, k, k2) {
        if (k2 === undefined) k2 = k;
        Object.defineProperty(o, k2, {
          enumerable: true,
          get: function() {
            return m[k];
          },
        });
      }
    : function(o, m, k, k2) {
        if (k2 === undefined) k2 = k;
        o[k2] = m[k];
      });
var __setModuleDefault =
  (this && this.__setModuleDefault) ||
  (Object.create
    ? function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }
    : function(o, v) {
        o["default"] = v;
      });
var __importStar =
  (this && this.__importStar) ||
  function(mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null)
      for (var k in mod)
        if (k !== "default" && Object.hasOwnProperty.call(mod, k))
          __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
  };
var __importDefault =
  (this && this.__importDefault) ||
  function(mod) {
    return mod && mod.__esModule ? mod : { default: mod };
  };
Object.defineProperty(exports, "__esModule", { value: true });
const process_1 = __importDefault(require("process"));
const p = __importStar(require("vscode-languageserver-protocol"));
const m = __importStar(require("vscode-jsonrpc/lib/messages"));
const v = __importStar(require("vscode-languageserver"));
const path = __importStar(require("path"));
const fs_1 = __importDefault(require("fs"));
const childProcess = __importStar(require("child_process"));
const vscode_languageserver_protocol_1 = require("vscode-languageserver-protocol");
const tmp = __importStar(require("tmp"));
const vscode_uri_1 = require("vscode-uri");
// See https://microsoft.github.io/language-server-protocol/specification Abstract Message
// version is fixed to 2.0
let jsonrpcVersion = "2.0";
let bscPartialPath = path.join(
  "node_modules",
  "bs-platform",
  process_1.default.platform,
  "bsc.exe"
);
let bsbLogPartialPath = "bsb.log";
let resExt = ".res";
let resiExt = ".resi";
// https://microsoft.github.io/language-server-protocol/specification#initialize
// According to the spec, there could be requests before the 'initialize' request. Link in comment tells how to handle them.
let initialized = false;
// https://microsoft.github.io/language-server-protocol/specification#exit
let shutdownRequestAlreadyReceived = false;
let diagnosisTimer = null;
// congrats. A simple UI problem is now a distributed system problem
let stupidFileContentCache = {};
let findDirOfFileNearFile = (fileToFind, source) => {
  let dir = path.dirname(source);
  if (fs_1.default.existsSync(path.join(dir, fileToFind))) {
    return dir;
  } else {
    if (dir === source) {
      // reached top
      return null;
    } else {
      return findDirOfFileNearFile(fileToFind, dir);
    }
  }
};
let formatUsingValidBscPath = (code, bscPath, isInterface) => {
  // library cleans up after itself. No need to manually remove temp file
  let tmpobj = tmp.fileSync();
  let extension = isInterface ? resiExt : resExt;
  let fileToFormat = tmpobj.name + extension;
  fs_1.default.writeFileSync(fileToFormat, code, { encoding: "utf-8" });
  try {
    let result = childProcess.execFileSync(
      bscPath,
      ["-color", "never", "-format", fileToFormat],
      { stdio: "pipe" }
    );
    return {
      kind: "success",
      result: result.toString(),
    };
  } catch (e) {
    return {
      kind: "error",
      error: e.message,
    };
  }
};
let parseBsbOutputLocation = (location) => {
  // example bsb output location:
  // 3:9
  // 3:5-8
  // 3:9-6:1
  // language-server position is 0-based. Ours is 1-based. Don't forget to convert
  // also, our end character is inclusive. Language-server's is exclusive
  let isRange = location.indexOf("-") >= 0;
  if (isRange) {
    let [from, to] = location.split("-");
    let [fromLine, fromChar] = from.split(":");
    let isSingleLine = to.indexOf(":") >= 0;
    let [toLine, toChar] = isSingleLine ? to.split(":") : [fromLine, to];
    return {
      start: {
        line: parseInt(fromLine) - 1,
        character: parseInt(fromChar) - 1,
      },
      end: { line: parseInt(toLine) - 1, character: parseInt(toChar) },
    };
  } else {
    let [line, char] = location.split(":");
    let start = { line: parseInt(line) - 1, character: parseInt(char) };
    return {
      start: start,
      end: start,
    };
  }
};
let parseBsbLogOutput = (content) => {
  /* example bsb.log file content:

Cleaning... 6 files.
Cleaning... 87 files.
[1/5] [34mBuilding[39m [2msrc/TestFramework.reiast[22m
[2/5] [34mBuilding[39m [2msrc/TestFramework.reast[22m
[3/5] Building src/test.resast
FAILED: src/test.resast
/Users/chenglou/github/bucklescript/darwin/bsc.exe   -bs-jsx 3 -bs-no-version-header -o src/test.resast -bs-syntax-only -bs-binary-ast /Users/chenglou/github/reason-react/src/test.res

  Syntax error!
  /Users/chenglou/github/reason-react/src/test.res 1:8-2:3

  1 │ let a =
  2 │ let b =
  3 │

  This let-binding misses an expression

[8/29] Building src/legacy/ReactDOMServerRe.reast
FAILED: src/test.cmj src/test.cmi

  Warning number 8
  /Users/chenglou/github/reason-react/src/test.res 3:5-8

  1 │ let a = j`😀`
  2 │ let b = `😀`
  3 │ let None = None
  4 │ let bla: int = "
  5 │   hi

  You forgot to handle a possible case here, for example:
  Some _

  We've found a bug for you!
  /Users/chenglou/github/reason-react/src/test.res 3:9

  1 │ let a = 1
  2 │ let b = "hi"
  3 │ let a = b + 1

  This has type:
    string

  But somewhere wanted:
    int


[15/62] [34mBuilding[39m [2msrc/ReactDOMServer.reast[22m
    */
  // we're gonna chop that
  let res = [];
  let lines = content.split("\n");
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];
    if (line.startsWith("  We've found a bug for you!")) {
      res.push([]);
    } else if (line.startsWith("  Warning number ")) {
      res.push([]);
    } else if (line.startsWith("  Syntax error!")) {
      res.push([]);
    } else if (/^  [0-9]+ /.test(line)) {
      // code display. Swallow
    } else if (line.startsWith("  ")) {
      res[res.length - 1].push(line);
    }
  }
  // map of file path to list of diagnosis
  let ret = {};
  res.forEach((diagnosisLines) => {
    let [fileAndLocation, ...diagnosisMessage] = diagnosisLines;
    let locationSeparator = fileAndLocation.lastIndexOf(" ");
    let file = fileAndLocation.substring(2, locationSeparator);
    let location = fileAndLocation.substring(locationSeparator);
    if (ret[file] == null) {
      ret[file] = [];
    }
    let cleanedUpDiagnosis = diagnosisMessage
      .map((line) => {
        // remove the spaces in front
        return line.slice(2);
      })
      .join("\n")
      // remove start and end whitespaces/newlines
      .trim();
    ret[file].push({
      range: parseBsbOutputLocation(location),
      message: cleanedUpDiagnosis,
    });
  });
  return ret;
};
let startWatchingBsbOutputFile = (root, process) => {
  // TOOD: setTimeout instead
  let id = setInterval(() => {
    let openFiles = Object.keys(stupidFileContentCache);
    let bsbLogDirs = new Set();
    openFiles.forEach((openFile) => {
      let filePath = vscode_uri_1.uriToFsPath(
        vscode_uri_1.URI.parse(openFile),
        true
      );
      let bsbLogDir = findDirOfFileNearFile(bsbLogPartialPath, filePath);
      if (bsbLogDir != null) {
        bsbLogDirs.add(bsbLogDir);
      }
    });
    let files = {};
    let res = Array.from(bsbLogDirs).forEach((bsbLogDir) => {
      let bsbLogPath = path.join(bsbLogDir, bsbLogPartialPath);
      let content = fs_1.default.readFileSync(bsbLogPath, {
        encoding: "utf-8",
      });
      let filesAndErrors = parseBsbLogOutput(content);
      Object.keys(filesAndErrors).forEach((file) => {
        // assumption: there's no existing files[file] entry
        // this is true; see the lines above. A file can only belong to one bsb.log root
        files[file] = filesAndErrors[file];
      });
    });
    Object.keys(files).forEach((file) => {
      let params = {
        uri: file,
        // there's a new optional version param from https://github.com/microsoft/language-server-protocol/issues/201
        // not using it for now, sigh
        diagnostics: files[file],
      };
      let notification = {
        jsonrpc: jsonrpcVersion,
        method: "textDocument/publishDiagnostics",
        params: params,
      };
      process.send(notification);
    });
  }, 1000);
  return id;
};
let stopWatchingBsbOutputFile = (timerId) => {
  clearInterval(timerId);
};
process_1.default.on("message", (a) => {
  if (a.id == null) {
    // this is a notification message, aka client sent and forgot
    let aa = a;
    if (!initialized && aa.method !== "exit") {
      // From spec: "Notifications should be dropped, except for the exit notification. This will allow the exit of a server without an initialize request"
      // For us: do nothing. We don't have anything we need to clean up right now
      // TODO: think of fs watcher
    } else if (aa.method === "exit") {
      // The server should exit with success code 0 if the shutdown request has been received before; otherwise with error code 1
      if (shutdownRequestAlreadyReceived) {
        process_1.default.exit(0);
      } else {
        process_1.default.exit(1);
      }
    } else if (
      aa.method ===
      vscode_languageserver_protocol_1.DidOpenTextDocumentNotification.method
    ) {
      let params = aa.params;
      let extName = path.extname(params.textDocument.uri);
      if (extName === resExt || extName === resiExt) {
        stupidFileContentCache[params.textDocument.uri] =
          params.textDocument.text;
      }
    } else if (
      aa.method ===
      vscode_languageserver_protocol_1.DidChangeTextDocumentNotification.method
    ) {
      let params = aa.params;
      let extName = path.extname(params.textDocument.uri);
      if (extName === resExt || extName === resiExt) {
        let changes = params.contentChanges;
        if (changes.length === 0) {
          // no change?
        } else {
          // we currently only support full changes
          stupidFileContentCache[params.textDocument.uri] =
            changes[changes.length - 1].text;
        }
      }
    } else if (
      aa.method ===
      vscode_languageserver_protocol_1.DidCloseTextDocumentNotification.method
    ) {
      let params = aa.params;
      delete stupidFileContentCache[params.textDocument.uri];
    }
  } else {
    // this is a request message, aka client sent request, waits for our reply
    let aa = a;
    if (!initialized && aa.method !== "initialize") {
      let response = {
        jsonrpc: jsonrpcVersion,
        id: aa.id,
        error: {
          code: m.ErrorCodes.ServerNotInitialized,
          message: "Server not initialized.",
        },
      };
      process_1.default.send(response);
    } else if (aa.method === "initialize") {
      let param = aa.params;
      let root = param.rootUri;
      if (root == null) {
        // TODO: handle single file
        console.log("not handling single file");
      } else {
        // diagnosisTimer = startWatchingBsbOutputFile(root, process)
      }
      // send the list of things we support
      let result = {
        capabilities: {
          // TODO: incremental sync
          textDocumentSync: v.TextDocumentSyncKind.Full,
          documentFormattingProvider: true,
        },
      };
      let response = {
        jsonrpc: jsonrpcVersion,
        id: aa.id,
        result: result,
      };
      initialized = true;
      process_1.default.send(response);
    } else if (aa.method === "initialized") {
      // sent from client after initialize. Nothing to do for now
      let response = {
        jsonrpc: jsonrpcVersion,
        id: aa.id,
        result: null,
      };
      process_1.default.send(response);
    } else if (aa.method === "shutdown") {
      // https://microsoft.github.io/language-server-protocol/specification#shutdown
      if (shutdownRequestAlreadyReceived) {
        let response = {
          jsonrpc: jsonrpcVersion,
          id: aa.id,
          error: {
            code: m.ErrorCodes.InvalidRequest,
            message: `Language server already received the shutdown request`,
          },
        };
        process_1.default.send(response);
      } else {
        shutdownRequestAlreadyReceived = true;
        if (diagnosisTimer != null) {
          stopWatchingBsbOutputFile(diagnosisTimer);
        }
        let response = {
          jsonrpc: jsonrpcVersion,
          id: aa.id,
          result: null,
        };
        process_1.default.send(response);
      }
    } else if (aa.method === p.DocumentFormattingRequest.method) {
      let params = aa.params;
      let filePath = vscode_uri_1.uriToFsPath(
        vscode_uri_1.URI.parse(params.textDocument.uri),
        true
      );
      let extension = path.extname(params.textDocument.uri);
      if (extension !== resExt && extension !== resiExt) {
        let response = {
          jsonrpc: jsonrpcVersion,
          id: aa.id,
          error: {
            code: m.ErrorCodes.InvalidRequest,
            message: `Not a ${resExt} or ${resiExt} file.`,
          },
        };
        process_1.default.send(response);
      } else {
        let nodeModulesParentPath = findDirOfFileNearFile(
          bscPartialPath,
          filePath
        );
        if (nodeModulesParentPath == null) {
          let response = {
            jsonrpc: jsonrpcVersion,
            id: aa.id,
            error: {
              code: m.ErrorCodes.InvalidRequest,
              message: `Cannot find a nearby ${bscPartialPath}. It's needed for formatting.`,
            },
          };
          process_1.default.send(response);
        } else {
          // file to format potentially doesn't exist anymore because of races. But that's ok, the error from bsc should handle it
          let code = stupidFileContentCache[params.textDocument.uri];
          // TODO: error here?
          if (code === undefined) {
            console.log("can't find file");
          }
          let formattedResult = formatUsingValidBscPath(
            code,
            path.join(nodeModulesParentPath, bscPartialPath),
            extension === resiExt
          );
          if (formattedResult.kind === "success") {
            let result = [
              {
                range: {
                  start: { line: 0, character: 0 },
                  end: { line: Number.MAX_VALUE, character: Number.MAX_VALUE },
                },
                newText: formattedResult.result,
              },
            ];
            let response = {
              jsonrpc: jsonrpcVersion,
              id: aa.id,
              result: result,
            };
            process_1.default.send(response);
            let params2 = {
              uri: params.textDocument.uri,
              // there's a new optional version param from https://github.com/microsoft/language-server-protocol/issues/201
              // not using it for now, sigh
              diagnostics: [],
            };
            let notification = {
              jsonrpc: jsonrpcVersion,
              method: "textDocument/publishDiagnostics",
              params: params2,
            };
            process_1.default.send(notification);
          } else {
            let response = {
              jsonrpc: jsonrpcVersion,
              id: aa.id,
              result: [],
            };
            process_1.default.send(response);
            let filesAndErrors = parseBsbLogOutput(formattedResult.error);
            Object.keys(filesAndErrors).forEach((file) => {
              let params2 = {
                uri: params.textDocument.uri,
                // there's a new optional version param from https://github.com/microsoft/language-server-protocol/issues/201
                // not using it for now, sigh
                diagnostics: filesAndErrors[file],
              };
              let notification = {
                jsonrpc: jsonrpcVersion,
                method: "textDocument/publishDiagnostics",
                params: params2,
              };
              process_1.default.send(notification);
            });
          }
        }
      }
    } else {
      let response = {
        jsonrpc: jsonrpcVersion,
        id: aa.id,
        error: {
          code: m.ErrorCodes.InvalidRequest,
          message: "Unrecognized editor request.",
        },
      };
      process_1.default.send(response);
    }
  }
});
//# sourceMappingURL=server.js.map
