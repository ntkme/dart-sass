// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../deprecation.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../callable.dart';
import '../util/character.dart';
import '../util/nullable.dart';
import '../util/number.dart' as number_lib;
import '../utils.dart';
import '../value.dart';
import '../visitor/interface/value.dart';
import '../visitor/serialize.dart';

/// A SassScript calculation.
///
/// Although calculations can in principle have any name or any number of
/// arguments, this class only exposes the specific calculations that are
/// supported by the Sass spec. This ensures that all calculations that the user
/// works with are always fully simplified.
///
/// {@category Value}
final class SassCalculation extends Value {
  /// The calculation's name, such as `"calc"`.
  final String name;

  /// The calculation's arguments.
  ///
  /// Each argument is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], or a [CalculationOperation].
  final List<Object> arguments;

  /// @nodoc
  @internal
  bool get isSpecialNumber => true;

  /// Creates a new calculation with the given [name] and [arguments]
  /// that will not be simplified.
  @internal
  static SassCalculation unsimplified(
    String name,
    Iterable<Object> arguments,
  ) =>
      SassCalculation._(name, List.unmodifiable(arguments));

  /// Creates a `calc()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value calc(Object argument) => switch (_simplify(argument)) {
        SassNumber value => value,
        SassCalculation value => value,
        var simplified => SassCalculation._(
            "calc",
            List.unmodifiable([simplified]),
          ),
      };

  /// Creates a `min()` calculation with the given [arguments].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation]. It must be passed at
  /// least one argument.
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value min(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("min() must have at least one argument.");
    }

    SassNumber? minimum;
    for (var arg in args) {
      if (arg is! SassNumber ||
          (minimum != null && !minimum.isComparableTo(arg))) {
        minimum = null;
        break;
      } else if (minimum == null || minimum.greaterThan(arg).isTruthy) {
        minimum = arg;
      }
    }
    if (minimum != null) return minimum;

    _verifyCompatibleNumbers(args);
    return SassCalculation._("min", args);
  }

  /// Creates a `max()` calculation with the given [arguments].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation]. It must be passed at
  /// least one argument.
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value max(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("max() must have at least one argument.");
    }

    SassNumber? maximum;
    for (var arg in args) {
      if (arg is! SassNumber ||
          (maximum != null && !maximum.isComparableTo(arg))) {
        maximum = null;
        break;
      } else if (maximum == null || maximum.lessThan(arg).isTruthy) {
        maximum = arg;
      }
    }
    if (maximum != null) return maximum;

    _verifyCompatibleNumbers(args);
    return SassCalculation._("max", args);
  }

  /// Creates a `hypot()` calculation with the given [arguments].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation]. It must be passed at
  /// least one argument.
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value hypot(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("hypot() must have at least one argument.");
    }
    _verifyCompatibleNumbers(args);

    var subtotal = 0.0;
    var first = args.first;
    if (first is! SassNumber || first.hasUnit('%')) {
      return SassCalculation._("hypot", args);
    }
    for (var i = 0; i < args.length; i++) {
      var number = args.elementAt(i);
      if (number is! SassNumber || !number.hasCompatibleUnits(first)) {
        return SassCalculation._("hypot", args);
      }
      var value = number.convertValueToMatch(
        first,
        "numbers[${i + 1}]",
        "numbers[1]",
      );
      subtotal += value * value;
    }
    return SassNumber.withUnits(
      math.sqrt(subtotal),
      numeratorUnits: first.numeratorUnits,
      denominatorUnits: first.denominatorUnits,
    );
  }

  /// Creates a `sqrt()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value sqrt(Object argument) =>
      _singleArgument("sqrt", argument, number_lib.sqrt, forbidUnits: true);

  /// Creates a `sin()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value sin(Object argument) =>
      _singleArgument("sin", argument, number_lib.sin);

  /// Creates a `cos()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value cos(Object argument) =>
      _singleArgument("cos", argument, number_lib.cos);

  /// Creates a `tan()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value tan(Object argument) =>
      _singleArgument("tan", argument, number_lib.tan);

  /// Creates an `atan()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value atan(Object argument) =>
      _singleArgument("atan", argument, number_lib.atan, forbidUnits: true);

  /// Creates an `asin()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value asin(Object argument) =>
      _singleArgument("asin", argument, number_lib.asin, forbidUnits: true);

  /// Creates an `acos()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value acos(Object argument) =>
      _singleArgument("acos", argument, number_lib.acos, forbidUnits: true);

  /// Creates an `abs()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value abs(Object argument) {
    argument = _simplify(argument);
    if (argument is! SassNumber) return SassCalculation._("abs", [argument]);
    if (argument.hasUnit("%")) {
      warnForDeprecation(
        "Passing percentage units to the global abs() function is deprecated.\n"
        "In the future, this will emit a CSS abs() function to be resolved by the browser.\n"
        "To preserve current behavior: math.abs($argument)"
        "\n"
        "To emit a CSS abs() now: abs(#{$argument})\n"
        "More info: https://sass-lang.com/d/abs-percent",
        Deprecation.absPercent,
      );
    }
    return number_lib.abs(argument);
  }

  /// Creates an `exp()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value exp(Object argument) {
    argument = _simplify(argument);
    if (argument is! SassNumber) {
      return SassCalculation._("exp", [argument]);
    }
    argument.assertNoUnits();
    return number_lib.pow(SassNumber(math.e), argument);
  }

  /// Creates a `sign()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value sign(Object argument) {
    argument = _simplify(argument);
    return switch (argument) {
      SassNumber(value: double(isNaN: true) || 0) => argument,
      SassNumber arg when !arg.hasUnit('%') => SassNumber(
          arg.value.sign,
        ).coerceToMatch(argument),
      _ => SassCalculation._("sign", [argument]),
    };
  }

  /// Creates a `clamp()` calculation with the given [min], [value], and [max].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than three arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value clamp(Object min, [Object? value, Object? max]) {
    if (value == null && max != null) {
      throw ArgumentError("If value is null, max must also be null.");
    }

    min = _simplify(min);
    value = value.andThen(_simplify);
    max = max.andThen(_simplify);

    if (min is SassNumber &&
        value is SassNumber &&
        max is SassNumber &&
        min.hasCompatibleUnits(value) &&
        min.hasCompatibleUnits(max)) {
      if (value.lessThanOrEquals(min).isTruthy) return min;
      if (value.greaterThanOrEquals(max).isTruthy) return max;
      return value;
    }

    var args = List<Object>.unmodifiable([
      min,
      if (value != null) value,
      if (max != null) max,
    ]);
    _verifyCompatibleNumbers(args);
    _verifyLength(args, 3);
    return SassCalculation._("clamp", args);
  }

  /// Creates a `pow()` calculation with the given [base] and [exponent].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than two arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value pow(Object base, Object? exponent) {
    var args = [base, if (exponent != null) exponent];
    _verifyLength(args, 2);
    base = _simplify(base);
    exponent = exponent.andThen(_simplify);
    if (base is! SassNumber || exponent is! SassNumber) {
      return SassCalculation._("pow", args);
    }
    base.assertNoUnits();
    exponent.assertNoUnits();
    return number_lib.pow(base, exponent);
  }

  /// Creates a `log()` calculation with the given [number] and [base].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// If arguments contains exactly a single argument, the base is set to
  /// `math.e` by default.
  static Value log(Object number, Object? base) {
    number = _simplify(number);
    base = base.andThen(_simplify);
    var args = [number, if (base != null) base];
    if (number is! SassNumber || (base != null && base is! SassNumber)) {
      return SassCalculation._("log", args);
    }
    number.assertNoUnits();
    if (base is SassNumber) {
      base.assertNoUnits();
      return number_lib.log(number, base);
    }
    return number_lib.log(number, null);
  }

  /// Creates a `atan2()` calculation for [y] and [x].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than two arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value atan2(Object y, Object? x) {
    y = _simplify(y);
    x = x.andThen(_simplify);
    var args = [y, if (x != null) x];
    _verifyLength(args, 2);
    _verifyCompatibleNumbers(args);
    if (y is! SassNumber ||
        x is! SassNumber ||
        y.hasUnit('%') ||
        x.hasUnit('%') ||
        !y.hasCompatibleUnits(x)) {
      return SassCalculation._("atan2", args);
    }
    return number_lib.atan2(y, x);
  }

  /// Creates a `rem()` calculation with the given [dividend] and [modulus].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than two arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value rem(Object dividend, Object? modulus) {
    dividend = _simplify(dividend);
    modulus = modulus.andThen(_simplify);
    var args = [dividend, if (modulus != null) modulus];
    _verifyLength(args, 2);
    _verifyCompatibleNumbers(args);
    if (dividend is! SassNumber ||
        modulus is! SassNumber ||
        !dividend.hasCompatibleUnits(modulus)) {
      return SassCalculation._("rem", args);
    }
    var result = dividend.modulo(modulus);
    if (modulus.value.signIncludingZero != dividend.value.signIncludingZero) {
      if (modulus.value.isInfinite) return dividend;
      if (result.value == 0) {
        return result.unaryMinus();
      }
      return result.minus(modulus);
    }
    return result;
  }

  /// Creates a `mod()` calculation with the given [dividend] and [modulus].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than two arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value mod(Object dividend, Object? modulus) {
    dividend = _simplify(dividend);
    modulus = modulus.andThen(_simplify);
    var args = [dividend, if (modulus != null) modulus];
    _verifyLength(args, 2);
    _verifyCompatibleNumbers(args);
    if (dividend is! SassNumber ||
        modulus is! SassNumber ||
        !dividend.hasCompatibleUnits(modulus)) {
      return SassCalculation._("mod", args);
    }
    return dividend.modulo(modulus);
  }

  /// Creates a `round()` calculation with the given [strategyOrNumber],
  /// [numberOrStep], and [step]. Strategy must be either nearest, up, down or
  /// to-zero.
  ///
  /// Number and step must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than two arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value round(
    Object strategyOrNumber, [
    Object? numberOrStep,
    Object? step,
  ]) =>
      roundInternal(
        strategyOrNumber,
        numberOrStep,
        step,
        span: null,
        inLegacySassFunction: null,
        warn: null,
      );

  /// Like [round], but with the internal-only [inLegacySassFunction] and
  /// [warn] parameters.
  ///
  /// If [inLegacySassFunction] isn't null, this allows unitless numbers to be
  /// added and subtracted with numbers with units, for backwards-compatibility
  /// with the old global `min()` and `max()` functions. This emits a
  /// deprecation warning using the string as the function's name.
  ///
  /// If [simplify] is `false`, no simplification will be done.
  ///
  /// The [warn] callback is used to surface deprecation warnings.
  ///
  /// @nodoc
  @internal
  static Value roundInternal(
    Object strategyOrNumber,
    Object? numberOrStep,
    Object? step, {
    required FileSpan? span,
    required String? inLegacySassFunction,
    required void Function(String message, [Deprecation? deprecation])? warn,
  }) {
    switch ((
      _simplify(strategyOrNumber),
      numberOrStep.andThen(_simplify),
      step.andThen(_simplify),
    )) {
      case (SassNumber(hasUnits: false) && var number, null, null):
        return SassNumber(number.value.round());

      case (SassNumber number, null, null) when inLegacySassFunction != null:
        warn!(
          "In future versions of Sass, round() will be interpreted as a CSS "
          "round() calculation. This requires an explicit modulus when "
          "rounding numbers with units. If you want to use the Sass "
          "function, call math.round() instead.\n"
          "\n"
          "See https://sass-lang.com/d/import",
          Deprecation.globalBuiltin,
        );
        return _matchUnits(number.value.round().toDouble(), number);

      case (SassNumber number, SassNumber step, null)
          when !number.hasCompatibleUnits(step):
        _verifyCompatibleNumbers([number, step]);
        return SassCalculation._("round", [number, step]);

      case (SassNumber number, SassNumber step, null):
        _verifyCompatibleNumbers([number, step]);
        return _roundWithStep('nearest', number, step);

      case (
            SassString(text: 'nearest' || 'up' || 'down' || 'to-zero') &&
                var strategy,
            SassNumber number,
            SassNumber step,
          )
          when !number.hasCompatibleUnits(step):
        _verifyCompatibleNumbers([number, step]);
        return SassCalculation._("round", [strategy, number, step]);

      case (
          SassString(text: 'nearest' || 'up' || 'down' || 'to-zero') &&
              var strategy,
          SassNumber number,
          SassNumber step,
        ):
        _verifyCompatibleNumbers([number, step]);
        return _roundWithStep(strategy.text, number, step);

      case (
          SassString(text: 'nearest' || 'up' || 'down' || 'to-zero') &&
              var strategy,
          SassString rest,
          null,
        ):
        return SassCalculation._("round", [strategy, rest]);

      case (
          SassString(text: 'nearest' || 'up' || 'down' || 'to-zero'),
          _?,
          null,
        ):
        throw SassScriptException("If strategy is not null, step is required.");

      case (
          SassString(text: 'nearest' || 'up' || 'down' || 'to-zero'),
          null,
          null,
        ):
        throw SassScriptException(
          "Number to round and step arguments are required.",
        );

      case (var number, null, null):
        return SassCalculation._("round", [number]);

      case (var number, var step?, null):
        return SassCalculation._("round", [number, step]);

      case (
          (SassString(text: 'nearest' || 'up' || 'down' || 'to-zero') ||
                  SassString(isVar: true)) &&
              var strategy,
          var number?,
          var step?,
        ):
        return SassCalculation._("round", [strategy, number, step]);

      case (_, _?, _?):
        throw SassScriptException(
          "$strategyOrNumber must be either nearest, up, down or to-zero.",
        );

      case (_, null, _?):
      // TODO(pamelalozano): Get rid of this case once dart-lang/sdk#52908 is solved.
      // ignore: unreachable_switch_case
      case (_, _, _):
        throw SassScriptException("Invalid parameters.");
    }
  }

  /// Creates an `calc-size()` calculation with the given [basis] and [value].
  ///
  /// The [basis] and [value] must be either a [SassNumber], a
  /// [SassCalculation], an unquoted [SassString], or a [CalculationOperation].
  ///
  /// This automatically simplifies the calculation. It throws an exception if
  /// it can determine that the calculation will definitely produce invalid CSS.
  static SassCalculation calcSize(Object basis, Object? value) {
    var args = [basis, if (value != null) value];
    _verifyLength(args, 2);
    basis = _simplify(basis);
    value = value.andThen(_simplify);
    return SassCalculation._("calc-size", [basis, if (value != null) value]);
  }

  /// Creates and simplifies a [CalculationOperation] with the given [operator],
  /// [left], and [right].
  ///
  /// This automatically simplifies the operation, so it may return a
  /// [SassNumber] rather than a [CalculationOperation].
  ///
  /// Each of [left] and [right] must be either a [SassNumber], a
  /// [SassCalculation], an unquoted [SassString], or a [CalculationOperation].
  static Object operate(
    CalculationOperator operator,
    Object left,
    Object right,
  ) =>
      operateInternal(
        operator,
        left,
        right,
        inLegacySassFunction: null,
        simplify: true,
        warn: null,
      );

  /// Like [operate], but with the internal-only [inLegacySassFunction] and
  /// [warn] parameters.
  ///
  /// If [inLegacySassFunction] isn't null, this allows unitless numbers to be
  /// added and subtracted with numbers with units, for backwards-compatibility
  /// with the old global `min()` and `max()` functions. This emits a
  /// deprecation warning using the string as the function's name.
  ///
  /// If [simplify] is `false`, no simplification will be done.
  ///
  /// The [warn] callback is used to surface deprecation warnings.
  ///
  /// @nodoc
  @internal
  static Object operateInternal(
    CalculationOperator operator,
    Object left,
    Object right, {
    required String? inLegacySassFunction,
    required bool simplify,
    required void Function(String message, [Deprecation? deprecation])? warn,
  }) {
    if (!simplify) return CalculationOperation._(operator, left, right);
    left = _simplify(left);
    right = _simplify(right);

    if (operator case CalculationOperator.plus || CalculationOperator.minus) {
      if (left is SassNumber && right is SassNumber) {
        var compatible = left.hasCompatibleUnits(right);
        if (!compatible &&
            inLegacySassFunction != null &&
            left.isComparableTo(right)) {
          warn!(
            "In future versions of Sass, $inLegacySassFunction() will be "
            "interpreted as the CSS $inLegacySassFunction() calculation. "
            "This doesn't allow unitless numbers to be mixed with numbers "
            "with units. If you want to use the Sass function, call "
            "math.$inLegacySassFunction() instead.\n"
            "\n"
            "See https://sass-lang.com/d/import",
            Deprecation.globalBuiltin,
          );
          compatible = true;
        }
        if (compatible) {
          return operator == CalculationOperator.plus
              ? left.plus(right)
              : left.minus(right);
        }
      }

      _verifyCompatibleNumbers([left, right]);

      if (right is SassNumber && number_lib.fuzzyLessThan(right.value, 0)) {
        right = right.times(SassNumber(-1));
        operator = operator == CalculationOperator.plus
            ? CalculationOperator.minus
            : CalculationOperator.plus;
      }

      return CalculationOperation._(operator, left, right);
    } else if (left is SassNumber && right is SassNumber) {
      return operator == CalculationOperator.times
          ? left.times(right)
          : left.dividedBy(right);
    } else {
      return CalculationOperation._(operator, left, right);
    }
  }

  /// An internal constructor that doesn't perform any validation or
  /// simplification.
  SassCalculation._(this.name, this.arguments);

  // Returns [value] coerced to [number]'s units.
  static SassNumber _matchUnits(double value, SassNumber number) =>
      SassNumber.withUnits(
        value,
        numeratorUnits: number.numeratorUnits,
        denominatorUnits: number.denominatorUnits,
      );

  /// Returns a rounded [number] based on a selected rounding [strategy],
  /// to the nearest integer multiple of [step].
  static SassNumber _roundWithStep(
    String strategy,
    SassNumber number,
    SassNumber step,
  ) {
    if (!{'nearest', 'up', 'down', 'to-zero'}.contains(strategy)) {
      throw ArgumentError(
        "$strategy must be either nearest, up, down or to-zero.",
      );
    }

    if (number.value.isInfinite && step.value.isInfinite ||
        step.value == 0 ||
        number.value.isNaN ||
        step.value.isNaN) {
      return _matchUnits(double.nan, number);
    }
    if (number.value.isInfinite) return number;

    if (step.value.isInfinite) {
      return switch ((strategy, number.value)) {
        (_, 0) => number,
        ('nearest' || 'to-zero', > 0) => _matchUnits(0.0, number),
        ('nearest' || 'to-zero', _) => _matchUnits(-0.0, number),
        ('up', > 0) => _matchUnits(double.infinity, number),
        ('up', _) => _matchUnits(-0.0, number),
        ('down', < 0) => _matchUnits(-double.infinity, number),
        ('down', _) => _matchUnits(0, number),
        (_, _) => throw UnsupportedError("Invalid argument: $strategy."),
      };
    }

    var stepWithNumberUnit = step.convertValueToMatch(number);
    return switch (strategy) {
      'nearest' => _matchUnits(
          (number.value / stepWithNumberUnit).round() * stepWithNumberUnit,
          number,
        ),
      'up' => _matchUnits(
          (step.value < 0
                  ? (number.value / stepWithNumberUnit).floor()
                  : (number.value / stepWithNumberUnit).ceil()) *
              stepWithNumberUnit,
          number,
        ),
      'down' => _matchUnits(
          (step.value < 0
                  ? (number.value / stepWithNumberUnit).ceil()
                  : (number.value / stepWithNumberUnit).floor()) *
              stepWithNumberUnit,
          number,
        ),
      'to-zero' => number.value < 0
          ? _matchUnits(
              (number.value / stepWithNumberUnit).ceil() * stepWithNumberUnit,
              number,
            )
          : _matchUnits(
              (number.value / stepWithNumberUnit).floor() * stepWithNumberUnit,
              number,
            ),
      _ => _matchUnits(double.nan, number),
    };
  }

  /// Returns an unmodifiable list of [args], with each argument simplified.
  static List<Object> _simplifyArguments(Iterable<Object> args) =>
      List.unmodifiable(args.map(_simplify));

  /// Simplifies a calculation argument.
  static Object _simplify(Object arg) => switch (arg) {
        SassNumber() || CalculationOperation() => arg,
        CalculationInterpolation() =>
          SassString('(${arg.value})', quotes: false),
        SassString(hasQuotes: false) => arg,
        SassString() => throw SassScriptException(
            "Quoted string $arg can't be used in a calculation.",
          ),
        SassCalculation(
          name: 'calc',
          arguments: [SassString(hasQuotes: false, :var text)],
        )
            when _needsParentheses(text) =>
          SassString('($text)', quotes: false),
        SassCalculation(name: 'calc', arguments: [var value]) => value,
        SassCalculation() => arg,
        Value() => throw SassScriptException(
            "Value $arg can't be used in a calculation."),
        _ => throw ArgumentError("Unexpected calculation argument $arg."),
      };

  /// Returns whether [text] needs parentheses if it's the contents of a
  /// `calc()` being embedded in another calculation.
  static bool _needsParentheses(String text) {
    var first = text.codeUnitAt(0);
    if (_charNeedsParentheses(first)) return true;
    var couldBeVar = text.length >= 4 && characterEqualsIgnoreCase(first, $v);

    if (text.length < 2) return false;
    var second = text.codeUnitAt(1);
    if (_charNeedsParentheses(second)) return true;
    couldBeVar = couldBeVar && characterEqualsIgnoreCase(second, $a);

    if (text.length < 3) return false;
    var third = text.codeUnitAt(2);
    if (_charNeedsParentheses(third)) return true;
    couldBeVar = couldBeVar && characterEqualsIgnoreCase(third, $r);

    if (text.length < 4) return false;
    var fourth = text.codeUnitAt(3);
    if (couldBeVar && fourth == $lparen) return true;
    if (_charNeedsParentheses(fourth)) return true;

    for (var i = 4; i < text.length; i++) {
      if (_charNeedsParentheses(text.codeUnitAt(i))) return true;
    }
    return false;
  }

  /// Returns whether [character] intrinsically needs parentheses if it appears
  /// in the unquoted string argument of a `calc()` being embedded in another
  /// calculation.
  static bool _charNeedsParentheses(int character) =>
      character.isWhitespace || character == $slash || character == $asterisk;

  /// Verifies that all the numbers in [args] aren't known to be incompatible
  /// with one another, and that they don't have units that are too complex for
  /// calculations.
  static void _verifyCompatibleNumbers(List<Object> args) {
    // Note: this logic is largely duplicated in
    // _EvaluateVisitor._verifyCompatibleNumbers and most changes here should
    // also be reflected there.
    for (var arg in args) {
      if (arg case SassNumber(hasComplexUnits: true)) {
        throw SassScriptException(
          "Number $arg isn't compatible with CSS calculations.",
        );
      }
    }

    for (var i = 0; i < args.length - 1; i++) {
      var number1 = args[i];
      if (number1 is! SassNumber) continue;

      for (var j = i + 1; j < args.length; j++) {
        var number2 = args[j];
        if (number2 is! SassNumber) continue;
        if (number1.hasPossiblyCompatibleUnits(number2)) continue;
        throw SassScriptException("$number1 and $number2 are incompatible.");
      }
    }
  }

  /// Throws a [SassScriptException] if [args] isn't [expectedLength] *and*
  /// doesn't contain a [SassString].
  static void _verifyLength(List<Object> args, int expectedLength) {
    if (args.length == expectedLength) return;
    if (args.any((arg) => arg is SassString)) {
      return;
    }
    throw SassScriptException(
      "$expectedLength arguments required, but only ${args.length} "
      "${pluralize('was', args.length, plural: 'were')} passed.",
    );
  }

  /// Returns a [Callable] named [name] that calls a single argument
  /// math function.
  ///
  /// If [forbidUnits] is `true` it will throw an error if [argument] has units.
  static Value _singleArgument(
    String name,
    Object argument,
    SassNumber mathFunc(SassNumber value), {
    bool forbidUnits = false,
  }) {
    argument = _simplify(argument);
    if (argument is! SassNumber) {
      return SassCalculation._(name, [argument]);
    }
    if (forbidUnits) argument.assertNoUnits();
    return mathFunc(argument);
  }

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitCalculation(this);

  SassCalculation assertCalculation([String? name]) => this;

  /// @nodoc
  @internal
  Value plus(Value other) {
    if (other is SassString) return super.plus(other);
    throw SassScriptException('Undefined operation "$this + $other".');
  }

  /// @nodoc
  @internal
  Value minus(Value other) =>
      throw SassScriptException('Undefined operation "$this - $other".');

  /// @nodoc
  @internal
  Value unaryPlus() =>
      throw SassScriptException('Undefined operation "+$this".');

  /// @nodoc
  @internal
  Value unaryMinus() =>
      throw SassScriptException('Undefined operation "-$this".');

  bool operator ==(Object other) =>
      other is SassCalculation &&
      name == other.name &&
      listEquals(arguments, other.arguments);

  int get hashCode => name.hashCode ^ listHash(arguments);
}

/// A binary operation that can appear in a [SassCalculation].
///
/// {@category Value}
final class CalculationOperation {
  /// We use a getters to allow overriding the logic in the JS API
  /// implementation.

  /// The operator.
  CalculationOperator get operator => _operator;
  final CalculationOperator _operator;

  /// The left-hand operand.
  ///
  /// This is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], or a [CalculationOperation].
  Object get left => _left;
  final Object _left;

  /// The right-hand operand.
  ///
  /// This is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], or a [CalculationOperation].
  Object get right => _right;
  final Object _right;

  CalculationOperation._(this._operator, this._left, this._right);

  bool operator ==(Object other) =>
      other is CalculationOperation &&
      operator == other.operator &&
      left == other.left &&
      right == other.right;

  int get hashCode => operator.hashCode ^ left.hashCode ^ right.hashCode;

  String toString() {
    var parenthesized = serializeValue(
      SassCalculation._("", [this]),
      inspect: true,
    );
    return parenthesized.substring(1, parenthesized.length - 1);
  }
}

/// An enumeration of possible operators for [CalculationOperation].
///
/// {@category Value}
enum CalculationOperator {
  /// The addition operator.
  plus('plus', '+', 1),

  /// The subtraction operator.
  minus('minus', '-', 1),

  /// The multiplication operator.
  times('times', '*', 2),

  /// The division operator.
  dividedBy('divided by', '/', 2);

  /// The English name of `this`.
  final String name;

  /// The CSS syntax for `this`.
  final String operator;

  /// The precedence of `this`.
  ///
  /// An operator with higher precedence binds tighter.
  ///
  /// @nodoc
  @internal
  final int precedence;

  const CalculationOperator(this.name, this.operator, this.precedence);

  String toString() => name;
}

/// A deprecated representation of a string injected into a [SassCalculation]
/// using interpolation.
///
/// This only exists for backwards-compatibility with an older version of Dart
/// Sass. It's now equivalent to creating a `SassString` whose value is wrapped
/// in parentheses.
///
/// {@category Value}
@Deprecated("Use SassString instead.")
@sealed
class CalculationInterpolation {
  /// We use a getters to allow overriding the logic in the JS API
  /// implementation.

  String get value => _value;
  final String _value;

  CalculationInterpolation(this._value);

  bool operator ==(Object other) =>
      other is CalculationInterpolation && value == other.value;

  int get hashCode => value.hashCode;

  String toString() => value;
}
