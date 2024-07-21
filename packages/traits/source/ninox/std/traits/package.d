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
 * Module to provide helpfull traits & templates
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codearq.net/mai-lapyst, Mai-Lapyst)
 */
module ninox.std.traits;

/**
 * Compile-time helper to generate code to import any time via the "imported!" mecanism.
 * 
 * Params:
 *   T = the type to generate code for
 */
template BuildImportCodeForType(alias T) {
    import std.traits;

    static if (isArray!T) {
        alias VTy(V : V[]) = V;
        enum BuildImportCodeForType = BuildImportCodeForType!(VTy!T) ~ "[]";
    }
    else static if (isAssociativeArray!T) {
        enum BuildImportCodeForType = BuildImportCodeForType!(ValueType!T) ~ "[" ~ BuildImportCodeForType!(KeyType!T) ~ "]";
    }
    else static if (isBasicType!T) {
        enum BuildImportCodeForType = T.stringof;
    }
    else static if (isSomeString!T) {
        enum BuildImportCodeForType = T.stringof;
    }
    else {
        enum FullType = fullyQualifiedName!T;
        enum Mod = moduleName!T;
        auto delMod(Range)(Range inp, Range mod) {
            import std.traits : isDynamicArray;
            import std.range.primitives : ElementEncodingType;
            static import std.ascii;
            static import std.uni;

            size_t i = 0;
            for (const size_t end = mod.length; i < end; ++i) {
                if (inp[i] != mod[i]) {
                    break;
                }
            }
            inp = inp[i .. $];
            return inp;
        }
        enum Name = delMod(FullType, Mod);

        enum BuildImportCodeForType = "imported!\"" ~ Mod ~ "\"" ~ Name;
    }
}

unittest {
    struct Test {}

    static assert (BuildImportCodeForType!Test == "imported!\"ninox.std.traits\".__unittest_L73_C1.Test");
    static assert (BuildImportCodeForType!(Test[int]) == "imported!\"ninox.std.traits\".__unittest_L73_C1.Test[int]");
    static assert (BuildImportCodeForType!(Test[string]) == "imported!\"ninox.std.traits\".__unittest_L73_C1.Test[immutable(char)[]]");
    static assert (BuildImportCodeForType!(Test[]) == "imported!\"ninox.std.traits\".__unittest_L73_C1.Test[]");
}

/** 
 * Helper to mark an type `T` as an `ref T`.
 * 
 * Used in `ninox.std.traits.BuildTypeStr`.
 * 
 * Params:
 *   T = The type to use.
 */
template RefT(alias T) {
    alias InnerT = T;
}

/** 
 * Helper to mark an type `T` as an `out T`.
 * 
 * Used in `ninox.std.traits.BuildTypeStr`.
 * 
 * Params:
 *   T = The type to use.
 */
template OutT(alias T) {
    alias InnerT = T;
}

/** 
 * Helper to mark an type `T` as an `lazy T`.
 * 
 * Used in `ninox.std.traits.BuildTypeStr`.
 * 
 * Params:
 *   T = The type to use.
 */
template LazyT(alias T) {
    alias InnerT = T;
}

/** 
 * Helper to build a string representation of an type `T`.
 * 
 * Note that:
 *  - instances of `ninox.std.traits.RefT!T` are converted to `ref T`
 *  - instances of `ninox.std.traits.OutT!T` are converted to `out T`
 *  - instances of `ninox.std.traits.LazyT!T` are converted to `lazy T`
 * 
 * Params:
 *   T = The type to build a string representation of.
 */
template BuildTypeStr(alias T)
{
    import std.traits : isInstanceOf;
    import ninox.std.traits : RefT, OutT, LazyT;
    static if (isInstanceOf!(RefT, T)) {
        enum BuildTypeStr = "ref " ~ T.InnerT.stringof;
    } else static if (isInstanceOf!(OutT, T)) {
        enum BuildTypeStr = "out " ~ T.InnerT.stringof;
    } else static if (isInstanceOf!(LazyT, T)) {
        enum BuildTypeStr = "lazy " ~ T.InnerT.stringof;
    } else {
        enum BuildTypeStr = T.stringof;
    }
}

unittest {
    assert(BuildTypeStr!int == "int");
    assert(BuildTypeStr!(RefT!int) == "ref int");
    assert(BuildTypeStr!(OutT!int) == "out int");
    assert(BuildTypeStr!(LazyT!int) == "lazy int");
}

private template BuildParamStr(ParamsT...)
{
    import std.meta : staticMap;
    import std.string : join;
    enum BuildParamStr = [ staticMap!(BuildTypeStr, ParamsT) ].join(",");
}

/** 
 * Builds a function type from a return type and zero or more parameter types.
 * If any given type is an instance of `ninox.std.traits.Ref`, a `ref T` is emitted.
 * 
 * Params:
 *   RetT = The returntype of the function.
 *   ParamsT = The parameter types of the function.
 */
template BuildFnType(RetT, ParamsT...) {
    import ninox.std.traits : BuildParamStr;
    alias BuildFnType = mixin(
        BuildTypeStr!RetT ~ " function(" ~ BuildParamStr!ParamsT ~ ")"
    );
}

unittest {
    assert(is(BuildFnType!(void, int) == void function(int)));
    assert(is(BuildFnType!(void, RefT!int) == void function(ref int)));
    assert(is(BuildFnType!(void, OutT!int) == void function(out int)));
    assert(is(BuildFnType!(void, LazyT!int) == void function(lazy int)));
}

/** 
 * Builds a delegate type from a return type and zero or more parameter types.
 * If any given type is an instance of `ninox.std.traits.Ref`, a `ref T` is emitted.
 * 
 * Params:
 *   RetT = The returntype of the delegate.
 *   ParamsT = The parameter types of the delegate.
 */
template BuildDgType(RetT, ParamsT...) {
    import ninox.std.traits : BuildParamStr;
    alias BuildDgType = mixin(
        BuildTypeStr!RetT ~ " delegate(" ~ BuildParamStr!ParamsT ~ ")"
    );
}

unittest {
    assert(is(BuildDgType!(void, int) == void delegate(int)));
    assert(is(BuildDgType!(void, RefT!int) == void delegate(ref int)));
    assert(is(BuildDgType!(void, OutT!int) == void delegate(out int)));
    assert(is(BuildDgType!(void, LazyT!int) == void delegate(lazy int)));
}
