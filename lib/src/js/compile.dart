// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:cli_pkg/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart' hide futureToPromise;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:path/path.dart' as p;

import '../../sass.dart' hide Deprecation;
import '../importer/no_op.dart';
import '../importer/js_to_dart/async.dart';
import '../importer/js_to_dart/async_file.dart';
import '../importer/js_to_dart/file.dart';
import '../importer/js_to_dart/sync.dart';
import '../importer/node_package.dart';
import '../io.dart';
import '../logger/js_to_dart.dart';
import '../util/nullable.dart';
import 'compile_options.dart';
import 'compile_result.dart';
import 'deprecations.dart';
import 'exception.dart';
import 'importer.dart';
import 'reflection.dart';
import 'utils.dart';

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
NodeCompileResult compile(String path, [CompileOptions? options]) {
  if (!isNodeJs) {
    jsThrow(JsError("The compile() method is only available in Node.js."));
  }
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  var logger = JSToDartLogger(
    options?.logger,
    Logger.stderr(color: color),
    ascii: ascii,
  );
  try {
    var result = compileToResult(
      path,
      color: color,
      loadPaths: options?.loadPaths,
      quietDeps: options?.quietDeps ?? false,
      style: _parseOutputStyle(options?.style),
      verbose: options?.verbose ?? false,
      charset: options?.charset ?? true,
      sourceMap: options?.sourceMap ?? false,
      logger: logger,
      importers: options?.importers?.map(_parseImporter),
      functions: _parseFunctions(options?.functions).cast(),
      fatalDeprecations: parseDeprecations(
        logger,
        options?.fatalDeprecations,
        supportVersions: true,
      ),
      silenceDeprecations: parseDeprecations(
        logger,
        options?.silenceDeprecations,
      ),
      futureDeprecations: parseDeprecations(
        logger,
        options?.futureDeprecations,
      ),
    );
    return _convertResult(
      result,
      includeSourceContents: options?.sourceMapIncludeSources ?? false,
    );
  } on SassException catch (error, stackTrace) {
    throwNodeException(error, color: color, ascii: ascii, trace: stackTrace);
  }
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
NodeCompileResult compileString(String text, [CompileStringOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  var logger = JSToDartLogger(
    options?.logger,
    Logger.stderr(color: color),
    ascii: ascii,
  );
  try {
    var result = compileStringToResult(
      text,
      syntax: parseSyntax(options?.syntax),
      url: options?.url.andThen(jsToDartUrl),
      color: color,
      loadPaths: options?.loadPaths,
      quietDeps: options?.quietDeps ?? false,
      style: _parseOutputStyle(options?.style),
      verbose: options?.verbose ?? false,
      charset: options?.charset ?? true,
      sourceMap: options?.sourceMap ?? false,
      logger: logger,
      importers: options?.importers?.map(_parseImporter),
      importer: options?.importer.andThen(_parseImporter) ??
          (options?.url == null ? NoOpImporter() : null),
      functions: _parseFunctions(options?.functions).cast(),
      fatalDeprecations: parseDeprecations(
        logger,
        options?.fatalDeprecations,
        supportVersions: true,
      ),
      silenceDeprecations: parseDeprecations(
        logger,
        options?.silenceDeprecations,
      ),
      futureDeprecations: parseDeprecations(
        logger,
        options?.futureDeprecations,
      ),
    );
    return _convertResult(
      result,
      includeSourceContents: options?.sourceMapIncludeSources ?? false,
    );
  } on SassException catch (error, stackTrace) {
    throwNodeException(error, color: color, ascii: ascii, trace: stackTrace);
  }
}

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise compileAsync(String path, [CompileOptions? options]) {
  if (!isNodeJs) {
    jsThrow(JsError("The compileAsync() method is only available in Node.js."));
  }
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  var logger = JSToDartLogger(
    options?.logger,
    Logger.stderr(color: color),
    ascii: ascii,
  );
  return _wrapAsyncSassExceptions(
    futureToPromise(() async {
      var result = await compileToResultAsync(
        path,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        charset: options?.charset ?? true,
        sourceMap: options?.sourceMap ?? false,
        logger: logger,
        importers: options?.importers?.map(
          (importer) => _parseAsyncImporter(importer),
        ),
        functions: _parseFunctions(options?.functions, asynch: true),
        fatalDeprecations: parseDeprecations(
          logger,
          options?.fatalDeprecations,
          supportVersions: true,
        ),
        silenceDeprecations: parseDeprecations(
          logger,
          options?.silenceDeprecations,
        ),
        futureDeprecations: parseDeprecations(
          logger,
          options?.futureDeprecations,
        ),
      );
      return _convertResult(
        result,
        includeSourceContents: options?.sourceMapIncludeSources ?? false,
      );
    }()),
    color: color,
    ascii: ascii,
  );
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise compileStringAsync(String text, [CompileStringOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  var logger = JSToDartLogger(
    options?.logger,
    Logger.stderr(color: color),
    ascii: ascii,
  );
  return _wrapAsyncSassExceptions(
    futureToPromise(() async {
      var result = await compileStringToResultAsync(
        text,
        syntax: parseSyntax(options?.syntax),
        url: options?.url.andThen(jsToDartUrl),
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        charset: options?.charset ?? true,
        sourceMap: options?.sourceMap ?? false,
        logger: logger,
        importers: options?.importers?.map(
          (importer) => _parseAsyncImporter(importer),
        ),
        importer: options?.importer.andThen(
              (importer) => _parseAsyncImporter(importer),
            ) ??
            (options?.url == null ? NoOpImporter() : null),
        functions: _parseFunctions(options?.functions, asynch: true),
        fatalDeprecations: parseDeprecations(
          logger,
          options?.fatalDeprecations,
          supportVersions: true,
        ),
        silenceDeprecations: parseDeprecations(
          logger,
          options?.silenceDeprecations,
        ),
        futureDeprecations: parseDeprecations(
          logger,
          options?.futureDeprecations,
        ),
      );
      return _convertResult(
        result,
        includeSourceContents: options?.sourceMapIncludeSources ?? false,
      );
    }()),
    color: color,
    ascii: ascii,
  );
}

/// Converts a Dart [CompileResult] into a JS API [NodeCompileResult].
NodeCompileResult _convertResult(
  CompileResult result, {
  required bool includeSourceContents,
}) {
  var sourceMap = result.sourceMap?.toJson(
    includeSourceContents: includeSourceContents,
  );
  if (sourceMap is Map<String, dynamic> && !sourceMap.containsKey('sources')) {
    // Dart's source map library can omit the sources key, but JS's type
    // declaration doesn't allow that.
    sourceMap['sources'] = <String>[];
  }

  var loadedUrls = toJSArray(result.loadedUrls.map(dartToJSUrl));
  return sourceMap == null
      // The JS API tests expects *no* source map here, not a null source map.
      ? NodeCompileResult(css: result.css, loadedUrls: loadedUrls)
      : NodeCompileResult(
          css: result.css,
          loadedUrls: loadedUrls,
          sourceMap: jsify(sourceMap),
        );
}

/// Catches `SassException`s thrown by [promise] and rethrows them as JS API
/// exceptions.
Promise _wrapAsyncSassExceptions(
  Promise promise, {
  required bool color,
  required bool ascii,
}) =>
    promise.then(
      null,
      allowInterop(
        (error) => error is SassException
            ? throwNodeException(error, color: color, ascii: ascii)
            : jsThrow(error as Object),
      ),
    );

/// Converts an output style string to an instance of [OutputStyle].
OutputStyle _parseOutputStyle(String? style) => switch (style) {
      null || 'expanded' => OutputStyle.expanded,
      'compressed' => OutputStyle.compressed,
      _ => jsThrow(JsError('Unknown output style "$style".')),
    };

/// Converts [importer] into an [AsyncImporter] that can be used with
/// [compileAsync] or [compileStringAsync].
AsyncImporter _parseAsyncImporter(Object? importer) {
  if (importer is NodePackageImporter) return importer;

  if (importer == null) jsThrow(JsError("Importers may not be null."));

  importer as JSImporter;
  var canonicalize = importer.canonicalize;
  var load = importer.load;
  if (importer.findFileUrl case var findFileUrl?) {
    if (canonicalize != null || load != null) {
      jsThrow(
        JsError(
          "An importer may not have a findFileUrl method as well as "
          "canonicalize and load methods.",
        ),
      );
    } else {
      return JSToDartAsyncFileImporter(findFileUrl);
    }
  } else if (canonicalize == null || load == null) {
    jsThrow(
      JsError(
        "An importer must have either canonicalize and load methods, or a "
        "findFileUrl method.",
      ),
    );
  } else {
    return JSToDartAsyncImporter(
      canonicalize,
      load,
      _normalizeNonCanonicalSchemes(importer.nonCanonicalScheme),
    );
  }
}

/// Converts [importer] into a synchronous [Importer].
Importer _parseImporter(Object? importer) {
  if (importer is NodePackageImporter) return importer;

  if (importer == null) jsThrow(JsError("Importers may not be null."));

  importer as JSImporter;
  var canonicalize = importer.canonicalize;
  var load = importer.load;
  if (importer.findFileUrl case var findFileUrl?) {
    if (canonicalize != null || load != null) {
      jsThrow(
        JsError(
          "An importer may not have a findFileUrl method as well as "
          "canonicalize and load methods.",
        ),
      );
    } else {
      return JSToDartFileImporter(findFileUrl);
    }
  } else if (canonicalize == null || load == null) {
    jsThrow(
      JsError(
        "An importer must have either canonicalize and load methods, or a "
        "findFileUrl method.",
      ),
    );
  } else {
    return JSToDartImporter(
      canonicalize,
      load,
      _normalizeNonCanonicalSchemes(importer.nonCanonicalScheme),
    );
  }
}

/// Converts a JS-style `nonCanonicalScheme` field into the form expected by
/// Dart classes.
List<String>? _normalizeNonCanonicalSchemes(Object? schemes) =>
    switch (schemes) {
      String scheme => [scheme],
      List<dynamic> schemes => schemes.cast<String>(),
      null => null,
      _ => jsThrow(
          JsError(
            'nonCanonicalScheme must be a string or list of strings, was '
            '"$schemes"',
          ),
        ),
    };

/// Implements the simplification algorithm for custom function return `Value`s.
/// See https://github.com/sass/sass/blob/main/spec/types/calculation.md#simplifying-a-calculationvalue
Value _simplifyValue(Value value) => switch (value) {
      SassCalculation() => switch ((
          // Match against...
          value.name, // ...the calculation name
          value.arguments // ...and simplified arguments
              .map(_simplifyCalcArg)
              .toList(),
        )) {
          ('calc', [var first]) => first as Value,
          ('calc', _) =>
            throw ArgumentError('calc() requires exactly one argument.'),
          ('clamp', [var min, var value, var max]) => SassCalculation.clamp(
              min,
              value,
              max,
            ),
          ('clamp', _) =>
            throw ArgumentError('clamp() requires exactly 3 arguments.'),
          ('min', var args) => SassCalculation.min(args),
          ('max', var args) => SassCalculation.max(args),
          (var name, _) => throw ArgumentError(
              '"$name" is not a recognized calculation type.'),
        },
      _ => value,
    };

/// Handles simplifying calculation arguments, which are not guaranteed to be
/// Value instances.
Object _simplifyCalcArg(Object value) => switch (value) {
      SassCalculation() => _simplifyValue(value),
      CalculationOperation() => SassCalculation.operate(
          value.operator,
          _simplifyCalcArg(value.left),
          _simplifyCalcArg(value.right),
        ),
      _ => value,
    };

/// Parses `functions` from [record] into a list of [Callable]s or
/// [AsyncCallable]s.
///
/// This is typed to always return [AsyncCallable], but in practice it will
/// return a `List<Callable>` if [asynch] is `false`.
List<AsyncCallable> _parseFunctions(Object? functions, {bool asynch = false}) {
  if (functions == null) return const [];

  var result = <AsyncCallable>[];
  jsForEach(functions, (signature, callback) {
    if (!asynch) {
      late Callable callable;
      callable = Callable.fromSignature(signature, (arguments) {
        var result = wrapJSExceptions(
          () => (callback as Function)(toJSArray(arguments)),
        );
        if (result is Value) return _simplifyValue(result);
        if (isPromise(result)) {
          throw 'Invalid return value for custom function '
              '"${callable.name}":\n'
              'Promises may only be returned for sass.compileAsync() and '
              'sass.compileStringAsync().';
        } else {
          throw 'Invalid return value for custom function '
              '"${callable.name}": $result is not a sass.Value.';
        }
      });
      result.add(callable);
    } else {
      late AsyncCallable callable;
      callable = AsyncCallable.fromSignature(signature, (arguments) async {
        var result = wrapJSExceptions(
          () => (callback as Function)(toJSArray(arguments)),
        );
        if (isPromise(result)) {
          result = await promiseToFuture<Object>(result as Promise);
        }

        if (result is Value) return _simplifyValue(result);
        throw 'Invalid return value for custom function '
            '"${callable.name}": $result is not a sass.Value.';
      });
      result.add(callable);
    }
  });
  return result;
}

/// The exported `NodePackageImporter` class that can be added to the
/// `importers` option to enable loading `pkg:` URLs from `node_modules`.
final JSClass nodePackageImporterClass = () {
  var jsClass = createJSClass(
    'sass.NodePackageImporter',
    (Object self, [String? entrypointDirectory]) => NodePackageImporter(
      switch ((entrypointDirectory, entrypointFilename)) {
        ((var directory?, _)) => directory,
        (_, var filename?) => p.dirname(filename),
        _ => throw "The Node package importer cannot determine an entry "
            "point because `require.main.filename` is not defined. Please "
            "provide an `entryPointDirectory` to the `NodePackageImporter`.",
      },
    ),
  );
  return jsClass;
}();
