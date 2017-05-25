import std.stdio;
import std.algorithm;
import std.array;
import parser;
import expression;

struct Trace {
    enum Value {
        F, T, X
    }

    struct ChangeEvent {
        ulong offset;
        Value new_value;
    }

    private ChangeEvent[] events;

    this(ChangeEvent[] events) {
        this.events = events.dup;
    }

    this(Value[] values) {
        events ~= ChangeEvent(0, values[0]);
        Value last_val = values[0];
        foreach (offset, val; values) {
            if (val != last_val) {
                events ~= ChangeEvent(offset, val);
            }
            last_val = val;
        }
    }

    this(string trace) {
        Value[dchar] vals = ['x': Value.X, '0': Value.F, '1': Value.T];
        this(trace.map!(a => vals[a]).array);
    }
}

interface IChecker {
    public bool match(ref const(Trace) trace);
}

class CombChecker(alias op) : IChecker {
    IChecker[] checkers;
    public bool match(ref const(Trace) trace) {
        bool conclusion = true;
        foreach (checker; checkers) {
            conclusion = mixin(q{conclusion} ~ op ~ q{checker});
        }
        return conclusion;
    }
}

class DelayChecker : IChecker {
    public bool match(ref const(Trace) trace) {
        return false;
    }
}

void main()
{
    auto e = parseExpression("0 || 1 && 1");
    writeln(e);
    auto t = e.create_expression_tree();
    writeln(t);
    t.walk(0);
    writeln(t.value());
    // auto tree = parseSVA("a ##1 a @@ b || c");
    // writeln(tree);
    // auto t2 = create_tree(tree);
    // writeln(t2);

    // auto t = Trace("00001010x");
    // writeln(t);
}
