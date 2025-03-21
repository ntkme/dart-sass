// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Container} from '../container';
import {Interpolation} from '../interpolation';
import {LazySource} from '../lazy-source';
import {Node, NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import {CssComment, CssCommentProps} from './css-comment';
import {SassComment, SassCommentChildProps} from './sass-comment';
import {GenericAtRule, GenericAtRuleProps} from './generic-at-rule';
import {ContentRule, ContentRuleProps} from './content-rule';
import {DebugRule, DebugRuleProps} from './debug-rule';
import {Declaration, DeclarationProps} from './declaration';
import {EachRule, EachRuleProps} from './each-rule';
import {ElseRule, ElseRuleProps} from './else-rule';
import {ErrorRule, ErrorRuleProps} from './error-rule';
import {ForRule, ForRuleProps} from './for-rule';
import {ForwardRule, ForwardRuleProps} from './forward-rule';
import {FunctionRule, FunctionRuleProps} from './function-rule';
import {IfRule, IfRuleProps} from './if-rule';
import {ImportRule, ImportRuleProps} from './import-rule';
import {IncludeRule, IncludeRuleProps} from './include-rule';
import {MixinRule, MixinRuleProps} from './mixin-rule';
import {ReturnRule, ReturnRuleProps} from './return-rule';
import {Root} from './root';
import {Rule, RuleProps} from './rule';
import {UseRule, UseRuleProps} from './use-rule';
import {
  VariableDeclaration,
  VariableDeclarationProps,
} from './variable-declaration';
import {WarnRule, WarnRuleProps} from './warn-rule';
import {WhileRule, WhileRuleProps} from './while-rule';

/**
 * The union type of all Sass statements.
 *
 * @category Statement
 */
export type AnyStatement = Comment | Root | Rule | AtRule | AnyDeclaration;

/**
 * Sass statement types.
 *
 * This is a superset of the node types PostCSS exposes, and is provided
 * alongside `Node.type` to disambiguate between the wide range of statements
 * that Sass parses as distinct types.
 *
 * @category Statement
 */
export type StatementType =
  | 'root'
  | 'rule'
  | 'atrule'
  | 'comment'
  | 'content-rule'
  | 'decl'
  | 'debug-rule'
  | 'each-rule'
  | 'else-rule'
  | 'error-rule'
  | 'for-rule'
  | 'forward-rule'
  | 'function-rule'
  | 'if-rule'
  | 'import-rule'
  | 'include-rule'
  | 'mixin-rule'
  | 'return-rule'
  | 'sass-comment'
  | 'use-rule'
  | 'variable-declaration'
  | 'warn-rule'
  | 'while-rule';

/**
 * All Sass statements that are also at-rules.
 *
 * @category Statement
 */
export type AtRule =
  | ContentRule
  | DebugRule
  | EachRule
  | ElseRule
  | ErrorRule
  | ForRule
  | ForwardRule
  | FunctionRule
  | GenericAtRule
  | IfRule
  | ImportRule
  | IncludeRule
  | MixinRule
  | ReturnRule
  | UseRule
  | WarnRule
  | WhileRule;

/**
 * All Sass statements that are declarations.
 *
 * @category Statement
 */
export type AnyDeclaration = VariableDeclaration | Declaration;

/**
 * All Sass statements that are comments.
 *
 * @category Statement
 */
export type Comment = CssComment | SassComment;

/**
 * All Sass statements that are valid children of other statements.
 *
 * The Sass equivalent of PostCSS's `ChildNode`.
 *
 * @category Statement
 */
export type ChildNode = Rule | AtRule | Comment | AnyDeclaration;

/**
 * The properties that can be used to construct {@link ChildNode}s.
 *
 * The Sass equivalent of PostCSS's `ChildProps`.
 *
 * @category Statement
 */
export type ChildProps =
  | postcss.ChildProps
  // In a ChildProps context, `ContentProps` requires an explicit
  // `contentArguments: undefined` so that an empty object isn't a valid
  // `ChildProps`.
  | (ContentRuleProps & {
      contentArguments: ContentRuleProps['contentArguments'];
    })
  | CssCommentProps
  | DebugRuleProps
  | DeclarationProps
  | EachRuleProps
  // In a ChildProps context, `ElseRuleProps` requires an explicit
  // `elseCondition: undefined` so that an empty object isn't a valid
  // `ChildProps`.
  | (ElseRuleProps & {elseCondition: ElseRuleProps['elseCondition']})
  | ErrorRuleProps
  | ForRuleProps
  | ForwardRuleProps
  | FunctionRuleProps
  | GenericAtRuleProps
  | IfRuleProps
  | ImportRuleProps
  | IncludeRuleProps
  | MixinRuleProps
  | ReturnRuleProps
  | RuleProps
  | SassCommentChildProps
  | UseRuleProps
  | VariableDeclarationProps
  | WarnRuleProps
  | WhileRuleProps;

/**
 * The Sass eqivalent of PostCSS's `ContainerProps`.
 *
 * @category Statement
 */
export interface ContainerProps extends NodeProps {
  nodes?: ReadonlyArray<postcss.Node | ChildProps>;
}

/**
 * A {@link Statement} that has actual child nodes.
 *
 * @category Statement
 */
export type StatementWithChildren = postcss.Container<postcss.ChildNode> &
  Container<ChildNode, NewNode> &
  AnyStatement;

/**
 * A statement in a Sass stylesheet.
 *
 * In addition to implementing the standard PostCSS behavior, this provides
 * extra information to help disambiguate different types that Sass parses
 * differently.
 *
 * @category Statement
 */
export interface Statement extends postcss.Node, Node {
  /** The type of this statement. */
  readonly sassType: StatementType;

  parent: StatementWithChildren | undefined;
}

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor = sassInternal.createStatementVisitor<Statement | Statement[]>({
  visitAtRootRule: inner => {
    const rule = new GenericAtRule({
      name: 'at-root',
      paramsInterpolation: inner.query
        ? new Interpolation(undefined, inner.query)
        : undefined,
      source: new LazySource(inner),
    });
    appendInternalChildren(rule, inner.children);
    return rule;
  },
  visitAtRule: inner => new GenericAtRule(undefined, inner),
  visitContentRule: inner => new ContentRule(undefined, inner),
  visitDebugRule: inner => new DebugRule(undefined, inner),
  visitDeclaration: inner => new Declaration(undefined, inner),
  visitErrorRule: inner => new ErrorRule(undefined, inner),
  visitEachRule: inner => new EachRule(undefined, inner),
  visitForRule: inner => new ForRule(undefined, inner),
  visitForwardRule: inner => new ForwardRule(undefined, inner),
  visitFunctionRule: inner => new FunctionRule(undefined, inner),
  visitIfRule: inner => {
    const rules: Statement[] = [new IfRule(undefined, inner)];

    // Skip `inner.clauses[0]` because it's already used by `new IfRule()`.
    for (let i = 1; i < inner.clauses.length; i++) {
      rules.push(new ElseRule(undefined, inner, inner.clauses[i]));
    }
    if (inner.lastClause) {
      rules.push(new ElseRule(undefined, inner, inner.lastClause));
    }
    return rules;
  },
  visitImportRule: inner => new ImportRule(undefined, inner),
  visitIncludeRule: inner => new IncludeRule(undefined, inner),
  visitExtendRule: inner => {
    const paramsInterpolation = new Interpolation(undefined, inner.selector);
    if (inner.isOptional) paramsInterpolation.append('!optional');
    return new GenericAtRule({
      name: 'extend',
      paramsInterpolation,
      source: new LazySource(inner),
    });
  },
  visitLoudComment: inner => new CssComment(undefined, inner),
  visitMediaRule: inner => {
    const rule = new GenericAtRule({
      name: 'media',
      paramsInterpolation: new Interpolation(undefined, inner.query),
      source: new LazySource(inner),
    });
    appendInternalChildren(rule, inner.children);
    return rule;
  },
  visitMixinRule: inner => new MixinRule(undefined, inner),
  visitReturnRule: inner => new ReturnRule(undefined, inner),
  visitSilentComment: inner => new SassComment(undefined, inner),
  visitStyleRule: inner => new Rule(undefined, inner),
  visitSupportsRule: inner => {
    const rule = new GenericAtRule({
      name: 'supports',
      paramsInterpolation: new Interpolation(
        undefined,
        inner.condition.toInterpolation(),
      ),
      source: new LazySource(inner),
    });
    appendInternalChildren(rule, inner.children);
    return rule;
  },
  visitUseRule: inner => new UseRule(undefined, inner),
  visitVariableDeclaration: inner => new VariableDeclaration(undefined, inner),
  visitWarnRule: inner => new WarnRule(undefined, inner),
  visitWhileRule: inner => new WhileRule(undefined, inner),
});

/** Appends parsed versions of `internal`'s children to `container`. */
export function appendInternalChildren(
  container: postcss.Container,
  children: sassInternal.Statement[] | null,
): void {
  // Make sure `container` knows it has a block.
  if (children?.length === 0) container.append(undefined);
  if (!children) return;
  for (const child of children) {
    container.append(child.accept(visitor));
  }
}

/**
 * The type of nodes that can be passed as new child nodes to PostCSS methods.
 */
export type NewNode =
  | ChildProps
  | ReadonlyArray<ChildProps>
  | postcss.Node
  | ReadonlyArray<postcss.Node>
  | string
  | ReadonlyArray<string>
  | undefined;

/** PostCSS's built-in normalize function. */
const postcssNormalize = postcss.Container.prototype['normalize'] as (
  nodes: postcss.NewChild,
  sample: postcss.Node | undefined,
  type?: 'prepend' | false,
) => postcss.ChildNode[];

/**
 * A wrapper around {@link postcssNormalize} that converts the results to the
 * corresponding Sass type(s) after normalizing.
 */
function postcssNormalizeAndConvertToSass(
  self: StatementWithChildren,
  node: string | postcss.ChildProps | postcss.Node,
  sample: postcss.Node | undefined,
): ChildNode[] {
  return postcssNormalize.call(self, node, sample).map(postcssNode => {
    // postcssNormalize sets the parent to the Sass node, but we don't want to
    // mix Sass AST nodes with plain PostCSS AST nodes so we unset it in favor
    // of creating a totally new node.
    postcssNode.parent = undefined;

    switch (postcssNode.type) {
      case 'atrule':
        return new GenericAtRule({
          name: postcssNode.name,
          params: postcssNode.params,
          raws: postcssNode.raws,
          source: postcssNode.source,
        });
      case 'rule':
        return new Rule({
          selector: postcssNode.selector,
          raws: postcssNode.raws,
          source: postcssNode.source,
        });
      default:
        throw new Error(`Unsupported PostCSS node type ${postcssNode.type}`);
    }
  });
}

/**
 * An override of {@link postcssNormalize} that supports Sass nodes as arguments
 * and converts PostCSS-style arguments to Sass.
 */
export function normalize(
  self: StatementWithChildren,
  node: NewNode,
  sample?: postcss.Node,
): ChildNode[] {
  if (node === undefined) return [];
  const nodes = Array.isArray(node) ? node : [node];

  const result: ChildNode[] = [];
  for (const node of nodes) {
    if (typeof node === 'string') {
      // We could in principle parse these as Sass.
      result.push(...postcssNormalizeAndConvertToSass(self, node, sample));
    } else if ('sassType' in node) {
      if (node.sassType === 'root') {
        result.push(...(node as Root).nodes);
      } else {
        result.push(node as ChildNode);
      }
    } else if ('type' in node) {
      result.push(...postcssNormalizeAndConvertToSass(self, node, sample));
    } else if ('prop' in node || 'propInterpolation' in node) {
      result.push(new Declaration(node));
    } else if (
      'selectorInterpolation' in node ||
      'selector' in node ||
      'selectors' in node
    ) {
      result.push(new Rule(node));
    } else if ('name' in node || 'nameInterpolation' in node) {
      result.push(new GenericAtRule(node as GenericAtRuleProps));
    } else if ('contentArguments' in node) {
      result.push(new ContentRule(node));
    } else if ('debugExpression' in node) {
      result.push(new DebugRule(node));
    } else if ('eachExpression' in node) {
      result.push(new EachRule(node));
    } else if ('elseCondition' in node) {
      result.push(new ElseRule(node));
    } else if ('errorExpression' in node) {
      result.push(new ErrorRule(node));
    } else if ('ifCondition' in node) {
      result.push(new IfRule(node));
    } else if ('imports' in node) {
      result.push(new ImportRule(node));
    } else if ('includeName' in node) {
      result.push(new IncludeRule(node));
    } else if ('fromExpression' in node) {
      result.push(new ForRule(node));
    } else if ('forwardUrl' in node) {
      result.push(new ForwardRule(node));
    } else if ('functionName' in node) {
      result.push(new FunctionRule(node));
    } else if ('mixinName' in node) {
      result.push(new MixinRule(node));
    } else if ('returnExpression' in node) {
      result.push(new ReturnRule(node));
    } else if ('silentText' in node) {
      result.push(new SassComment(node));
    } else if ('text' in node || 'textInterpolation' in node) {
      result.push(new CssComment(node as CssCommentProps));
    } else if ('useUrl' in node) {
      result.push(new UseRule(node));
    } else if ('variableName' in node) {
      result.push(new VariableDeclaration(node));
    } else if ('warnExpression' in node) {
      result.push(new WarnRule(node));
    } else if ('whileCondition' in node) {
      result.push(new WhileRule(node));
    } else {
      result.push(...postcssNormalizeAndConvertToSass(self, node, sample));
    }
  }

  for (const node of result) {
    if (node.parent) node.parent.removeChild(node);
    if (
      node.raws.before === 'undefined' &&
      sample?.raws?.before !== undefined
    ) {
      node.raws.before = sample.raws.before.replace(/\S/g, '');
    }
    node.parent = self;
  }

  return result;
}
