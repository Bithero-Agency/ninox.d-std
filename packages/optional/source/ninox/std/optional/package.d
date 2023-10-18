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
 * Module to provide optionals for dlang.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.std.optional;

import std.traits : isCallable, Parameters, ReturnType, isInstanceOf;
import std.meta : AliasSeq;

/// Exception when an Optional is None but a operation that assumes an Some was executed
class OptionalIsNoneException : Exception {
    this (string s, string op) {
        super("Optional " ~ s ~ " is none; operation " ~ op ~ " not permitted");
    }
}

/// ditto
alias OptionIsNoneException = OptionalIsNoneException;

/// An optional of type `T`
struct Optional(T) {
    private T value;
    private bool _isSome = false;

    this(T value, bool isSome) @disable;

    private this(T value) {
        this.value = value;
        this._isSome = true;
    }

    /**
     * Takes the value out of the optional, leaving a None in it's place
     * 
     * Returns: the value the optional holds
     * 
     * Throws: $(REF OptionalIsNoneException) if the optional is a None instead of a Some
     */
    T take() {
        if (!_isSome) {
            throw new OptionalIsNoneException(.stringof, ".take()");
        }
        this._isSome = false;
        return value;
    }

    /** 
     * Gets the value of the optional but leaving it as it.
     * 
     * Returns: the value the optional holds
     * 
     * Throws: $(REF OptionalIsNoneException) if the optional is a None instead of a Some
     */
    T get() {
        if (!_isSome) {
            throw new OptionalIsNoneException(.stringof, ".take()");
        }
        return value;
    }

    /// Returns true if the optional is a None; false otherwise
    bool isNone() {
        return !_isSome;
    }

    /// Returns true if the optional is a Some; false otherwise
    bool isSome() {
        return _isSome;
    }

    /// Maps this optional to another optional of `U`
    /// 
    /// Parameter `f` needs to be a callable that accepts one parameter: `T`,
    /// and produces one return `U`.
    /// 
    /// If this optional is a Some, then the function is called with the current value,
    /// and the return is wrapped into a new Some of the destination type before returned
    /// from this function as well.
    /// 
    /// If this optional is a None, a none of the destination type is returned.
    Optional!U map(F, U = ReturnType!F)(F f)
    if (isCallable!F && is(Parameters!F == AliasSeq!(T)))
    {
        if (_isSome) {
            return Optional!U.some(f(value));
        } else {
            return Optional!U.none();
        }
    }

    /// Maps the optional to another optional of `U`, with a default value.
    /// 
    /// Parameter `f` needs to be a callable that accepts one parameter: `T`,
    /// and produces one return `U`.
    /// 
    /// If this optional is a Some, then the function is called with the current value,
    /// and the return is wrapped into a new Some of the destination type before returned
    /// from this function as well.
    /// 
    /// If this optional is a None, a some of the destination type with the value of `_default`
    /// is returned instead.
    Optional!U map_or(F, U = ReturnType!F)(U _default, F f)
    if (isCallable!F && is(Parameters!F == AliasSeq!(T)))
    {
        if (_isSome) {
            return Optional!U.some(f(value));
        } else {
            return Optional!U.some(_default);
        }
    }

    /// If this is a some, the given callable `f` is called and it's
    /// return (another optional of `U`) is returned.
    /// 
    /// If this is a none, a new none of the type `U` is returned instead.
    R and_then(F, R = ReturnType!F)(F f)
    if (isCallable!F && is(Parameters!F == AliasSeq!(T)) && is(R == Optional!U, U))
    {
        if (_isSome) {
            return f(value);
        } else {
            static if (is(R == Optional!U, U)) {
                return Optional!U.none();
            } else {
                static assert(0, "Should not happen!");
            }
        }
    }

    /**
     * Creates a None
     * 
     * Returns: A optional which is a None
     */
    static Optional none() {
        return Optional();
    }

    /**
     * Creates a Some
     * 
     * Params:
     *  value = the value to use for the Some
     * 
     * Returns: A optional which is a Some and holds the given value
     */
    static Optional some(T value) {
        return Optional(value);
    }
}

/// ditto
alias Option = Optional;

/// Returns true if `T` is a `Optional`
enum isOptional(T) = isInstanceOf!(Optional, T);

unittest {
    Optional!int maybe_int = Optional!int.none();
    try {
        maybe_int.take();
        assert(0, "Optional.take() should throw a OptionalIsNoneException if it is a None");
    } catch (OptionalIsNoneException) {}
}

unittest {
    Optional!int maybe_int = Optional!int.some(42);
    try {
        auto i = maybe_int.take();
        assert(i == 42, "Optional.take() should return the value hold by the Some");
        assert(maybe_int.isNone(), "Optional should be a None after call to Optional.take()");
    } catch (OptionalIsNoneException) {
        assert(0, "Optional.take() should not throw a OptionalIsNoneException if it is a Some");
    }
}

unittest {
    Optional!int maybe_int = Optional!int.none();
    Optional!string maybe_str = maybe_int.map((int i) {
        import std.conv : to;
        return to!string(i);
    });
    assert(maybe_str.isNone());
}

unittest {
    Optional!int maybe_int = Optional!int.some(42);
    Optional!string maybe_str = maybe_int.map((int i) {
        import std.conv : to;
        return to!string(i);
    });
    assert(maybe_str.isSome());
    assert(maybe_str.take() == "42");
}

unittest {
    Optional!int maybe_int = Optional!int.none();
    Optional!string maybe_str = maybe_int.map_or("empty", (int i) {
        import std.conv : to;
        return to!string(i);
    });
    assert(maybe_str.isSome());
    assert(maybe_str.take() == "empty");
}

unittest {
    Optional!int maybe_int = Optional!int.some(42);
    Optional!string maybe_str = maybe_int.map_or("empty", (int i) {
        import std.conv : to;
        return to!string(i);
    });
    assert(maybe_str.isSome());
    assert(maybe_str.take() == "42");
}

unittest {
    Optional!int maybe_int = Optional!int.none();
    Optional!string maybe_str = maybe_int.and_then((int i) {
        import std.conv : to;
        return Optional!string.some(to!string(i));
    });
    assert(maybe_str.isNone());
}

unittest {
    Optional!int maybe_int = Optional!int.some(42);
    Optional!string maybe_str = maybe_int.and_then((int i) {
        import std.conv : to;
        return Optional!string.some(to!string(i));
    });
    assert(maybe_str.isSome());
    assert(maybe_str.take() == "42");
}

unittest {
    alias MaybeInt = Optional!int;
    assert(isOptional!(MaybeInt) == true);
    assert(isOptional!(int) == false);
}
