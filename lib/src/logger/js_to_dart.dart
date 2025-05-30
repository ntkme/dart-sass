// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import '../deprecation.dart';
import '../logger.dart';
import '../js/deprecations.dart' show deprecations;
import '../js/logger.dart';

/// A wrapper around a [JSLogger] that exposes it as a Dart [Logger].
final class JSToDartLogger extends LoggerWithDeprecationType {
  /// The wrapped logger object.
  final JSLogger? _node;

  /// The fallback logger to use if the [JSLogger] doesn't define a method.
  final Logger _fallback;

  /// Whether to use only ASCII characters when highlighting sections of source
  /// code.
  ///
  /// This defaults to [glyph.ascii].
  final bool _ascii;

  JSToDartLogger(this._node, this._fallback, {bool? ascii})
      : _ascii = ascii ?? glyph.ascii;

  void internalWarn(
    String message, {
    FileSpan? span,
    Trace? trace,
    Deprecation? deprecation,
  }) {
    if (_node?.warn case var warn?) {
      warn(
        message,
        WarnOptions(
          span: span ?? (undefined as SourceSpan?),
          stack: trace.toString(),
          deprecation: deprecation != null,
          deprecationType: deprecations[deprecation?.id],
        ),
      );
    } else {
      _withAscii(() {
        switch (_fallback) {
          case LoggerWithDeprecationType():
            _fallback.internalWarn(
              message,
              span: span,
              trace: trace,
              deprecation: deprecation,
            );
          case _:
            _fallback.warn(
              message,
              span: span,
              trace: trace,
              deprecation: deprecation != null,
            );
        }
      });
    }
  }

  void debug(String message, SourceSpan span) {
    if (_node?.debug case var debug?) {
      debug(message, DebugOptions(span: span));
    } else {
      _withAscii(() => _fallback.debug(message, span));
    }
  }

  /// Sets [glyph.ascii] to [_ascii] within [callback].
  T _withAscii<T>(T callback()) {
    var wasAscii = glyph.ascii;
    glyph.ascii = _ascii;
    try {
      return callback();
    } finally {
      glyph.ascii = wasAscii;
    }
  }
}
