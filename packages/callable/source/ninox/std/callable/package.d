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
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.std.callable;

/// A struct that makes holding any function and/or delegate a breeze!
struct Callable(RetT, ParamsT...) {
    this(RetT function(ParamsT) fn) pure nothrow @nogc @safe {
        () @trusted { this.fn = fn; }();
        this.kind = Kind.FN;
    }
    this(RetT delegate(ParamsT) dg) pure nothrow @nogc @safe {
        () @trusted { this.dg = dg; }();
        this.kind = Kind.DG;
    }

    RetT opCall(ParamsT params) {
        final switch (this.kind) {
            case Kind.FN: return fn(params);
            case Kind.DG: return dg(params);
            case Kind.NO: throw new Exception("Called uninitialzed Callable!");
        }
    }

private:
    enum Kind { NO, FN, DG }
    Kind kind = Kind.NO;
    union {
        RetT function(ParamsT) fn;
        RetT delegate(ParamsT) dg;
    }
}

unittest {
    auto adder = Callable!(int, int, int)( (int a, int b) => a + b );
    assert( adder(12, 34) == (12 + 34) );
}