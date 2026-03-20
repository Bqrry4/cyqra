module cyqra::interpreter;
import std::io;

import cyqra::parser::ast;

struct Interpreter
{
	Allocator allocator;

	Scope* global_scope;
}

fn Interpreter new(
	Allocator allocator
)
{
	Scope* global_scope = scope::new_ref(allocator);
	return {
		.allocator = allocator,
		.global_scope = global_scope
	};
}

fn void Interpreter.free(&self)
{
	self.global_scope.free();
	allocator::free(self.allocator, self.global_scope);
}

fn void Interpreter.interpret(&self, Ast ast)
{
	foreach (expr: ast.expressions) {
		Value val = self.eval(expr);
		String s_val = val.to_string(self.allocator);
		io::printn(s_val);
		s_val.free(self.allocator);	
	}
}

fn Value Interpreter.eval(&self, Expr* expr)
{
	switch (expr.kind) {
		case PRIMARY:
			return self.eval_primary(&expr.primary);			
		case STRING:
			return self.eval_string(&expr.string);
		// case PREFIX:
		// 	expr.prefix.eval();
		// case POSTFIX:
		// 	expr.postfix.eval();
		// case INFIX:
		// 	return self.infix.eval(scope);
	// case CALL:
		// 	expr.call.eval();
		// case INDEX:
		// 	expr.index.eval();
		case BINDING:
			return self.eval_binding(&expr.binding);
		case BLOCK:
			return self.eval_block(&expr.block);
		// case FUNCTION:
		// 	expr.block.eval();
		default: io::printn("not implemented");
	}
	return value::UNIT;
}

fn Value Interpreter.eval_primary(&self, Primary* expr)
{
	switch (expr.token.kind) {
		case INTEGER: return {
			.kind = INT,
			._int = expr.token.slice.to_long()!!
		};
		case FLOAT: return {
			.kind = FLOAT,
			._float = expr.token.slice.to_double()!!
		};
		case IDENTIFIER:
			return self.global_scope.get(expr.token.slice)!!;
		default: unreachable("Unreachable reached in primary eval"); 
	}
}

fn Value Interpreter.eval_string(&self, StringLiteral* expr)
{
	DString dstring = (DString){}.init(self.allocator);

	foreach (part: expr.parts) {
		switch (part.kind) {
			case TEXT:
				dstring.append(part.text);
			case INTERP:
				Value val = self.eval(part.interp);
				dstring.append(val.to_string(self.allocator));			
		}
	}

	String result = dstring.copy_str(self.allocator);
	dstring.free();
	
	return {
		.kind = STRING,
		._string = result
	};
}

// fn Value Infix.eval(&self, Scope* scope)
// {
// 	Value lhs_v = self.lhs.eval(scope);
// 	Value rhs_v = self.rhs.eval(scope);

// 	switch (self.op) {
// 		case PLUS:
// 			if (lhs_v.kind == INT && rhs_v.kind == INT) {
//                 return {
// 					.kind = INT,
// 					._int = lhs_v._int + rhs_v._int,
// 				};
//             }
//             unreachable("invalid operands for +");
// 		case MINUS:
// 		case STAR:
// 		default: unreachable("Unreacahble reached in infix eval");	
// 	}		
// }

fn Value Interpreter.eval_binding(&self, Binding* expr)
{
	Value value = self.eval(expr.value);
	self.global_scope.set(expr.identifier.slice, value);

	return value::UNIT;
}

fn Value Interpreter.eval_block(&self, Block* expr)
{
	return value::UNIT;	
}
