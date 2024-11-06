/*
 * Copyright (C) 2023 Mai-Lapyst
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/** 
 * Module to provide callables for dlang.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codearq.net/mai-lapyst, Mai-Lapyst)
 */
module ninox.std.callable;

import ninox.std.traits;

/// A struct that makes holding any function and/or delegate a breeze!
struct Callable(RetT, ParamsT...) {
    alias FnT = BuildFnType!(RetT, ParamsT);
    alias DgT = BuildDgType!(RetT, ParamsT);

    this(FnT fn) pure nothrow @nogc @safe {
        () @trusted { this.fn = fn; }();
        this.kind = Kind.FN;
    }
    this(DgT dg) pure nothrow @nogc @safe {
        () @trusted { this.dg = dg; }();
        this.kind = Kind.DG;
    }

    private template buildOpCall() {
        import std.conv : to;
        template buildParams(size_t i) {
            static if (i >= ParamsT.length) {
                enum buildParams = "";
            } else {
                alias PT = ParamsT[i];
                enum buildParams = (BuildTypeStr!PT ~ " _arg" ~ i.to!string) ~ ", " ~ buildParams!(i+1);
            }
        }
        template buildCallArgs(size_t i) {
            static if (i >= ParamsT.length) {
                enum buildCallArgs = "";
            } else {
                enum buildCallArgs = ("_arg" ~ i.to!string) ~ ", " ~ buildCallArgs!(i+1);
            }
        }
        enum code =
            BuildTypeStr!RetT ~ " opCall(" ~ buildParams!(0) ~ ") {\n" ~
            "    final switch (this.kind) {\n" ~
            "        case Kind.FN: return fn(" ~ buildCallArgs!(0) ~ ");\n" ~
            "        case Kind.DG: return dg(" ~ buildCallArgs!(0) ~ ");\n" ~
            "        case Kind.NO: throw new Exception(\"Called uninitialzed Callable!\");\n" ~
            "    }\n" ~
            "}"
        ;
        mixin(code);
    }
    mixin buildOpCall!();

    auto opAssign(FnT fn) pure nothrow @nogc @safe {
        () @trusted { this.fn = fn; }();
        this.kind = Kind.FN;
        return this;
    }

    auto opAssign(DgT dg) pure nothrow @nogc @safe {
        () @trusted { this.dg = dg; }();
        this.kind = Kind.DG;
        return this;
    }

    /// Checks if the callable is set or not.
    pragma(inline) @property bool isSet() const pure nothrow @nogc @safe => this.kind != Kind.NO;

    /// Converts this callable to an boolean state, describing wether or not it is set.
    bool opCast(T : bool)() const pure nothrow @nogc @safe => this.kind != Kind.NO;

private:
    enum Kind { NO, FN, DG }
    Kind kind = Kind.NO;
    union {
        FnT fn;
        DgT dg;
    }
}

unittest {
    auto adder = Callable!(int, int, int)( (int a, int b) => a + b );
    assert( adder(12, 34) == (12 + 34) );

    adder = (int a, int b) => a - b;
    assert( adder(22, 10) == 12 );

    int mul(int a, int b) {
        return a * b;
    }

    adder = &mul;
    assert( adder(2, 20) == 40 );
}

unittest {
    alias C = Callable!(void, RefT!int);
    C c = (ref int a) { a *= 2; };

    int i = 12; c(i); assert(i == 24);
}

unittest {
    Callable!(void, int) a;
    assert(!a.isSet);
    assert(!a);

    a = (int i) {};
    assert(a.isSet);
    assert(a);
}
