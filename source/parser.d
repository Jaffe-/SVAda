import std.stdio;
import pegged.grammar;
import std.algorithm;
import std.array;
import expression;
import parseutil;

PT ignoreEmpty(PT)(PT p) {
    if (p.children.length == 1) {
        return p.children[0];
    }
    return p;
}

mixin(grammar(`
MinSVA:
    OrExpr          < AndExpr ("or" AndExpr)* { ignoreEmpty }

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

    Expr         < MinSVAExpr.Expr

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
`));


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

enum nodes_to_flatten = ["And", "Or", "Throughout", "Within", "Intersect", "SeqExpr"];

auto parseSVA(string sva) {
    auto parse_tree = MinSVA(sva);
    return parse_tree
        .process_tree!(flatten!nodes_to_flatten);
}
