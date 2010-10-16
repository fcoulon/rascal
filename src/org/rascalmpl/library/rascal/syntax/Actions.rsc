module rascal::syntax::Actions

import rascal::syntax::Grammar;
import rascal::syntax::Generator;
import ParseTree;

public tuple[Grammar grammar, map[Production, Tree] actions] extractActions(Grammar g) {
  actions = ();
  
  g = visit (g) {
    case \action(Symbol nt, p:prod(_,_,_), Tree action) : {
      actions[unmeta(p)] = unmeta(action);
      insert p;
    }
  }
  
  return <g, actions>;
}