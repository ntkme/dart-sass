// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:meta/meta.dart';

import '../exception.dart';
import '../utils.dart';
import '../value.dart';
import 'async_built_in.dart';

/// An interface for functions and mixins that can be invoked from Sass by
/// passing in arguments.
///
/// This class represents callables that *need* to do asynchronous work. It's
/// only compatible with the asynchronous `compile()` methods. If a callback can
/// work synchronously, it should be a [Callable] instead.
///
/// See [Callable] for more details.
///
/// {@category Compile}
@sealed
abstract interface class AsyncCallable {
  /// The callable's name.
  String get name;

  @Deprecated('Use `AsyncCallable.function` instead.')
  factory AsyncCallable(
    String name,
    String arguments,
    FutureOr<Value> callback(List<Value> arguments),
  ) =>
      AsyncCallable.function(name, arguments, callback);

  /// Creates a callable with the given [name] and [arguments] that runs
  /// [callback] when called.
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// See [Callable.new] for more details.
  factory AsyncCallable.function(
    String name,
    String arguments,
    FutureOr<Value> callback(List<Value> arguments),
  ) =>
      AsyncBuiltInCallable.function(name, arguments, callback);

  /// Creates a callable with a single [signature] and a single [callback].
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory AsyncCallable.fromSignature(
    String signature,
    FutureOr<Value> callback(List<Value> arguments), {
    bool requireParens = true,
  }) {
    var (name, declaration) = parseSignature(
      signature,
      requireParens: requireParens,
    );
    return AsyncBuiltInCallable.parsed(name, declaration, callback);
  }
}
