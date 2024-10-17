// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {DeclarationRaws} from 'postcss/lib/declaration';

import {Configuration, ConfigurationProps} from '../configuration';
import {Expression} from '../expression';
import {StringExpression} from '../expression/string';
import {LazySource} from '../lazy-source';
import {RawWithValue} from '../raw-with-value';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {ContainerProps, Statement, StatementWithChildren} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link VariableDeclaration}.
 *
 * @category Statement
 */
export interface VariableDeclarationRaws extends Omit<DeclarationRaws, 'value', 'important'> {
  /**
   * The variable's namespace.
   *
   * This may be different than {@link VariableDeclarationRaws.name} if the name
   * contains escape codes or underscores.
   */
  namespace?: RawWithValue<string>;

  /**
   * The variable's name, not including the `$`.
   *
   * This may be different than {@link VariableDeclarationRaws.variable} if the
   * name contains escape codes or underscores.
   */
  variable?: RawWithValue<string>;
}

/**
 * The initializer properties for {@link VariableDeclaration}.
 *
 * @category Statement
 */
export interface VariableDeclarationProps {
  raws?: VariableDeclarationRaws;
  namespace?: string;
  variable: string;
  expression: Expression|ExpressionProps;
  guarded?: boolean;
  global?: boolean;
}

/**
 * A Sass variable declaration. Extends [`postcss.Declaration`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#declaration
 *
 * @category Statement
 */
export class VariableDeclaration
  extends _Declaration<Partial<VariableDeclarationProps>>
  implements Statement
{
  readonly sassType = 'variable-declaration' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: VariableDeclarationRaws;

  /**
   * The variable name, not including `$`.
   *
   * This is the parsed value, with escapes resolved to the characters they
   * represent.
   */
  declare namespace: string|undefined;

  /**
   * The variable name, not including `$`.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare variable: string;
}
