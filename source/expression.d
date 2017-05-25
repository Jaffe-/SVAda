import std.stdio;
import std.algorithm;
import std.array;
import std.meta;
import std.range;
import std.conv;
import pegged.grammar;
import parseutil;

PT ignoreEmpty(PT)(PT p) {
    if (p.children.length == 1) {
        return p.children[0];
    }
    return p;
}

mixin(grammar(`
MinSVAExpr:
    Expr        < UnaryOp Expr
                / BoolOrExpr
                / Number
                / Name
                / '(' Expr ')'

    BoolOrExpr  < BoolAndExpr ("||" BoolAndExpr)*
    BoolAndExpr < BitOrExpr ("&&" BitOrExpr)*
    BitOrExpr   < BitXorExpr ("|" BitXorExpr)*
    BitXorExpr  < BitAndExpr (("^" / "~^" / "^~") BitAndExpr)*
    BitAndExpr  < CaseEqlExpr ("&" CaseEqlExpr)*
    CaseEqlExpr < EqlExpr (("===" / "!===") EqlExpr)*
    EqlExpr     < CompExpr (("==" / "!=") CompExpr)*
    CompExpr    < ShiftExpr (("<" / "<=" / ">=" / ">") ShiftExpr)*
    ShiftExpr   < SubAddExpr (("<<" / ">>") SubAddExpr)*
    SubAddExpr  < MulDivModExpr (("+" / "-") MulDivModExpr)*
    MulDivModExpr < Expr (("*" / "/" / "%") Expr)*

    UnaryOp     < '+' / '-' / '!' / '~'

    Number          < ~([0-9]+)

    Name            < identifier
`));

enum operators = ["BoolOrExpr",
                  "BoolAndExpr",
                  "BitOrExpr",
                  "BitXorExpr",
                  "BitAndExpr",
                  "CaseEqlExpr",
                  "EqlExpr",
                  "CompExpr",
                  "ShiftExpr",
                  "SubAddExpr",
                  "MulDivModExpr"];

Expression make_operator(string op, Expression[] children) {
    template ExprType(alias name) {
        mixin("alias ExprType = " ~ name ~ ";");
    }

    assert(operators.canFind(op));

    foreach (select_op; aliasSeqOf!(operators)) {
        if (select_op == op) {
            return new ExprType!select_op(children);
        }
    }

    assert(false, "Invalid op given: " ~ op);
}

alias Value = ulong;

class Expression {
    string[] dependencies;
    Expression[] children;

    this() {
    }
    this(Expression[] children) {
        this.children = children;
    }

    void walk(int level) {
        writeln('\t'.repeat(level), typeof(this).stringof);
        foreach (child; children) {
            child.walk(level + 1);
        }
    }

    Value value() {
        return children[0].value();
    }
}

template Walk() {
    override void walk(int level) {
        writeln('\t'.repeat(level), typeof(this).stringof);
        foreach (child; children) {
            child.walk(level + 1);
        }
    }
}

template ForwardingConstructor() {
    this(Expression[] children) {
        super(children);
    }
}

class BoolOrExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return children.map!(c => c.value()).any!(x => x != 0);
    }
}

class BoolAndExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return children.map!(c => c.value()).all!(x => x != 0);
    }
}

class BitOrExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class BitXorExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class BitAndExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class CaseEqlExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class EqlExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class CompExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class ShiftExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class SubAddExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class MulDivModExpr : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class UnaryOperator(alias op) : Expression {
    mixin ForwardingConstructor;
    mixin Walk;

    override ulong value() {
        return 0;
    }
}

class Number : Expression {
    Value val;

    this(string repr) {
        val = to!Value(repr);
    }

    override void walk(int level) {
        writeln('\t'.repeat(level), "number=", val);
    }

    override Value value() {
        return val;
    }
}

bool isBinaryOperator(PT)(PT tree) {
    return operators.canFind(tree.name);
}

Expression create_expression_tree(PT)(PT tree) {
    Expression[] children;
    string[] this_matches = tree.matches;
    foreach (child; tree.children) {
        auto child_expr = create_expression_tree(child);
        if (child_expr !is null) {
            children ~= child_expr;
        }
        this_matches = setDifference(this_matches, child.matches).array;
    }

    if (isBinaryOperator(tree)) {
        return make_operator(tree.name, children);
    }

    switch (tree.name) {
    default:
        return new Expression(children);
    case "Number":
        return new Number(tree.matches[0]);
    }
}

auto parseExpression(string expr) {
    auto parse_tree = MinSVAExpr(expr);

    enum to_flatten = operators ~ "Expr";

    return parse_tree
        .process_tree!(remove_prefix, flatten!to_flatten, join_operators!operators);
}
