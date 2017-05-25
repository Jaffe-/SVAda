import std.algorithm;
import std.stdio;

template process_tree(funcs ...) {
    PT process_impl(PT, alias func)(PT tree) {
        foreach (ref child; tree.children) {
            child = process_impl!(PT, func)(child);
        }

        tree = func(tree);

        return tree;
    }

    PT process_tree(PT)(PT tree) {
        foreach (func; funcs) {
            tree = process_impl!(PT, func)(tree);
        }

        return tree;
    }
}

Range stripLeftUntil(Range, E)(Range range, E element) {
    if (range.canFind('.')) {
        return range.stripLeft!(e => e != element);
    } else {
        return range;
    }
}

PT remove_prefix(PT)(PT tree) {
    if (tree.name.canFind('.')) {
        tree.name = tree.name.stripLeftUntil('.')[1 .. $];
    }
    return tree;
}

bool isSequenceExpr(PT)(ref PT tree) {
    return tree.name == "MinSVA.SeqExpr";
}

/* Flatten the chain of operator matches when there is only one child */
template flatten(alias nodes) {
    PT flatten(PT)(PT tree) {
        if (nodes.canFind(tree.name)) {
            if (tree.children.length == 1) {
                return tree.children[0];
            }
        }
        return tree;
    }
}

template join_operators(alias operators) {
    PT join_operators(PT)(PT tree) {
        bool isBinaryOperator(PT tree) {
            return operators.canFind(tree.name);
        }

        if (isBinaryOperator(tree)) {
            typeof(tree.children) new_children;
            foreach (child; tree.children) {
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
}
