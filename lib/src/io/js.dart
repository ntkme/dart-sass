// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:cli_pkg/js.dart';
import 'package:js/js.dart';
import 'package:node_interop/fs.dart';
import 'package:node_interop/os.dart';
import 'package:node_interop/node_interop.dart' hide process;
import 'package:node_interop/util.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:watcher/watcher.dart';

import '../exception.dart';
import '../js/parcel_watcher.dart';

@JS('process')
external final Process? _nodeJsProcess; // process is null in the browser

/// The Node.JS [Process] global variable.
///
/// This value is `null` when running the script is not run from Node.JS
Process? get _process => isNodeJs ? _nodeJsProcess : null;

class FileSystemException {
  final String message;
  final String path;

  FileSystemException._(this.message, this.path);

  String toString() => "${p.prettyUri(p.toUri(path))}: $message";
}

void safePrint(Object? message) {
  if (_process case var process?) {
    process.stdout.write("${message ?? ''}\n");
  } else {
    console.log(message ?? '');
  }
}

void printError(Object? message) {
  if (_process case var process?) {
    process.stderr.write("${message ?? ''}\n");
  } else {
    console.error(message ?? '');
  }
}

String readFile(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("readFile() is only supported on Node.js");
  }
  // TODO(nweiz): explicitly decode the bytes as UTF-8 like we do in the VM when
  // it doesn't cause a substantial performance degradation for large files. See
  // also dart-lang/sdk#25377.
  var contents = _readFile(path, 'utf8') as String;
  if (!contents.contains("�")) return contents;

  var sourceFile = SourceFile.fromString(contents, url: p.toUri(path));
  for (var i = 0; i < contents.length; i++) {
    if (contents.codeUnitAt(i) != 0xFFFD) continue;
    throw SassException("Invalid UTF-8.", sourceFile.location(i).pointSpan());
  }

  // This should be unreachable.
  return contents;
}

/// Wraps `fs.readFileSync` to throw a [FileSystemException].
Object? _readFile(String path, [String? encoding]) =>
    _systemErrorToFileSystemException(() => fs.readFileSync(path, encoding));

void writeFile(String path, String contents) {
  if (!isNodeJs) {
    throw UnsupportedError("writeFile() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(
      () => fs.writeFileSync(path, contents));
}

void deleteFile(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("deleteFile() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() => fs.unlinkSync(path));
}

Future<String> readStdin() async {
  var process = _process;
  if (process == null) {
    throw UnsupportedError("readStdin() is only supported on Node.js");
  }
  var completer = Completer<String>();
  String contents;
  var innerSink = StringConversionSink.withCallback((String result) {
    contents = result;
    completer.complete(contents);
  });
  // Node defaults all buffers to 'utf8'.
  var sink = utf8.decoder.startChunkedConversion(innerSink);
  process.stdin.on('data', allowInterop(([Object? chunk]) {
    sink.add(chunk as List<int>);
  }));
  process.stdin.on('end', allowInterop(([Object? arg]) {
    // Callback for 'end' receives no args.
    assert(arg == null);
    sink.close();
  }));
  process.stdin.on('error', allowInterop(([Object? e]) {
    printError('Failed to read from stdin');
    printError(e);
    completer.completeError(e!);
  }));
  return completer.future;
}

/// Cleans up a Node system error's message.
String _cleanErrorMessage(JsSystemError error) {
  // The error message is of the form "$code: $text, $syscall '$path'". We just
  // want the text.
  return error.message.substring("${error.code}: ".length,
      error.message.length - ", ${error.syscall} '${error.path}'".length);
}

bool fileExists(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("fileExists() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    // `existsSync()` is faster than `statSync()`, but it doesn't clarify
    // whether the entity in question is a file or a directory. Since false
    // negatives are much more common than false positives, it works out in our
    // favor to check this first.
    if (!fs.existsSync(path)) return false;

    try {
      return fs.statSync(path).isFile();
    } catch (error) {
      var systemError = error as JsSystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

bool dirExists(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("dirExists() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    // `existsSync()` is faster than `statSync()`, but it doesn't clarify
    // whether the entity in question is a file or a directory. Since false
    // negatives are much more common than false positives, it works out in our
    // favor to check this first.
    if (!fs.existsSync(path)) return false;

    try {
      return fs.statSync(path).isDirectory();
    } catch (error) {
      var systemError = error as JsSystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

void ensureDir(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("ensureDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    try {
      fs.mkdirSync(path);
    } catch (error) {
      var systemError = error as JsSystemError;
      if (systemError.code == 'EEXIST') return;
      if (systemError.code != 'ENOENT') rethrow;
      ensureDir(p.dirname(path));
      fs.mkdirSync(path);
    }
  });
}

Iterable<String> listDir(String path, {bool recursive = false}) {
  if (!isNodeJs) {
    throw UnsupportedError("listDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    if (!recursive) {
      return fs
          .readdirSync(path)
          .map((child) => p.join(path, child as String))
          .where((child) => !dirExists(child));
    } else {
      Iterable<String> list(String parent) =>
          fs.readdirSync(parent).expand((child) {
            var path = p.join(parent, child as String);
            return dirExists(path) ? list(path) : [path];
          });

      return list(path);
    }
  });
}

DateTime modificationTime(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("modificationTime() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() =>
      DateTime.fromMillisecondsSinceEpoch(fs.statSync(path).mtime.getTime()));
}

String? getEnvironmentVariable(String name) {
  var env = _process?.env;
  return env == null ? null : getProperty(env as Object, name) as String?;
}

/// Runs callback and converts any [JsSystemError]s it throws into
/// [FileSystemException]s.
T _systemErrorToFileSystemException<T>(T callback()) {
  try {
    return callback();
  } catch (error) {
    if (error is! JsSystemError) rethrow;
    throw FileSystemException._(_cleanErrorMessage(error), error.path);
  }
}

/// Ignore `invalid_null_aware_operator` error, because [process.stdout.isTTY]
/// from `node_interop` declares `isTTY` as always non-nullably available, but
/// in practice it's undefined if stdout isn't a TTY.
/// See: https://github.com/pulyaevskiy/node-interop/issues/93
bool get hasTerminal => _process?.stdout.isTTY == true;

bool get isWindows => _process?.platform == 'win32';

bool get isMacOS => _process?.platform == 'darwin';

// Node seems to support ANSI escapes on all terminals.
bool get supportsAnsiEscapes => hasTerminal;

int get exitCode => _process?.exitCode ?? 0;

set exitCode(int code) => _process?.exitCode = code;

Future<Stream<WatchEvent>> watchDir(String path, {bool poll = false}) async {
  if (!isNodeJs) {
    throw UnsupportedError("watchDir() is only supported on Node.js");
  }

  StreamController<WatchEvent>? controller;
  if (poll) {
    var tmpdir = _systemErrorToFileSystemException(
        () => fs.mkdtempSync(p.join(os.tmpdir(), 'dart-sass-')));
    var currentSnapshot = p.join(tmpdir, '0');
    var previousSnapshot = p.join(tmpdir, '1');
    var processing = false;
    await ParcelWatcher.writeSnapshotFuture(path, currentSnapshot);
    var timer = Timer.periodic(Duration(seconds: 1), (Timer t) async {
      if (processing ||
          _systemErrorToFileSystemException(
              () => !fs.existsSync(currentSnapshot))) return;
      processing = true;

      _systemErrorToFileSystemException(
          () => fs.renameSync(currentSnapshot, previousSnapshot));
      await ParcelWatcher.writeSnapshotFuture(path, currentSnapshot);
      var events =
          await ParcelWatcher.getEventsSinceFuture(path, previousSnapshot);
      _systemErrorToFileSystemException(() => fs.unlinkSync(previousSnapshot));
      for (var event in events) {
        switch (event.type) {
          case 'create':
            controller?.add(WatchEvent(ChangeType.ADD, event.path));
          case 'update':
            controller?.add(WatchEvent(ChangeType.MODIFY, event.path));
          case 'delete':
            controller?.add(WatchEvent(ChangeType.REMOVE, event.path));
        }
      }

      processing = false;
    });
    return (controller = StreamController<WatchEvent>(onCancel: () {
      timer.cancel();
      _systemErrorToFileSystemException(() => fs.unlinkSync(currentSnapshot));
      _systemErrorToFileSystemException(() => fs.rmdirSync(tmpdir));
    }))
        .stream;
  } else {
    var subscription = await ParcelWatcher.subscribeFuture(path,
        (Object? error, List<ParcelWatcherEvent> events) {
      if (error != null) {
        controller?.addError(error);
      } else {
        for (var event in events) {
          switch (event.type) {
            case 'create':
              controller?.add(WatchEvent(ChangeType.ADD, event.path));
            case 'update':
              controller?.add(WatchEvent(ChangeType.MODIFY, event.path));
            case 'delete':
              controller?.add(WatchEvent(ChangeType.REMOVE, event.path));
          }
        }
      }
    });

    return (controller = StreamController<WatchEvent>(onCancel: () {
      subscription.unsubscribe();
    }))
        .stream;
  }
}
