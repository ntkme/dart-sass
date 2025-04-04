// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws as PostcssAtRuleRaws} from 'postcss/lib/at-rule';

import {convertExpression} from '../expression/convert';
import {AnyExpression, ExpressionProps} from '../expression';
import {fromProps} from '../expression/from-props';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Statement, StatementWithChildren} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link DebugRule}.
 *
 * @category Statement
 */
export type DebugRuleRaws = Pick<
  PostcssAtRuleRaws,
  'afterName' | 'before' | 'between'
>;

/**
 * The initializer properties for {@link DebugRule}.
 *
 * @category Statement
 */
export type DebugRuleProps = postcss.NodeProps & {
  raws?: DebugRuleRaws;
  debugExpression: AnyExpression | ExpressionProps;
};

/**
 * A `@debug` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class DebugRule
  extends _AtRule<Partial<DebugRuleProps>>
  implements Statement
{
  readonly sassType = 'debug-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: DebugRuleRaws;
  declare readonly nodes: undefined;

  get name(): string {
    return 'debug';
  }
  set name(value: string) {
    throw new Error("DebugRule.name can't be overwritten.");
  }

  get params(): string {
    return this.debugExpression.toString();
  }
  set params(value: string | number | undefined) {
    this.debugExpression = {text: value?.toString() ?? ''};
  }

  /** The expression whose value is emitted when the debug rule is executed. */
  get debugExpression(): AnyExpression {
    return this._debugExpression!;
  }
  set debugExpression(debugExpression: AnyExpression | ExpressionProps) {
    if (this._debugExpression) this._debugExpression.parent = undefined;
    const built =
      'sassType' in debugExpression
        ? debugExpression
        : fromProps(debugExpression);
    built.parent = this;
    this._debugExpression = built;
  }
  private declare _debugExpression?: AnyExpression;

  constructor(defaults: DebugRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.DebugRule);
  constructor(defaults?: DebugRuleProps, inner?: sassInternal.DebugRule) {
    super(defaults as unknown as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.debugExpression = convertExpression(inner.expression);
    }
  }

  clone(overrides?: Partial<DebugRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['raws', 'debugExpression'],
      [{name: 'params', explicitUndefined: true}],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'debugExpression', 'params', 'nodes'],
      inputs,
    );
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyExpression> {
    return [this.debugExpression];
  }
}

interceptIsClean(DebugRule);
