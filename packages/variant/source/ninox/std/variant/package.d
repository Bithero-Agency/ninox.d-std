/*
 * Copyright (C) 2024 Mai-Lapyst
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
 * Module to provide variants for dlang.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2024 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.std.variant;

import std.meta;
import std.traits;

class VariantException : Exception {
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line, nextInChain);
    }
}

struct Variant {
    // -------------------- Fields --------------------

    private {
        void[] _data;
        bool function(Op op, void* dest, TypeInfo ty, const void[] data) _handler;
    }

    // -------------------- handler implementations --------------------

    private enum Op {
        unknown,
        getTypeInfo,
        tryPut,
        isTruthy,
    }

    private static bool handler(T)(Op op, void* dest, TypeInfo ty, const void[] data) {

        bool tryPut(void* dest, TypeInfo ty, void* data) {
            alias UT = Unqual!T;

            alias MutTypes = AliasSeq!(UT, AllImplicitConversionTargets!UT);
            alias ConstTypes = staticMap!(ConstOf, MutTypes);
            alias ImmuTypes = staticMap!(ImmutableOf, MutTypes);
            alias SharedTypes = staticMap!(SharedOf, MutTypes);
            alias SharedConstTypes = staticMap!(SharedConstOf, MutTypes);

            static if (is(T == immutable)) {
                alias AllTypes = AliasSeq!(ImmuTypes, ConstTypes, SharedConstTypes);
            }
            else static if (is(T == shared)) {
                static if (is(T == const)) {
                    alias AllTypes = SharedConstTypes;
                }
                else {
                    alias AllTypes = AliasSeq!(SharedTypes, SharedConstTypes);
                }
            }
            else static if (is(T == const)) {
                alias AllTypes = ConstTypes;
            }
            else {
                alias AllTypes = AliasSeq!(MutTypes, ConstTypes, ImmuTypes);
            }

            foreach (TC; AllTypes) {
                if (ty != typeid(TC)) {
                    continue;
                }

                static if (is(T == class) || is(T == interface)) {
                    if (dest !is null) {
                        T* src = cast(T*) data;
                        *(cast(Unqual!TC*) dest) = cast(Unqual!TC) *src;
                    }
                }
                else static if (isArray!T || isAssociativeArray!T) {
                    if (dest !is null) {
                        T* src = cast(T*) data;
                        *cast(T*) dest = *src;
                    }
                }
                else static if (isScalarType!T) {
                    T* src = cast(T*) data;
                    static if (
                        is(typeof(delegate TC() { return *src; }))
                        || is(TC == const(U), U)
                        || is(TC == shared(U), U)
                        || is(TC == shared const(U), U)
                        || is(TC == immutable(U), U)
                    ) {
                        if (dest !is null) {
                            auto target = cast(Unqual!TC*) dest;
                            *target = *src;
                        }
                    }
                    else {
                        assert(false, T.stringof);
                    }
                }
                return true;
            }
            return false;
        }

        bool isTruthyImpl(T)() pure nothrow @trusted {
            static if(is(T == struct)) {
                return true;
            }
            else static if (is(T == class) || is(T == interface)) {
                return data.length > 0;
            }
            else static if (is(T == bool)) {
                auto d = cast(bool*) data.ptr;
                return *d;
            }
            else static if (isScalarType!T) {
                auto d = cast(T*) data.ptr;
                return (*d) != 0;
            }
            else static if (isArray!T || isAssociativeArray!T) {
                if (data.length <= 0) {
                    return false;
                }
                auto d = cast(size_t[2]*) data.ptr;
                return (*d)[0] > 0;
            }
        }

        final switch (op) {
            case Op.unknown:
                throw new VariantException("Unknown variant operation");

            case Op.getTypeInfo:
                *(cast(TypeInfo*)dest) = typeid(T);
                return true;

            case Op.tryPut:
                static if (is(T == struct)) {
                    if (ty != typeid(T)) {
                        return false;
                    }
                    if (dest !is null) {
                        *(cast(void**) dest) = (cast(void[])data).ptr;
                    }
                    return true;
                }
                else {
                    return tryPut(dest, ty, (cast(void[])data).ptr);
                }

            case Op.isTruthy:
                return isTruthyImpl!(T)();
        }
    }

    // -------------------- constructors --------------------

    this(T)(ref T val) if (is(T == struct)) {
        this._handler = &handler!(T);

        // Since we would be stack-smashing
        // when using the ref directly, we
        // instead allocate an buffer for
        // it here and copy it.
        this._data = new void[T.sizeof];
        *(cast(T*) this._data.ptr) = val;
    }

    this(T)(T val) if (is(T == class) || is(T == interface)) {
        this._handler = &handler!T;

        if (val !is null) {
            this._data = new void[(void*).sizeof];
            *(cast(void**) this._data.ptr) = cast(void*) val;
        }
    }

    this(T)(T val) if (isScalarType!T | isArray!T || isAssociativeArray!T) {
        this._handler = &handler!T;

        this._data = new void[T.sizeof];
        *(cast(T*) this._data.ptr) = val;
    }

    // -------------------- opAssign --------------------

    auto opAssign(Variant var) {
        this._handler = var._handler;
        this._data = var._data;
        return var;
    }

    auto opAssign(T)(ref T val) if (is(T == struct)) {
        this._handler = &handler!T;

        // Since we would be stack-smashing
        // when using the ref directly, we
        // instead allocate an buffer for
        // it here and copy it.
        this._data = new void[T.sizeof];
        *(cast(T*) this._data.ptr) = val;
        return this;
    }

    auto opAssign(T)(T val) if (is(T == class) || is(T == interface)) {
        this._handler = &handler!T;

        if (val !is null) {
            this._data = new void[(void*).sizeof];
            *(cast(void**) this._data.ptr) = cast(void*) val;
        }

        return this;
    }

    auto opAssign(T)(T val) if (isScalarType!T | isArray!T || isAssociativeArray!T) {
        this._handler = &handler!T;

        this._data = new void[T.sizeof];
        *(cast(T*) this._data.ptr) = val;

        return this;
    }

    // -------------------- getters --------------------

    /** 
     * Checks if the current Variant holds a value.
     * 
     * Returns: true if the Variant has a value; false otherwise
     */
    @property bool hasValue() const pure nothrow @safe {
        return this._handler !is null;
    }

    /** 
     * Getter property to recieve the type of the value currently held by the variant.
     * 
     * Returns: The <c>TypeInfo</c> of the value currently held.
     */
    @property const(TypeInfo) type() const @trusted {
        TypeInfo ty = null;
        this._handler(Op.getTypeInfo, cast(void*) &ty, null, null);
        return ty;
    }

    /** 
     * Checks if the variant and it's holded value is truthy.
     * 
     * Returns: true if the variant and it's value is truthy; false otherwise
     */
    @property bool isTruthy() const @trusted {
        if (!this.hasValue) {
            return false;
        }
        return this._handler(Op.isTruthy, null, null, this._data);
    }

    // -------------------- convertsTo --------------------

    /** 
     * Checks if the stored value can be implicitly converted to the type given
     * 
     * Type params:
     *   T = The type to check conversion to
     * Throws: <c>VariantException</c> if the Variant is uninitialized
     * Returns: true if the value can be implicitly converted; false otherwise
     */
    pragma(inline) @property bool convertsTo(T)() const @trusted {
        return this.convertsTo(typeid(T));
    }

    /** 
     * Checks if the stored value can be implicitly converted to the type given
     * 
     * Params:
     *   ty = The type to check conversion to
     * Throws: <c>VariantException</c> if the Variant is uninitialized
     * Returns: true if the value can be implicitly converted; false otherwise
     */
    @property bool convertsTo(TypeInfo ty) const @trusted {
        if (!this.hasValue) {
            throw new VariantException("Cannot use uninitialized Variant");
        }
        return this._handler(Op.tryPut, null, ty, this._data);
    }

    // -------------------- peek --------------------

    /** 
     * Peeks into the current variant and returns a pointer to the value
     * if the **exact** type is contained. Returns a <c>null</c> pointer
     * if either no value is contained or not of the right type.
     * 
     * Returns: A pointer to the value or <c>null</c> if no value is held or the type differs.
     */
    @property T* peek(T)() const @trusted {
        if (!this.hasValue) {
            return null;
        }
        if (this.type != typeid(T)) {
            return null;
        }
        return (cast(T*) this._data.ptr);
    }

    // -------------------- get --------------------

    /** 
     * Tries to return the value held by the Variant.
     * 
     * Throws: A <c>VariantException</c> if either the variant holds no value,
     *         or the requested type is not compatible with the value held.
     * Returns: A reference to the struct
     */
    @property ref T get(T)() const @trusted if (is(T == struct)) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to retrieve value from Variant: holds no data"
            );
        }

        T* ptr = null;
        if (!this._handler(Op.tryPut, cast(void*) &ptr, typeid(T), this._data)) {
            throw new VariantException("Could not retrieve value for specified type");
        }
        return *ptr;
    }

    /** 
     * Tries to return the value held by the Variant.
     * 
     * Throws: A <c>VariantException</c> if either the variant holds no value,
     *         or the requested type is not compatible with the value held.
     * Returns: The class requested
     */
    @property T get(T)() const @trusted if (is(T == class) || is(T == interface)) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to retrieve value from Variant: holds no data"
            );
        }

        if (this._data.length == 0) {
            return null;
        }

        T ptr = null;
        if (!this._handler(Op.tryPut, cast(void*) &ptr, typeid(T), this._data)) {
            throw new VariantException("Could not retrieve value for specified type");
        }
        return ptr;
    }

    /** 
     * Tries to return the value held by the Variant.
     * 
     * Throws: A <c>VariantException</c> if either the variant holds no value,
     *         or the requested type is not compatible with the value held.
     * Returns: The value requested
     */
    @property T get(T)() const @trusted if (isScalarType!T || isArray!T || isAssociativeArray!T) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to retrieve value from Variant: holds no data"
            );
        }

        Unqual!T val;
        if (!this._handler(Op.tryPut, cast(void*)(&val), typeid(T), this._data)) {
            throw new VariantException("Could not retrieve value for specified type");
        }
        return val;
    }

}

/// Test numerics (int)
unittest {
    int i = 12;
    auto v = Variant(i);
    i = 34;

    assert(v.get!int == 12);
    assert(v.get!(const int) == 12);
    assert(v.get!(immutable int) == 12);

    assert(v.peek!int !is null);
    assert(*v.peek!int == 12);

    assert(v.convertsTo!size_t);
    assert(v.get!size_t == 12);

    assert(v.isTruthy);

    v = Variant(0);
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test string
unittest {
    string s = "hello";
    auto v = Variant(s);

    assert(v.get!string == "hello");
    assert(v.get!(const string) == "hello");
    assert(v.get!(immutable string) == "hello");

    assert(v.peek!string !is null);
    assert(*v.peek!string == "hello");

    assert(v.convertsTo!(const char[]));
    assert(v.get!(const char[]) == "hello");

    assert(v.isTruthy);

    v = Variant("");
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test dynamic array
unittest {
    int[] a = [11, 22];
    auto v = Variant(a);

    assert(v.get!(int[]) == [11, 22]);
    assert(v.get!(const(int[])) == [11, 22]);
    assert(v.get!(const(int)[]) == [11, 22]);

    assert(v.peek!(int[]) !is null);
    assert(*v.peek!(int[]) == [11, 22]);

    assert(v.isTruthy);

    a = [];
    v = Variant(a);
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test static array
unittest {
    int[2] a = [11, 22];
    auto v = Variant(a);

    assert(v.get!(int[2]) == [11, 22]);
    assert(v.get!(const(int[2])) == [11, 22]);
    assert(v.get!(const(int)[2]) == [11, 22]);

    assert(v.peek!(int[2]) !is null);
    assert(*v.peek!(int[2]) == [11, 22]);

    assert(v.isTruthy);

    int[0] b;
    v = Variant(b);
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test associative array
unittest {
    int[string] a = [ "a": 11, "b": 22 ];
    auto v = Variant(a);

    assert(v.get!(int[string]) == [ "a": 11, "b": 22 ]);
    assert(v.get!(const(int[string])) == cast(const(int[string])) [ "a": 11, "b": 22 ]);

    assert(v.peek!(int[string]) !is null);
    assert(*v.peek!(int[string]) == [ "a": 11, "b": 22 ]);

    assert(v.isTruthy);

    int[string] b;
    v = Variant(b);
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test struct
unittest {
    struct S { int i; }
    S s = S(42);
    auto v = Variant(s);
    s.i = 0;

    assert(v.get!S == S(42));

    assert(v.peek!S !is null);
    assert(*v.peek!S == S(42));

    assert(v.isTruthy);
}

/// Test class
unittest {
    class C {
        int i;
        this(int i) {
            this.i = i;
        }
    }
    C c = new C(42);
    auto v = Variant(c);

    assert(v.get!C is c);
    assert(v.get!(const C) is c);
    assert(v.get!(immutable C) is c);

    assert(v.peek!C !is null);
    assert(*v.peek!C is c);

    assert(v.isTruthy);

    c = null;
    v = Variant(c);
    assert(v.get!C is null);
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test class as interface
unittest {
    interface I {}
    class C : I {}
    C c = new C();
    I i = cast(I) c;

    auto v = Variant(c);
    assert(v.hasValue);

    assert(v.get!I is i);
    assert(v.get!(const I) is i);

    assert(v.peek!I is null);

    assert(v.isTruthy);
}

/// Test interface
unittest {
    interface I {}
    class C : I {}
    C c = new C();
    I i = cast(I) c;

    auto v = Variant(i);
    assert(v.hasValue);

    assert(v.get!I is i);
    assert(v.get!(const I) is i);

    assert(v.peek!I !is null);
    assert(*v.peek!I is i);

    assert(v.isTruthy);

    i = null;
    v = Variant(i);
    assert(v.get!I is null);
    assert(v.hasValue);
    assert(!v.isTruthy);
}

/// Test assign
unittest {
    int i = 42;
    auto v = Variant(i);

    int j = 33;
    v = j;
}
