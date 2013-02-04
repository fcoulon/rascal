@license{
  Copyright (c) 2009-2011 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Jurgen J. Vinju - Jurgen.Vinju@cwi.nl - CWI}
@contributor{Arnold Lankamp - Arnold.Lankamp@cwi.nl}
@doc{
  This module provides functionality for merging the Rascal grammar and arbitrary user-defined grammars
}
module lang::rascal::newgrammar::ConcreteSyntax

import ValueIO;
import List;
import IO;
import ParseTree;
import Grammar;
import lang::rascal::newsyntax::Rascal;
import lang::rascal::grammar::definition::Productions;
import lang::rascal::grammar::definition::Literals;
import lang::rascal::grammar::definition::Regular;
import lang::rascal::grammar::definition::Symbols;
import lang::rascal::format::Escape;

public Grammar addHoles(Grammar object) = compose(object, grammar({}, holes(object)));

@doc{
  For every non-terminal in the grammar we create a rule that can recognize its hole syntax. Each hole
  is specific for a non-terminal (using its name as a literal), such that no ambiguity can arise. When parsing
  a fragment, the Rascal evaluator will generate a string that matches this generated syntax. It does so based on
  knowing the type of the variable, which is either declared internally in the '<...>' syntax, or derived by the 
  type checker.
  
  List types are treated differently. The are added as alternatives to the element type, such that an 
  arbitrary number of list variables can be elements of list patterns. To retrieve their original type, we store
  the list symbol as one of the attributes of the generated production.
  
  Another exception is made for lexicals. Since currently the type checker is not inline yet, we can not see at parse time
  which nonterminal names are lexical and which are not. Since nonterminal names are unique between lex and normal nonterminals
  we make sure that the literal that is generated is first normalized to remove all lex names.   
}
public set[Production] holes(Grammar object) {
  // syntax N = @holeType=<N> [\a00] "N" ":" [0-9]+ [\a00];
  return  { regular(iter(\char-class([range(48,57)]))), 
            prod(label("$MetaHole",getTargetSymbol(nont)),
                 [ \char-class([range(0,0)]),
                   lit("<denormalize(nont)>"),lit(":"),iter(\char-class([range(48,57)])),
                   \char-class([range(0,0)])
                 ],{\tag("holeType"(nont))})  
          | Symbol nont <- object.rules, quotable(nont)
          };
}

@doc{
  This function is called by the Rascal interpreter to generate a string that can be parsed by the rules generated by the
  holes function in this module.
}
public str createHole(ConcretePart hole, int idx) = createHole(hole.hole, idx);
public str createHole(ConcreteHole hole, int idx) = "\u0000<denormalize(sym2symbol(hole.symbol))>:<idx>\u0000";


@doc{
  In Rascal programs with type literals, it's hard to see easily if it is a lex or sort, so we "denormalize" here.
  The same goes for the introduction of layout non-terminals in lists. We do not know which non-terminal is introduced,
  so we remove this here to create a canonical 'source-level' type.
}
private Symbol denormalize(Symbol s) = visit (s) { 
  case \lex(n) => \sort(n)
  case \iter-seps(u,[layouts(_),t,layouts(_)]) => \iter-seps(u,[t])
  case \iter-star-seps(u,[layouts(_),t,layouts(_)]) => \iter-star-seps(u,[t])
  case \iter-seps(u,[layouts(_)]) => \iter(u)
  case \iter-star-seps(u,[layouts(_)]) => \iter-star(u)
};

@doc{This is needed such that list variables can be repeatedly used as elements of the same list}
private Symbol getTargetSymbol(Symbol sym) {
  switch(sym) {
    case \iter(s) : return s;
    case \iter-star(s) : return s;  
    case \iter-seps(s, seps) : return s; 
    case \iter-star-seps(s, seps) : return s; 
    default: return sym;
  } 
}

@doc{This decides for which part of the grammar we can write anti-quotes}
private bool quotable(Symbol x) { 
    return \lit(_) !:= x 
       && \empty() !:= x
       && \cilit(_) !:= x 
       && \char-class(_) !:= x 
       && \layouts(_) !:= x
       && \keywords(_) !:= x
       && \start(_) !:= x
       && \parameterized-sort(_,[\parameter(_),_*]) !:= x
       && \parameterized-lex(_,[\parameter(_),_*]) !:= x;
}
