// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../deprecation.dart';
import '../io.dart';
import '../logger.dart';
import '../utils.dart';

/// A logger that prints warnings to standard error or browser console.
final class StderrLogger extends LoggerWithDeprecationType {
  /// Whether to use terminal colors in messages.
  final bool color;

  const StderrLogger({this.color = false});

  void internalWarn(
    String message, {
    FileSpan? span,
    Trace? trace,
    Deprecation? deprecation,
  }) {
    var result = StringBuffer();
    var showDeprecation =
        deprecation != null && deprecation != Deprecation.userAuthored;
    if (color) {
      // Bold yellow.
      result.write('\u001b[33m\u001b[1m');
      if (deprecation != null) result.write('Deprecation ');
      result.write('Warning\u001b[0m');
      if (showDeprecation) result.write(' [\u001b[34m$deprecation\u001b[0m]');
    } else {
      if (deprecation != null) result.write('DEPRECATION ');
      result.write('WARNING');
      if (showDeprecation) result.write(' [$deprecation]');
    }

    if (span == null) {
      result.writeln(': $message');
    } else if (trace != null) {
      // If there's a span and a trace, the span's location information is
      // probably duplicated in the trace, so we just use it for highlighting.
      result.writeln(': $message\n\n${span.highlight(color: color)}');
    } else {
      result.writeln(' on ${span.message("\n" + message, color: color)}');
    }

    if (trace != null) result.writeln(indent(trace.toString().trimRight(), 4));

    printError(result);
  }

  void debug(String message, SourceSpan span) {
    var result = StringBuffer();
    var url =
        span.start.sourceUrl == null ? '-' : p.prettyUri(span.start.sourceUrl);
    result.write('$url:${span.start.line + 1} ');
    result.write(color ? '\u001b[1mDebug\u001b[0m' : 'DEBUG');
    result.write(': $message');
    printError(result.toString());
  }
}
