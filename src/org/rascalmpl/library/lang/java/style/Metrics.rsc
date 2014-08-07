module lang::java::style::Metrics

import analysis::m3::Core;
import lang::java::m3::Core;
import lang::java::m3::AST;
import Message;
import String;
import Set;

import lang::java::jdt::m3::Core;		// Java specific modules
import lang::java::jdt::m3::AST;

import lang::java::style::Utils;

import IO;

/*
BooleanExpressionComplexity		DONE
ClassDataAbstractionCoupling	DONE
ClassFanOutComplexity			DONE
CyclomaticComplexity			DONE
NPathComplexity					DONE
JavaNCSS						TBD
*/

data Message = metric(str category, loc pos);

list[Message] metricsChecks(node ast, M3 model, list[Declaration] allClasses, list[Declaration] allMethods) {
	return 
		  booleanExpressionComplexity(ast, model, allClasses, allMethods) 
		+ classDataAbstractionCoupling(ast, model, allClasses, allMethods)
		+ classFanOutComplexity(ast, model, allClasses, allMethods)
		+ cyclomaticComplexity(ast, model, allClasses, allMethods)
		+ nPathComplexity(ast, model, allClasses, allMethods)
		;
}
	
list[Message] booleanExpressionComplexity(node ast, M3 model, list[Declaration] allClasses, list[Declaration] allMethods){
	msgs = [];
	
	bool tooManyBooleanOperators(Expression e){
	   int cnt = 0;
	   visit(e){
		 case \infix(_, str operator, _):
			 if(operator in {"&&", "&", "||", "|", "^"}) cnt += 1;
		 case \prefix("!", _): cnt += 1;
	   }
	   return cnt > 3;
    }
	
	top-down-break visit(ast){
		case Expression e: 
			if(tooManyBooleanOperators(e)) { msgs += metric("BooleanExpressionComplexity", e@src); }
	}
	return msgs;
}

set[str] excludedClasses = {	// TODO: verify that these names really work (may use a loc?)
	"boolean", "byte", "char", "double", "float", "int", "long", "short", "void", 
	"Boolean", "Byte", "Character", "Double", "Float", "Integer", "Long", "Short", 
	"Void", "Object", "Class", "String", "StringBuffer", "StringBuilder", 
	"ArrayIndexOutOfBoundsException", "Exception", "RuntimeException", 
	"IllegalArgumentException", "IllegalStateException", "IndexOutOfBoundsException", 
	"NullPointerException", "Throwable", "SecurityException", "UnsupportedOperationException", 
	"List", "ArrayList", "Deque", "Queue", "LinkedList", "Set", "HashSet", "SortedSet", "TreeSet", 
	"Map", "HashMap", "SortedMap", "TreeMap"};

list[Message] classDataAbstractionCoupling(node ast, M3 model, list[Declaration] allClasses, list[Declaration] allMethods){ 
	invNames = model@names<1,0>;
	
	str getName(loc declaration){
		if({ name } := invNames[declaration])
			return name;
	}
    set[str] getNew(Declaration ast){
    	news = {};
    	visit(ast){
    		case obj: \newObject(Expression expr, Type \type, list[Expression] args, Declaration class):
    			news += getName(obj@typ.decl);
    			
    		case obj: \newObject(Expression expr, Type \type, list[Expression] args):
    			news += getName(obj@typ.decl);
    		
    		case obj: \newObject(Type \type, list[Expression] args, Declaration class):
    			news += getName(obj@typ.decl);
    		
    		case obj: \newObject(Type \type, list[Expression] args): 
    			news += getName(obj@typ.decl);
    	}
    	return news;
    }
    bool tooManyNew(Declaration class){
    	return size(getNew(class) - excludedClasses) > 7;
    }

	return 
		[ metric("ClassDataAbstractionCoupling", c@src) | c <- getAllClasses(ast), tooManyNew(c) ];
}

list[Message] classFanOutComplexity(node ast, M3 model, list[Declaration] allClasses, list[Declaration] allMethods){
	return 
		[ metric("ClassFanOutComplexity", c) | c <- classes(model), size(model@typeDependency[model@containment[c]] - excludedClasses) > 7 ];
}

list[Message] cyclomaticComplexity(node ast, M3 model, list[Declaration] allClasses, list[Declaration] allMethods){
	msgs = [];
	void checkCC(Statement body){
		int cnt = 1;
		visit(body){
			case \do(_, _): 			cnt += 1;
			case \while(_, _): 			cnt += 1;
    		case \foreach(_, _, _): 	cnt += 1;
    		case \for(_, _, _, _) : 	cnt += 1;
    		case \for(_, _, _): 		cnt += 1;
    		case \if(_, _): 			cnt += 1;
    		case \if(_, _, _): 			cnt += 1;
			case \case(_): 				cnt += 1;
			case \conditional(_, _, _): cnt += 1;
  			case \catch(_, _): 			cnt += 1;
   			case \infix(_, "&&", _): cnt += 1;
    		case \infix(_, "||", _): cnt + 1;
		}
		if(cnt > 10) msgs += metric("CyclomaticComplexity", body@src);
	}
	
	top-down-break visit(ast){
		case \initializer(Statement initializerBody): checkCC(initializerBody);
    	case \method(_, _, _, _, Statement impl): 	checkCC(impl);
    	case \constructor(_, _, _, Statement impl): checkCC(impl);
	}
	return msgs;
}

list[Message] nPathComplexity(node ast, M3 model, list[Declaration] allClasses, list[Declaration] allMethods){
	msgs = [];
	void checkNPath(Statement body){
		if(nPath(body) > 200){
			msgs += metric("NPathComplexity", body@src);
		}
	}
	top-down-break visit(ast){
		case \initializer(Statement initializerBody): checkNPath(initializerBody);
    	case \method(_, _, _, _, Statement impl): 	checkNPath(impl);
    	case \constructor(_, _, _, Statement impl): checkNPath(impl);
	}
	return msgs;
}

// http://pmd.sourceforge.net/pmd-4.3.0/xref/net/sourceforge/pmd/rules/design/NpathComplexity.html

int nPathExpression(Expression e){
	cnt = 1;
	visit(e){
		case \infix(_, "&&", _): 	
			cnt += 1;
    	case \infix(_, "||", _): 	
    		cnt += 1;
	}
	return cnt;
}

int nPath(node ast){
	switch(ast){
			case \block(list[Statement] statements):
					return (1 | it * nPath(s) | s <- statements);
					
			case \do(body,cond): 		
					return nPathExpression(cond) + nPath(body) + 1;
					
			case \while(cond, body): 	
					return nPathExpression(cond) + nPath(body) + 1;
					
    		case \foreach(_, _,body): 	
    				return nPath(body);
    				
    		case \for(_, cond, _, body):
    				return nPathExpression(cond) + nPath(body) + 1;
    				
    		case \for(_, _, body): 		
    				return nPath(body);
    				
    		case \if(cond, thenBranch): 
    				return nPathExpression(cond) + nPath(thenBranch) + 1;
    				
    		case \if(cond, thenBranch, elseBranch):
    				return nPathExpression(cond) + nPath(thenBranch) + nPath(elseBranch);
    				
			case \switch(Expression expression, list[Statement] statements):
					return nPathExpression(expression) + (0 | it + nPath(s) | s <- statements);
					
			case \case(_):
					return 0;
					
			case \defaultCase():
					return 0;
			
			case \try(Statement body, list[Statement] catchClauses):
					return nPath(body) + (0 | it + nPath(s) | s <- catchClauses);
					
    		case \try(Statement body, list[Statement] catchClauses, Statement \finally):                                        
					return nPath(body) + (0 | it + nPath(s) | s <- catchClauses) + nPath(\finally);
										
  			case \catch(_, body): 		
  					return nPath(body);

    			case \return(Expression e): 
    				return nPathExpression(e);
    		
    		default:
    			return 1;
		}
}
