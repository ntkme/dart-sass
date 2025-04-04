// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws as PostcssAtRuleRaws} from 'postcss/lib/at-rule';

import {Interpolation, InterpolationProps} from '../interpolation';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {
  AtRule,
  ChildNode,
  ContainerProps,
  NewNode,
  Statement,
  StatementWithChildren,
  appendInternalChildren,
  normalize,
} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link GenericAtRule}.
 *
 * Sass doesn't support PostCSS's `params` raws, since
 * {@link GenericAtRule.paramInterpolation} has its own raws.
 *
 * @category Statement
 */
export interface GenericAtRuleRaws extends Omit<PostcssAtRuleRaws, 'params'> {
  /**
   * Whether to collapse the nesting for an `@at-root` with no params that
   * contains only a single style rule.
   *
   * This is ignored for rules that don't meet all of those criteria.
   */
  atRootShorthand?: boolean;
}

/**
 * The initializer properties for {@link GenericAtRule}.
 *
 * @category Statement
 */
export type GenericAtRuleProps = ContainerProps & {
  raws?: GenericAtRuleRaws;
} & (
    | {nameInterpolation: Interpolation | InterpolationProps; name?: never}
    | {name: string; nameInterpolation?: never}
  ) &
  (
    | {paramsInterpolation?: Interpolation | InterpolationProps; params?: never}
    | {params?: string | number; paramsInterpolation?: never}
  );

/**
 * An `@`-rule that isn't parsed as a more specific type. Extends
 * [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class GenericAtRule
  extends _AtRule<Partial<GenericAtRuleProps>>
  implements Statement
{
  readonly sassType = 'atrule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: GenericAtRuleRaws;
  declare nodes: ChildNode[] | undefined;

  get name(): string {
    return this.nameInterpolation.toString();
  }
  set name(value: string) {
    this.nameInterpolation = value;
  }

  /**
   * The interpolation that represents this at-rule's name.
   */
  get nameInterpolation(): Interpolation {
    return this._nameInterpolation!;
  }
  set nameInterpolation(value: Interpolation | InterpolationProps) {
    if (this._nameInterpolation) this._nameInterpolation.parent = undefined;
    const nameInterpolation =
      value instanceof Interpolation ? value : new Interpolation(value);
    nameInterpolation.parent = this;
    this._nameInterpolation = nameInterpolation;
  }
  private declare _nameInterpolation?: Interpolation;

  get params(): string {
    if (this.name !== 'media' || !this.paramsInterpolation) {
      return this.paramsInterpolation?.toString() ?? '';
    }

    // @media has special parsing in Sass, and allows raw expressions within
    // parens.
    let result = '';
    const rawText = this.paramsInterpolation.raws.text;
    const rawExpressions = this.paramsInterpolation.raws.expressions;
    for (let i = 0; i < this.paramsInterpolation.nodes.length; i++) {
      const element = this.paramsInterpolation.nodes[i];
      if (typeof element === 'string') {
        const raw = rawText?.[i];
        result += raw?.value === element ? raw.raw : element;
      } else {
        if (result.match(/(\([ \t\n\f\r]*|(:|[<>]?=)[ \t\n\f\r]*)$/)) {
          result += element;
        } else {
          const raw = rawExpressions?.[i];
          result +=
            '#{' + (raw?.before ?? '') + element + (raw?.after ?? '') + '}';
        }
      }
    }
    return result;
  }
  set params(value: string | number | undefined) {
    this.paramsInterpolation = value === '' ? undefined : value?.toString();
  }

  /**
   * The interpolation that represents this at-rule's parameters, or undefined
   * if it has no parameters.
   */
  get paramsInterpolation(): Interpolation | undefined {
    return this._paramsInterpolation;
  }
  set paramsInterpolation(
    value: Interpolation | InterpolationProps | undefined,
  ) {
    if (this._paramsInterpolation) this._paramsInterpolation.parent = undefined;
    if (value === undefined) {
      this._paramsInterpolation = undefined;
    } else {
      const paramsInterpolation =
        value instanceof Interpolation ? value : new Interpolation(value);
      paramsInterpolation.parent = this;
      this._paramsInterpolation = paramsInterpolation;
    }
  }
  private declare _paramsInterpolation: Interpolation | undefined;

  constructor(defaults: GenericAtRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.AtRule);
  constructor(defaults?: GenericAtRuleProps, inner?: sassInternal.AtRule) {
    super(defaults as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.nameInterpolation = new Interpolation(undefined, inner.name);
      if (inner.value) {
        this.paramsInterpolation = new Interpolation(undefined, inner.value);
      }
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<GenericAtRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      [
        'nodes',
        'raws',
        'nameInterpolation',
        {name: 'paramsInterpolation', explicitUndefined: true},
      ],
      ['name', {name: 'params', explicitUndefined: true}],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'nameInterpolation', 'params', 'paramsInterpolation', 'nodes'],
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
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    const result = [this.nameInterpolation];
    if (this.paramsInterpolation) result.push(this.paramsInterpolation);
    return result;
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this as StatementWithChildren, node, sample);
  }
}

interceptIsClean(GenericAtRule);
