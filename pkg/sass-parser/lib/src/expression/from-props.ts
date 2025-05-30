// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sass from 'sass';
import {AnyExpression, ExpressionProps} from '.';
import {BinaryOperationExpression} from './binary-operation';
import {BooleanExpression} from './boolean';
import {ColorExpression} from './color';
import {FunctionExpression, FunctionExpressionProps} from './function';
import {InterpolatedFunctionExpression} from './interpolated-function';
import {ListExpression} from './list';
import {MapExpression} from './map';
import {NullExpression} from './null';
import {NumberExpression} from './number';
import {ParenthesizedExpression} from './parenthesized';
import {StringExpression} from './string';
import {UnaryOperationExpression} from './unary-operation';
import {VariableExpression} from './variable';

/** Constructs an expression from {@link ExpressionProps}. */
export function fromProps(props: ExpressionProps): AnyExpression {
  if ('text' in props) return new StringExpression(props);
  if ('left' in props) return new BinaryOperationExpression(props);
  if ('operand' in props) return new UnaryOperationExpression(props);
  if ('separator' in props) return new ListExpression(props);
  if ('nodes' in props) return new MapExpression(props);
  if ('inParens' in props) return new ParenthesizedExpression(props);
  if ('variableName' in props) return new VariableExpression(props);
  if ('name' in props) {
    if (typeof props.name === 'string') {
      return new FunctionExpression(props as FunctionExpressionProps);
    } else {
      return new InterpolatedFunctionExpression(props);
    }
  }
  if ('value' in props) {
    if (props.value === null) return new NullExpression();
    if (typeof props.value === 'boolean') return new BooleanExpression(props);
    if (typeof props.value === 'number') return new NumberExpression(props);
    if (props.value instanceof sass.SassColor) {
      return new ColorExpression(props);
    }
  }

  throw new Error(`Unknown node type, keys: ${Object.keys(props)}`);
}
