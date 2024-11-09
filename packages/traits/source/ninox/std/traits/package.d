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
    else static if (isBasicType!T && !is(T == enum)) {
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
        enum BuildTypeStr = "ref " ~ BuildImportCodeForType!(T.InnerT);
    } else static if (isInstanceOf!(OutT, T)) {
        enum BuildTypeStr = "out " ~ BuildImportCodeForType!(T.InnerT);
    } else static if (isInstanceOf!(LazyT, T)) {
        enum BuildTypeStr = "lazy " ~ BuildImportCodeForType!(T.InnerT);
    } else {
        enum BuildTypeStr = BuildImportCodeForType!T;
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
    import ninox.std.traits : BuildTypeStr, BuildParamStr;
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
    import ninox.std.traits : BuildTypeStr, BuildParamStr;
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

/** 
 * Detectes weather `T` is a indexable object, which can be called with the
 * index operator `[]`.
 * 
 * Params:
 *   indexable = The type to check.
 */
template isIndexable(alias indexable)
{
    static if (is(typeof(&indexable.opIndex) == delegate)) {
        // member function 'opIndex' is present
        enum bool isIndexable = true;
    }
    else static if (is(typeof(&indexable.opIndex) V : V*) && is(V == function)) {
        // static member function 'opIndex' is present
        enum bool isIndexable = true;
    }
    else static if (is(typeof(&indexable.opIndex!()) V : V*) && is(V == function)) {
        enum bool isIndexable = true;
    }
    else {
        import std.traits : isArray, isAssociativeArray;
        enum bool isIndexable = isArray!(indexable) || isAssociativeArray!(indexable);
    }
}

unittest {
    assert(isIndexable!(int[]));
    assert(isIndexable!(int[string]));

    struct S1 {
        void opIndex(int i) {}
    }
    assert(isIndexable!S1);

    struct S2 {
        void opIndex(P...)(P params) {}
    }
    assert(isIndexable!S2);

    struct S3 {
        static void opIndex(int i) {}
    }
    assert(isIndexable!S3);

    struct S4 {
        static void opIndex(P...)(P params) {}
    }
    assert(isIndexable!S4);
}

/** 
 * Applies currying to an template.
 * 
 * Params:
 *   tmpl = The template to curry.
 *   Args = The arguments to supply.
 */
template Curry(alias tmpl, Args...) {
    template Curry(Rest...) {
        alias Curry = tmpl!(Args, Rest);
    }
}

unittest {
    auto fn1(string a, string b)() {
        return a ~ b;
    }
    alias fn2 = Curry!(fn1, "a");
    assert(fn2!("b")() == "ab");

    template T1(string a, string b) {
        enum T1 = a ~ b;
    }
    alias T2 = Curry!(T1, "a");
    assert(T2!("b") == "ab");
}

/*
 * Retruns a `AliasSeq` containing all fields wrapped in a `FieldHandler` for easy access.
 * 
 * Each element of the result a instanciated template with the following member symbols:
 *  - `name`: The string of the fields name, equivalent to `T.tupleof[x].stringof`.
 *  - `type`: Alias for the fields type, equivalent to `typeof(T.tupleof[x])`.
 *  - `index`: The index of the field, i.e. `x` in `T.tupleof[x]`.
 * 
 *  - `has_UDA`: Template which accepts a single argument `attr` to test if the field has the attribute / UDA.
 *               Equivalent to `hasUDA!(T.tupleof[x], attr)`.
 *  - `get_UDAs`: Template which accepts a single argument `attr` to retrieve all attributes / UDAs of that type from the field.
 *                Equivalent to `getUDAs!(T.tupleof[x], attr)`.
 * 
 *  - `compiles`: A boolean value if access to the field compiles.
 *                Equivalent to `__traits(compiles, mixin("T." ~ T.tupleof[x].stringof))`.
 *  - `member`: Get the member, equivalent to `__traits(getMember, T, T.tupleof[x].stringof)`.
 *  - `raw`: The raw element this wrapper was constructed from, i.e. `T.tupleof[x]`.
 */
template GetFields(alias T) {
    import std.meta : AliasSeq;
    template FieldHandler(size_t i, alias E) {
        enum name = E.stringof;
        alias type = typeof(E);
        enum index = i;
        template has_UDA(alias attr) {
            import std.traits : hasUDASys = hasUDA;
            alias has_UDA = hasUDASys!(E, attr);
        }
        template get_UDAs(alias attr) {
            import std.traits : getUDAsSys = getUDAs;
            alias get_UDAs = getUDAsSys!(E, attr);
        }
        enum compiles = __traits(compiles, mixin("T." ~ E.stringof));
        alias member = __traits(getMember, T, E.stringof);
        alias raw = E;
    }
    alias GetFields = AliasSeq!();
    static foreach (i, arg; T.tupleof)
        GetFields = AliasSeq!(GetFields, FieldHandler!(i, arg));
}

/** 
 * Applies for every field in `T` the handler template `Handler`.
 * 
 * This is done by first retrieveing all fields with `ninox.std.traits.GetFields!T`,
 * and mapping that afterwards with `std.meta.staticMap!(Handler, Fields)`.
 * 
 * Params:
 *   T = The type to map fields for.
 *   Handler = The handler to call for each field.
 *   Default = A default value if the `AliasSeq` produced contains no values.
 * 
 * Example:
-----------------
struct MyUDA { string s; }
struct S {
    @MyUDA("hello") int i;
    long j;
}

template MyHandler(alias Field) {
    static if (Field.has_UDA!MyUDA) {
        enum MyHandler = "Field " ~ Field.name ~ " has type " ~ Field.type.stringof ~ " with @MyUDA(s = " ~ Field.get_UDAs!MyUDA[0].s ~ ")";
    }
    else {
        enum MyHandler = "Field " ~ Field.name ~ " has type " ~ Field.type.stringof;
    }
}

import std.string : join;
enum Msg = [ MapFields!(S, MyHandler) ].join("\n");
static assert(Msg, "Field i has type int with @MyUDA(s = hello)\nField j has type long\n");
-----------------
 */
template MapFields(alias T, alias Handler, alias Default = imported!"std.meta".AliasSeq!()) {
    import std.meta : staticMap;
    alias _tmp = staticMap!(Handler, GetFields!T);
    static if (_tmp.length < 1) {
        alias MapFields = Default;
    } else {
        alias MapFields = _tmp;
    }
}

unittest {
    struct MyUDA { string s; }
    struct S {
        @MyUDA("hello") int i;
        long j;
    }

    template MyHandler(alias Field) {
        static if (Field.has_UDA!MyUDA) {
            enum MyHandler = "Field " ~ Field.name ~ " has type " ~ Field.type.stringof ~ " with @MyUDA(s = " ~ Field.get_UDAs!MyUDA[0].s ~ ")";
        }
        else {
            enum MyHandler = "Field " ~ Field.name ~ " has type " ~ Field.type.stringof;
        }
    }

    import std.string : join;
    enum Msg = [ MapFields!(S, MyHandler) ].join("\n");
    static assert(Msg, "Field i has type int with @MyUDA(s = hello)\nField j has type long\n");
}

/** 
 * Retruns a `AliasSeq` containing all derived members wrapped in a `MemberHandler` for easy access.
 * 
 * Each element of the result a instanciated template with the following member symbols:
 *  - `name`: The string of the members name.
 *  - `type`: Alias for the members type.
 *  - `index`: The index of the member, as they appeared in `__traits(derivedMembers, T)`.
 * 
 *  - `has_UDA`: Template which accepts a single argument `attr` to test if the field has the attribute / UDA.
 *               Equivalent to `hasUDA!(Member, attr)`.
 *  - `get_UDAs`: Template which accepts a single argument `attr` to retrieve all attributes / UDAs of that type from the field.
 *                Equivalent to `getUDAs!(Member, attr)`.
 * 
 *  - `compiles`: A boolean value if access to the field compiles.
 *                Equivalent to `__traits(compiles, mixin("T." ~ Member.Name))`.
 *  - `raw`: The underlying member value, i.e. `__traits(getMember, T, Member.Name)`.
 * 
 * Params:
 *   T = The type whose derived members should be returned.
 */
template GetDerivedMembers(alias T) {
    import std.meta : Filter;
    import std.traits : isFunction;
    template MemberHandler(size_t i, alias E) {
        enum name = E;
        static if (isFunction!(__traits(getMember, T, E))) {
            enum raw = &__traits(getMember, T, E);
        } else {
            alias raw = __traits(getMember, T, E);
        }
        alias type = typeof(raw);
        enum index = i;
        template has_UDA(alias attr) {
            import std.traits : hasUDASys = hasUDA;
            alias has_UDA = hasUDASys!(__traits(getMember, T, E), attr);
        }
        template get_UDAs(alias attr) {
            import std.traits : getUDAsSys = getUDAs;
            alias get_UDAs = getUDAsSys!(__traits(getMember, T, E), attr);
        }
        enum compiles = __traits(compiles, mixin("T." ~ E));
    }
    enum isMember(alias E) = !is(__traits(getMember, T, E));
    alias GetDerivedMembers = staticMapWithIndex!(MemberHandler, Filter!(isMember, __traits(derivedMembers, T)));
}

unittest {
    struct MyUDA {}
    struct S {
        @MyUDA
        void f() {}
    }

    alias members = GetDerivedMembers!S;
    static assert(members[0].name == "f");
    static assert(is(members[0].type == function));
    static assert(members[0].has_UDA!MyUDA);
}

/** 
 * Like `std.meta.staticMap`, but also passes the index to the callback.
 * 
 * Params:
 *   callback = The template to call with `!(i, arg)`.
 *   args = The arguments to map.
 */
template staticMapWithIndex(alias callback, args...)
{
    import std.meta : AliasSeq;
    alias staticMapWithIndex = AliasSeq!();
    static foreach (i, arg; args)
        staticMapWithIndex = AliasSeq!(staticMapWithIndex, callback!(i, arg));
}

unittest {
    import std.meta : AliasSeq;
    alias list = AliasSeq!( "a", "b" );

    template Mapper(size_t i, alias elem)
    {
        import std.conv : to;
        enum Mapper = i.to!string ~ "=>" ~ elem;
    }
    alias res = staticMapWithIndex!(Mapper, list);
    static assert(res[0] == "0=>a");
    static assert(res[1] == "1=>b");
}
