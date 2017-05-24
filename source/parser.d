import std.stdio;
import pegged.grammar;
import std.algorithm;
import std.array;

mixin(grammar(`
MinSVA:
    OrExpr          < AndExpr ("or" AndExpr)*

    AndExpr         < IntersectExpr ("and" IntersectExpr)*

    IntersectExpr   < WithinExpr ("intersect" WithinExpr)*

    WithinExpr      < ThroughoutExpr ("within" ThroughoutExpr)*

    ThroughoutExpr  < DelayExpr ("throughout" DelayExpr)*

    DelayExpr       < SeqExpr (CycleDelay SeqExpr)*

    SeqExpr     < CycleDelay SeqExpr (CycleDelay SeqExpr)*
                / RepExpr
                / Expr
                / '(' OrExpr ')'

    RepExpr     < Expr (ConsRep / NonconsRep / GotoRep)
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

    CycleDelay   < "##" (
                      Number
                    / '[' ConstRange ']'
                    / ZeroOrMoreRep
                    / OneOrMoreRep)

    ConstRange   < Number ':' (Number / '$')

    ZeroOrMoreRep   < "[*]"
    OneOrMoreRep    < "[+]"

    ConsRep         < "[*" (ConstRange / Number) ']'
                     / ZeroOrMoreRep
                     / OneOrMoreRep

    NonconsRep      < "[=" (ConstRange / Number) ']'

    GotoRep         < "[->" (ConstRange / Number) ']'

    Number          < ~([0-9]+)

    Name            < identifier

`));

bool isBinaryOperator(PT)(ref PT tree) {
    return ["And",
            "Or",
            "Within",
            "Throughout",
            "Intersect",
            "BoolOr",
            "BoolAnd",
            "BitOr",
            "BitXor",
            "BitAnd",
            "CaseEql",
            "Eql",
            "Comp",
            "Shift",
            "SubAdd",
            "MulDivMod"]
        .map!(s => "MinSVA." ~ s ~ "Expr").canFind(tree.name);
}

bool isSequenceExpr(PT)(ref PT tree) {
    return tree.name == "MinSVA.SeqExpr";
}

/* Flatten the chain of operator matches when there is only one child */
PT flatten(PT)(ref PT tree) {
    if (tree.children.empty) {
        return tree;
    }
    foreach (ref child; tree.children) {
        child = flatten(child);
    }
    if (isBinaryOperator(tree)
        || isSequenceExpr(tree)
        || tree.name == "MinSVA.Expr") {
        if (tree.children.length == 1) {
            return tree.children[0];
        }
    }
    return tree;
}

PT join_operators(PT)(PT tree) {
    if (tree.children.empty) {
        return tree;
    }

    foreach (ref child; tree.children) {
        child = join_operators(child);
    }

    if (isBinaryOperator(tree)) {
        typeof(tree.children) new_children;
        foreach (ref child; tree.children) {
            if (isBinaryOperator(child) && child.name == tree.name) {
                new_children ~= child.children;
            }
            else {
                new_children ~= child;
            }
        }
        tree.children = new_children;
    }
    return tree;
}

template ForwardChildren(T) {
    this(T[] children) {
        super(children);
    }
}

template Walk() {
    public override void walk() {
        writeln(typeof(this).stringof ~ ": dep = ", dependencies);
        foreach (child; children) {
            child.walk();
        }
    }
}

class Node {
    Node[] children;

    this(Node[] children) {
        this.children = children;
    }

    public void walk() {
        writeln("Node");
        foreach (child; children) {
            child.walk();
        }
    }
}

class SequenceOperator(alias op) : Node {
    mixin ForwardChildren!Node;
}

class DelayExpression : Node {
    mixin ForwardChildren!Node;
}

class Repetition : Node {
    mixin ForwardChildren!Node;
}

class Expression : Node {
    string[] dependencies;

    this(Expression[] children) {
        super(cast(Node[])children);
        foreach (child; children) {
            dependencies ~= setDifference(child.dependencies, dependencies).array;
        }
    }

    mixin Walk;
}

class Operator(alias op) : Expression {
    mixin ForwardChildren!Expression;
    mixin Walk;
}

class Name : Expression {
    string identifier;

    this(string name) {
        super(null);
        identifier = name;
        dependencies = [name];
    }

    mixin Walk;
}

Node create_tree(PT)(ref PT parse_tree) {
    Node[] children;
    foreach (ref child; parse_tree.children) {
        auto node = create_tree(child);
        if (node !is null) {
            children ~= node;
        }
    }

    switch (parse_tree.name) {
    default:
        return null;
    case "MinSVA.Name":
        return new Name(parse_tree.matches[0]);
    case "MinSVA.BoolOrExpr":
        return new Operator!"||"(children);
    case "MinSVA.BoolAndExpr":
        return new Operator!"&&"(children);
    case "MinSVA.BitOrExpr":
        return new Operator!"|"(children);
    case "MinSVA.BitXorExpr":
        return new Operator!"Eql"(children);
    case "MinSVA.EqlExpr":
        return new Operator!"Eql"(children);
    }
}

auto parseSVA(string sva) {
    auto parse_tree = MinSVA(sva);
    return parse_tree
        .flatten
        .join_operators;
}
