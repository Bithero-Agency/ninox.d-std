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
 * Authors:   $(HTTP codearq.net/mai-lapyst, Mai-Lapyst)
 */
module ninox.std.variant;

import std.meta;
import std.traits;
import core.exception : RangeError;

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
        bool function(Op op, void* dest, void* arg, const void[] data) _handler;
    }

    // -------------------- handler implementations --------------------

    private enum Op {
        unknown,
        getTypeInfo,
        tryPut,
        isTruthy,
        lookupMember,
        toStr,
        call,
        isCallable,
        iterate,
        index,
        equals,
        cmp,
        length,
    }

    private static bool handler(T)(Op op, void* dest, void* arg, const void[] data) {

        bool tryPut(void* dest, TypeInfo ty, void* data, bool noRef = false) {
            alias UT = Unqual!T;

            static if (is(T == struct)) {
                alias MutTypes = AliasSeq!(UT);
            }
            else {
                alias MutTypes = AliasSeq!(UT, AllImplicitConversionTargets!UT);
            }

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
                else static if (is(T == struct)) {
                    if (dest !is null) {
                        if (noRef) {
                            *(cast(Unqual!TC*) dest) = *(cast(UT*) data);
                        } else {
                            *(cast(Unqual!TC**) dest) = cast(UT*) data;
                        }
                    }
                }
                else static if (isFunctionPointer!T || isDelegate!T || isPointer!T) {
                    if (dest !is null) {
                        *(cast(T*) dest) = *(cast(T*) data);
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
            else static if (isFunctionPointer!T || isDelegate!T || isPointer!T) {
                auto d = cast(T*) data.ptr;
                return (*d) !is null;
            }
        }

        version (ninox_std_variant_lookupMember) {
            static if (is(T == class) || is(T == struct) || is(T == interface)) {
                bool lookupMember(T)(Variant* dest, string name, void* data) {
                    static if (is(T == struct)) {
                        T* src = cast(T*) data;
                    }
                    else {
                        T src = *(cast(T*) data);
                    }

                    static foreach (memberName; __traits(derivedMembers, T)) {
                        static if (__traits(compiles, mixin("T." ~ memberName))) {
                            if (name == memberName) {
                                static if (isFunction!(mixin("T." ~ memberName))) {
                                    *dest = Variant(mixin("&(src." ~ memberName ~ ")"));
                                }
                                else {
                                    *dest = Variant(mixin("src." ~ memberName));
                                }
                                return true;
                            }
                        }
                    }

                    static if (is(T == class)) {
                        alias baseClasses = BaseClassesTuple!T;
                        static if (baseClasses.length > 1 && !is(baseClasses[0] == Object)) {
                            auto base_data = cast(baseClasses[0]) src;
                            return lookupMember!(baseClasses[0])(dest, name, &base_data);
                        }
                    }
                    else static if (is(T == struct)) {
                        alias aliasThis = __traits(getAliasThis, T);
                        static if (aliasThis.length == 1) {
                            alias baseTy = typeof(mixin("T." ~ aliasThis[0]));
                            static if (isPointer!baseTy) {
                                auto base_data = mixin("src." ~ aliasThis[0]);
                                return lookupMember!(PointerTarget!baseTy)(dest, name, base_data);
                            }
                            else {
                                auto base_data = mixin("&(src." ~ aliasThis[0] ~ ")");
                                return lookupMember!(baseTy)(dest, name, base_data);
                            }
                        }
                        else static if (aliasThis.length >= 2) {
                            static assert(0, "A struct with 2 or more 'alias this' is not supported.");
                        }
                    }
                    return false;
                }
            }
        }

        bool cmp(T* src, T* rhs, Op op, void* dest) {
            if (op == Op.equals) {
                return (*rhs == *src);
            } else {
                if (*rhs == *src) {
                    *(cast(int*) dest) = 0;
                    return true;
                }

                static if (is(typeof(*src < *rhs))) {
                    *(cast(int*) dest) = (*src < *rhs) ? -1 : 1;
                    return true;
                }
                else {
                    return false;
                }
            }
        }

        import std.traits : isCallable;
        import ninox.std.traits : isIndexable;

        final switch (op) {
            case Op.unknown:
                throw new VariantException("Unknown variant operation");

            case Op.getTypeInfo:
                *(cast(TypeInfo*)dest) = typeid(T);
                return true;

            case Op.tryPut:
                TypeInfo ty = cast(TypeInfo) arg;
                return tryPut(dest, ty, (cast(void[])data).ptr);

            case Op.isTruthy:
                return isTruthyImpl!(T)();

            case Op.lookupMember:
                version (ninox_std_variant_lookupMember) {
                    static if (is(T == Variant)) {
                        Variant* src = cast(Variant*) (cast(void[])data).ptr;
                        return (*src)._handler(Op.lookupMember, dest, arg, (*src)._data);
                    } else static if (is(T == class) || is(T == struct) || is(T == interface)) {
                        string name = *(cast(string*) arg);
                        return lookupMember!(Unqual!T)(cast(Variant*) dest, name, (cast(void[])data).ptr);
                    } else {
                        return false;
                    }
                }
                else {
                    return false;
                }

            case Op.toStr:
                import std.conv : to;
                static if (
                    is(T == struct)
                    || is(T == class) || is(T == interface)
                    || isArray!T || isAssociativeArray!T
                    || isScalarType!T
                ) {
                    T* src = cast(T*) (cast(void[])data).ptr;
                    *(cast(string*) dest) = (*src).to!string;
                    return true;
                } else static if (isFunctionPointer!T || isDelegate!T || isPointer!T) {
                    void** src = cast(void**) (cast(void[])data).ptr;
                    *(cast(string*) dest) = (*src).to!string;
                    return true;
                } else {
                    return false;
                }

            case Op.call:
                static if (isFunctionPointer!T || isDelegate!T || isCallable!T) {
                    T* src = cast(T*) (cast(void[])data).ptr;
                    Variant[] params = *(cast(Variant[]*) arg);

                    alias ParamTypes = Parameters!T;

                    import std.typecons : Tuple;
                    Tuple!(staticMap!(Unqual, ParamTypes)) raw_args;

                    static if (variadicFunctionStyle!T == Variadic.typesafe) {
                        foreach (i, PT; ParamTypes[0..$-1]) {
                            raw_args[i] = cast() params[i].get!PT;
                        }

                        alias VariadicTy = typeof( ParamTypes[$-1].init[0] );
                        enum nonVariadicParamsCount = ParamTypes.length - 1;
                        VariadicTy[] variadicArgs;
                        for (auto i = nonVariadicParamsCount; i < params.length; i++) {
                            variadicArgs ~= cast() params[i].get!VariadicTy;
                        }
                        raw_args[nonVariadicParamsCount] = variadicArgs;
                    }
                    else {
                        foreach (i, PT; ParamTypes) {
                            raw_args[i] = cast() params[i].get!PT;
                        }
                    }

                    auto args = cast(Tuple!(ParamTypes)) raw_args;
                    static if (is(ReturnType!T == void)) {
                        (*src)(args.expand);
                        *(cast(Variant*) dest) = Variant();
                    }
                    else {
                        *(cast(Variant*) dest) = Variant((*src)(args.expand));
                    }
                    return true;
                }
                else {
                    return false;
                }

            case Op.isCallable:
                static if (isFunctionPointer!T || isDelegate!T || isCallable!T) {
                    return true;
                }
                else {
                    return false;
                }

            case Op.iterate:
                auto dg = *(cast(int delegate(ref Variant, ref Variant)*) arg);
                static if (isArray!T || isAssociativeArray!T) {
                    T* src = cast(T*) (cast(void[])data).ptr;
                    foreach (ref idx, ref elem; *src) {
                        auto _idx = Variant(idx);
                        auto _elem = Variant(elem);
                        if (dg(_idx, _elem)) break;
                    }
                    return true;
                }
                else {
                    return false;
                }

            case Op.index: {
                T* src = cast(T*) (cast(void[])data).ptr;
                if (src is null) {
                    static if (isArray!T || isAssociativeArray!T || isIndexable!T) {
                        return true;
                    } else {
                        return false;
                    }
                }

                Variant[] params = *(cast(Variant[]*) arg);
                static if (isArray!T) {
                    if (params.length != 1) {
                        import std.conv : to;
                        throw new VariantException(
                            "Mismatching count of parameters; expected 1 but got " ~ params.length.to!string
                        );
                    }
                    *(cast(Variant*) dest) = Variant( (*src)[ params[0].get!size_t ] );
                    return true;
                } 
                else static if (isAssociativeArray!T) {
                    if (params.length != 1) {
                        import std.conv : to;
                        throw new VariantException(
                            "Mismatching count of parameters; expected 1 but got " ~ params.length.to!string
                        );
                    }
                    *(cast(Variant*) dest) = Variant( (*src)[ params[0].get!(KeyType!T) ] );
                    return true;
                }
                else static if (is(T == Variant)) {
                    return (*src)._handler(Op.index, dest, arg, (*src)._data);
                }
                else static if (isIndexable!T) {
                    alias OpIndexTy = typeof( __traits(getMember, T, "opIndex") );
                    alias ParamTypes = Parameters!OpIndexTy;

                    import std.typecons : Tuple;
                    Tuple!(staticMap!(Unqual, ParamTypes)) raw_args;
                    static if (variadicFunctionStyle!OpIndexTy == Variadic.typesafe) {
                        foreach (i, PT; ParamTypes[0..$-1]) {
                            raw_args[i] = cast() params[i].get!PT;
                        }
                        alias VariadicTy = typeof( ParamTypes[$-1].init[0] );
                        enum nonVariadicParamsCount = ParamTypes.length - 1;
                        VariadicTy[] variadicArgs;
                        for (auto i = nonVariadicParamsCount; i < params.length; i++) {
                            variadicArgs ~= cast() params[i].get!VariadicTy;
                        }
                        raw_args[nonVariadicParamsCount] = variadicArgs;
                    }
                    else {
                        foreach (i, PT; ParamTypes) {
                            raw_args[i] = cast() params[i].get!PT;
                        }
                    }

                    auto args = cast(Tuple!(ParamTypes)) raw_args;
                    static if (is(ReturnType!OpIndexTy == void)) {
                        (*src)[args.expand];
                        *(cast(Variant*) dest) = Variant();
                    }
                    else {
                        *(cast(Variant*) dest) = Variant((*src)[args.expand]);
                    }
                    return true;
                }
                else {
                    return false;
                }
            }

            case Op.cmp:
            case Op.equals:
                auto other = cast(Variant*) arg;
                auto otherTy = other.type;

                // For all direct types
                if (otherTy == typeid(T)) {
                    T* src = cast(T*) data.ptr;
                    T* rhs = cast(T*) other._data.ptr;
                    return cmp(src, rhs, op, dest);
                }

                // Try to convert this to other...
                Variant temp;
                temp._data = new void[ other._data.length ];
                if (tryPut(cast(void*) temp._data.ptr, cast(TypeInfo) otherTy, (cast(void[])data).ptr, true)) {
                    temp._handler = other._handler;
                    if (op == Op.equals) {
                        return temp.opEquals(*other);
                    } else {
                        *(cast(int*) dest) = temp.opCmp(*other);
                        return true;
                    }
                }

                // Try converting other to this...
                temp._data = new void[ data.length ];
                if (
                    //tryPut(cast(void*) temp._data.ptr, typeid(T), other._data.ptr, true)
                    other._handler(Op.tryPut, temp._data.ptr, cast(void*) typeid(T), cast(const void[]) other._data)
                ) {
                    T* src = cast(T*) data.ptr;
                    static if (is(T == struct)) {
                        T* rhs = *(cast(T**) temp._data.ptr);
                    } else {
                        T* rhs = cast(T*) temp._data.ptr;
                    }
                    return cmp(src, rhs, op, dest);
                }

                return false;

            case Op.length:
                static if (isArray!T || isAssociativeArray!T) {
                    T* src = cast(T*) data.ptr;
                    *(cast(ulong*) dest) = src.length;
                    return true;
                }
                else static if (
                    __traits(hasMember, T, "length")
                    && __traits(compiles, &T.length)
                    && isNumeric!(typeof(T.length))
                ) {
                    T* src = cast(T*) data.ptr;
                    *(cast(ulong*) dest) = src.length;
                    return true;
                }
                else {
                    return false;
                }
        }
    }

    // -------------------- constructors --------------------

    this(Variant var) {
        this._handler = var._handler;
        this._data = var._data;
    }

    this(T)(ref T val) if (is(T == struct)) {
        this._handler = &handler!(T);

        // Since we would be stack-smashing
        // when using the ref directly, we
        // instead allocate an buffer for
        // it here and copy it.
        this._data = new void[T.sizeof];
        *(cast(Unqual!T*) this._data.ptr) = val;
    }

    this(T)(T val) if (is(T == struct)) {
        this._handler = &handler!(T);

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

    this(T)(T val) if (isScalarType!T || isArray!T || isAssociativeArray!T) {
        this._handler = &handler!T;

        this._data = new void[T.sizeof];
        *(cast(Unqual!T*) this._data.ptr) = val;
    }

    this(T)(T val) if (isFunctionPointer!T || isDelegate!T || isPointer!T) {
        this._handler = &handler!T;

        if (val !is null) {
            this._data = new void[T.sizeof];
            *(cast(T*) this._data.ptr) = val;
        }
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

    auto opAssign(T)(T val) if (is(T == struct)) {
        this._handler = &handler!(T);

        this._data = new void[T.sizeof];
        *(cast(T*) this._data.ptr) = val;

        return this;
    }

    auto opAssign(T)(T val) if (is(T == class) || is(T == interface)) {
        this._handler = &handler!T;
        this._data = [];

        if (val !is null) {
            this._data = new void[(void*).sizeof];
            *(cast(void**) this._data.ptr) = cast(void*) val;
        }

        return this;
    }

    auto opAssign(T)(T val) if (isScalarType!T || isArray!T || isAssociativeArray!T) {
        this._handler = &handler!T;

        this._data = new void[T.sizeof];
        *(cast(Unqual!T*) this._data.ptr) = val;

        return this;
    }

    auto opAssign(T)(T val) if (isFunctionPointer!T || isDelegate!T || isPointer!T) {
        this._handler = &handler!T;
        this._data = [];

        if (val !is null) {
            this._data = new void[T.sizeof];
            *(cast(T*) this._data.ptr) = val;
        }

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
        return this._handler(Op.tryPut, null, cast(void*) ty, this._data);
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
        if (!this._handler(Op.tryPut, cast(void*) &ptr, cast(void*) typeid(T), this._data)) {
            import std.conv : to;
            throw new VariantException("Could not retrieve value for specified type: " ~ this.type.to!string ~ " != " ~ typeid(T).to!string);
        }
        return *ptr;
    }

    /** 
     * Tries to return the value held by the Variant.
     * 
     * Throws: A <c>VariantException</c> if either the variant holds no value,
     *         or the requested type is not compatible with the value held.
     * Returns: The class, interface, function or delegate requested
     */
    @property T get(T)() const @trusted if (is(T == class) || is(T == interface) || isFunctionPointer!T || isDelegate!T || isPointer!T) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to retrieve value from Variant: holds no data"
            );
        }

        if (this._data.length == 0) {
            return null;
        }

        T ptr = null;
        if (!this._handler(Op.tryPut, cast(void*) &ptr, cast(void*) typeid(T), this._data)) {
            import std.conv : to;
            throw new VariantException("Could not retrieve value for specified type: " ~ this.type.to!string ~ " != " ~ typeid(T).to!string);
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
        if (!this._handler(Op.tryPut, cast(void*)(&val), cast(void*) typeid(T), this._data)) {
            import std.conv : to;
            throw new VariantException("Could not retrieve value for specified type: " ~ this.type.to!string ~ " != " ~ typeid(T).to!string);
        }
        return val;
    }

    // -------------------- lookupMember --------------------

    @property Variant lookupMember(string s) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to lookup member on Variant: holds no data"
            );
        }

        version (ninox_std_variant_lookupMember) {
            Variant ret;
            if (!this._handler(Op.lookupMember, cast(void*) &ret, cast(void*) &s, this._data)) {
                throw new VariantException(
                    "Unable to lookup member on Variant: holds not a struct, class or interface or member is not known"
                );
            }
            return ret;
        }
        else {
            throw new VariantException("Cannot lookup member on Variant: feature is not enabled");
        }
    }

    // -------------------- toString --------------------

    @property string toString() const {
        string str;
        this._handler(Op.toStr, cast(void*) &str, null, this._data);
        return str;
    }

    // -------------------- opCall --------------------

    Variant opCall(P...)(P params) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute opCall on Variant: holds no data"
            );
        }

        Variant[] var_params;
        foreach (ref param; params) {
            var_params ~= Variant(param);
        }

        Variant ret;
        if (!this._handler(Op.call, cast(void*) &ret, cast(void*) &var_params, this._data)) {
            throw new VariantException(
                "Failed to execute opCall on Variant: holds no callable value"
            );
        }
        return ret;
    }

    Variant doCall(Variant[] params = []) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute doCall on Variant: holds no data"
            );
        }

        Variant ret;
        if (!this._handler(Op.call, cast(void*) &ret, cast(void*) &params, this._data)) {
            throw new VariantException(
                "Failed to execute doCall on Variant: holds no callable value"
            );
        }
        return ret;
    }

    @property bool isCallable() const {
        return this._handler(Op.isCallable, null, null, null);
    }

    // -------------------- iterateable --------------------

    void iterateOver(scope int delegate(ref Variant, ref Variant) dg) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute iterateOver on Variant: holds no data"
            );
        }

        if (!this._handler(Op.iterate, null, cast(void*) &dg, this._data)) {
            throw new VariantException(
                "Unable to execute iterateOver on Variant: value does not support this"
            );
        }
    }

    // -------------------- indexable --------------------

    Variant opIndex(P...)(P params) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute opIndex on Variant: holds no data"
            );
        }

        Variant[] var_params;
        foreach (ref param; params) {
            var_params ~= Variant(param);
        }

        Variant ret;
        if (!this._handler(Op.index, cast(void*) &ret, cast(void*) &var_params, this._data)) {
            throw new VariantException(
                "Failed to execute opIndex on Variant: holds no indexable value"
            );
        }
        return ret;
    }

    Variant doIndex(Variant[] params...) {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute opIndex on Variant: holds no data"
            );
        }

        Variant ret;
        if (!this._handler(Op.index, cast(void*) &ret, cast(void*) &params, this._data)) {
            throw new VariantException(
                "Failed to execute opIndex on Variant: holds no indexable value"
            );
        }
        return ret;
    }

    @property bool isIndexable() const {
        return this._handler(Op.index, null, null, null);
    }

    @property size_t length() const {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to get length from Variant: holds no data"
            );
        }

        size_t ret;
        if (!this._handler(Op.length, cast(void*) &ret, null, this._data)) {
            throw new VariantException(
                "Unable to get length from Variant: value does not support this operation"
            );
        }
        return ret;
    }

    // -------------------- comparison --------------------

    bool opEquals(T)(T other) const {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute opEquals on Variant: holds no data"
            );
        }

        static if (is(T == Variant)) {
            alias arg = other;
        }
        else {
            auto arg = Variant(other);
        }
        return this._handler(Op.equals, null, cast(void*) &arg, this._data);
    }

    int opCmp(T)(const T other) const {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute opCmp on Variant: holds no data"
            );
        }

        static if (is(T == Variant)) {
            alias arg = other;
        }
        else {
            auto arg = Variant(other);
        }

        int res;
        if (!this._handler(Op.cmp, cast(void*) &res, cast(void*) &arg, this._data)) {
            import std.conv : to;
            throw new VariantException(
                "Unable to execute opCmp on Variant: cannot compare "
                    ~ this.type.to!string ~ " with " ~ typeid(T).to!string
            );
        }
        return res;
    }

    // -------------------- binary operators --------------------

    Variant opBinaryRight(string op, T)(T lhs) if (op == "in") {
        if (!this.hasValue) {
            throw new VariantException(
                "Unable to execute 'X in Y' on Variant: holds no data"
            );
        }

        Variant[] var_params = [ Variant(lhs) ];
        Variant ret;
        try {
            this._handler(Op.index, cast(void*) &ret, cast(void*) &var_params, this._data);
        } catch (RangeError) {}
        return ret;
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

/// Test const numeric & not possible to cast const-ness away
unittest {
    const int j = 56;
    auto v = Variant(j);

    assert(v.hasValue);
    assert(v.isTruthy);

    assert(v.get!(const int) == 56);

    try {
        v.get!int;
        assert(0);
    }
    catch (VariantException e) {
        assert(e.message == "Could not retrieve value for specified type: const(int) != int");
    }
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

    assert(v.get!(const S) == S(42));
}

/// Test const struct & not possible to cast const-ness away
unittest {
    struct S { int i; }
    const S s = S(42);

    auto v = Variant(s);
    assert(v.hasValue);
    assert(v.get!(const S) == S(42));

    try {
        v.get!S;
        assert(0);
    } catch (VariantException e) {
        import std.string : startsWith;
        assert(e.message.startsWith("Could not retrieve value for specified type"));
    }
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

/// Test const class & not possible to cast const-ness away
unittest {
    class C {}
    const C c = new C();

    auto v = Variant(c);
    assert(v.hasValue);

    assert(v.get!(const C) == c);

    try {
        v.get!C;
        assert(0);
    } catch (VariantException e) {
        import std.string : startsWith;
        assert(e.message.startsWith("Could not retrieve value for specified type"));
    }
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

/// Test const class as interface & not possible to cast const-ness away
unittest {
    interface I {}
    class C : I {}
    const C c = new C();
    const I i = cast(I) c;

    auto v = Variant(c);
    assert(v.hasValue);

    assert(v.get!(const I) is i);

    try {
        v.get!I;
        assert(0);
    } catch (VariantException e) {
        import std.string : startsWith;
        assert(e.message.startsWith("Could not retrieve value for specified type"));
    }
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

/// Test const interface & not possible to cast const-ness away
unittest {
    interface I {}
    class C : I {}
    C c = new C();
    const I i = cast(I) c;

    auto v = Variant(i);
    assert(v.hasValue);

    assert(v.get!(const I) == i);

    try {
        v.get!I;
        assert(0);
    } catch (VariantException e) {
        import std.string : startsWith;
        assert(e.message.startsWith("Could not retrieve value for specified type"));
    }
}

/// Test assign
unittest {
    int i = 42;
    auto v = Variant(i);

    int j = 33;
    v = j;
}

/// Test function
unittest {
    auto fn = (ref int i) { i = 42; };

    auto v = Variant(fn);
    assert(v.hasValue);
    assert(v.isTruthy);

    alias FN = void function(ref int i) pure nothrow @nogc @safe;

    assert(v.get!FN == fn);

    int i = 0;
    assert(i == 0);
    v.get!FN()(i);
    assert(i == 42);

    assert(v.peek!FN !is null);
    assert(*(v.peek!FN) == fn);

    assert(v.get!(const FN) == fn);
}

/// Test delegate
unittest {
    int i = 0;
    void doSome() {
        i = 42;
    }

    auto v = Variant(&doSome);
    assert(v.hasValue);
    assert(v.isTruthy);

    alias DG = void delegate() pure nothrow @nogc @safe;

    assert(v.get!DG == &doSome);

    assert(i == 0);
    v.get!DG()();
    assert(i == 42);

    assert(v.peek!DG !is null);
    assert(*(v.peek!DG) == &doSome);

    assert(v.get!(const DG) == &doSome);
}

/// Test pointer to struct
unittest {
    struct S {}
    auto s = S();
    auto v = Variant(&s);

    assert(v.isTruthy);
    assert(v.get!(S*) == &s);

    assert(v.get!(const S*) == &s);
}

/// Test lookupMember on struct
unittest {
    struct S {
        int i;

        this(int i) {
            this.i = i;
        }

        void doSome() {
            this.i *= 2;
        }
    }
    S s = S(42);
    auto v = Variant(s);

    auto i = v.lookupMember("i");
    assert(i.hasValue);
    assert(i.type == typeid(int));
    assert(i.get!int == 42);

    auto doSome = v.lookupMember("doSome");
    assert(doSome.hasValue);

    alias DG = void delegate();

    assert(s.i == 42);
    doSome.get!DG()();
    assert(v.get!S.i == 84);
}

/// Test lookupMember on class
unittest {
    class C {
        int i;

        this(int i) {
            this.i = i;
        }

        void doSome() {
            this.i *= 2;
        }
    }
    auto c = new C(42);
    auto v = Variant(c);

    auto i = v.lookupMember("i");
    assert(i.hasValue);
    assert(i.type == typeid(int));
    assert(i.get!int == 42);

    auto doSome = v.lookupMember("doSome");
    assert(doSome.hasValue);

    alias DG = void delegate();

    assert(doSome.get!DG == &(c.doSome));
    assert(c.i == 42);
    doSome.get!DG()();
    assert(c.i == 84);
}

/// Test lookupMember on interface
unittest {
    interface I {
        void doSome();
    }
    class C : I {
        int i;

        this(int i) {
            this.i = i;
        }

        void doSome() {
            this.i *= 2;
        }
    }
    auto c = new C(42);
    I i = c;
    auto v = Variant(i);

    auto doSome = v.lookupMember("doSome");
    assert(doSome.hasValue);

    alias DG = void delegate();

    assert(c.i == 42);
    doSome.get!DG()();
    assert(c.i == 84);
}

/// Test lookupMember on struct with alias this
unittest {
    struct B {
        int i;
    }
    struct S {
        B* b;
        alias b this;
    }
    B b = B(42);
    S s = S(&b);
    auto v = Variant(s);

    auto i = v.lookupMember("i");
    assert(i.hasValue);
    assert(i.type == typeid(int));
    assert(i.get!int == 42);
}

/// Test lookupMember on class with parent
unittest {
    class B {
        int i;
    }
    class C : B {}

    auto c = new C();
    c.i = 42;
    auto v = Variant(c);

    auto i = v.lookupMember("i");
    assert(i.hasValue);
    assert(i.get!int == 42);
}

/// Test lookupMember on interface with parent
unittest {
    interface I {
        void doSome();
    }
    interface I2 : I {}
    class C : I2 {
        int i = 0;

        void doSome() {
            this.i = 42;
        }
    }

    auto c = new C();
    auto v = Variant(c);

    auto doSome = v.lookupMember("doSome");
    assert(doSome.hasValue);

    alias DG = void delegate();
    assert(doSome.get!DG == &(c.doSome));

    assert(c.i == 0);
    doSome.get!DG()();
    assert(c.i == 42);
}

/// Test toString
unittest {
    import std.conv : to;
    import std.stdio;

    assert(Variant(1).toString == "1");
    assert(Variant(true).toString == "true");
    assert(Variant("hello").toString == "hello");

    assert(Variant([ 11, 22 ]).toString == "[11, 22]");
    assert(Variant(cast(int[2]) [ 11, 22 ]).toString == "[11, 22]");
    assert(Variant([ "a": 1, "b": 2 ]).toString == "[\"b\":2, \"a\":1]");

    struct S1 { int i = 42; }
    assert(Variant(S1()).toString == "S1(42)");

    struct S2 {
        string toString() const @safe pure nothrow {
            return "abc";
        }
    }
    assert(Variant(S2()).toString == "abc");

    auto fn = () {};
    assert(Variant(fn).toString == fn.to!string);

    class C1 {}
    import std.string : startsWith, endsWith;
    assert(Variant(new C1()).toString.startsWith("ninox.std.variant.__unittest_L"));
    assert(Variant(new C1()).toString.endsWith("_C1.C1"));

    class C2 {
        override string toString() const @safe pure nothrow {
            return "def";
        }
    }
    assert(Variant(new C2()).toString == "def");
}

/// Test opCall
unittest {
    auto fn1 = () { return 42; };
    auto v = Variant(fn1);
    assert(v().get!int == 42);
    assert(v.doCall().get!int == 42);

    auto fn2 = (int i) { return i * 2; };
    v = Variant(fn2);
    assert(v(12).get!int == 24);
    assert(v.doCall([ Variant(12) ]).get!int == 24);

    // Currently ref's aren't correctly forwarded
    auto fn3 = (ref int i) { i *= 2; };
    v = Variant(fn3);
    int i = 5; v(i);
    assert(i != 10);

    struct S {
        int i;
        void doSome() {
            this.i *= 2;
        }
    }
    auto s = S(5);
    v = Variant(&(s.doSome));
    v();
    assert(s.i == 10);

    class C {
        auto opCall() {
            return 42;
        }
    }
    v = Variant(new C());
    assert(v().get!int == 42);
    assert(v.doCall().get!int == 42);

    struct S2 {
        auto opCall(int i) {
            return i * 2;
        }
    }
    S2 s2;
    v = Variant(s2);
    assert(v(12).get!int == 24);
    assert(v.doCall([ Variant(12) ]).get!int == 24);

    v = Variant((int[] args...) {
        return args.length;
    });
    assert(v(1, 2, 3).get!long == 3);
}

/// Test opIndex
unittest {
    auto v = Variant([11, 22]);
    assert(v.isIndexable);
    assert(v[1].get!int == 22);
    assert(v.doIndex(Variant(1)).get!int == 22);

    v = Variant([ "a": 1, "b": 2 ]);
    assert(v.isIndexable);
    assert(v["b"].get!int == 2);
    assert(v.doIndex([ Variant("b") ]).get!int == 2);

    struct S {
        int opIndex(int i) {
            return i * 2;
        }
    }
    v = Variant(S());
    assert(v.isIndexable);
    assert(v[12].get!int == 24);
    assert(v.doIndex(Variant(12)).get!int == 24);
}

/// Test opEqual
unittest {
    auto v = Variant(11);
    assert(v == 11);

    v = Variant(cast(const size_t) 22);
    assert(v == 22);

    struct S1 { int i; }
    v = Variant(S1(42));
    assert(v == S1(42));

    const S1 s = S1(42);
    v = Variant(s);
    assert(v == S1(42));

    auto fn1 = () { return 42; };
    v = Variant(fn1);
    assert(v == fn1);
}

/// Test opCmp
unittest {
    auto v = Variant(11);
    assert (v > 10);
    assert (v < 12);
    assert (v >= 11);
}

/// Test `X in Y`
unittest {
    auto v = Variant([ "a": 11 ]);
    auto v2 = "a" in v;
    assert(v2.hasValue);
    assert(v2.get!int == 11);

    v2 = "b" in v;
    assert(!v2.hasValue);
}

/// Test `.length`
unittest {
    auto v = Variant([11, 22]);
    assert(v.length == 2);

    v = Variant([ "a": 11 ]);
    assert(v.length == 1);

    struct S1 {
        @property size_t length() => 42;
    }
    v = Variant(S1());
    assert(v.length == 42);
}
