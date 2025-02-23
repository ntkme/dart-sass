// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sass from 'sass';
import {Expression, ExpressionProps} from '.';
import {BinaryOperationExpression} from './binary-operation';
import {BooleanExpression} from './boolean';
import {ColorExpression} from './color';
import {FunctionExpression} from './function';
import {ListExpression} from './list';
import {MapExpression} from './map';
import {NumberExpression} from './number';
import {StringExpression} from './string';

/** Constructs an expression from {@link ExpressionProps}. */
export function fromProps(props: ExpressionProps): Expression {
  if ('text' in props) return new StringExpression(props);
  if ('left' in props) return new BinaryOperationExpression(props);
  if ('separator' in props) return new ListExpression(props);
  if ('nodes' in props) return new MapExpression(props);
  if ('name' in props) return new FunctionExpression(props);
  if ('value' in props) {
    if (typeof props.value === 'boolean') return new BooleanExpression(props);
    if (typeof props.value === 'number') return new NumberExpression(props);
    if (props.value instanceof sass.SassColor) {
      return new ColorExpression(props);
    }
  }

  throw new Error(`Unknown node type, keys: ${Object.keys(props)}`);
}
