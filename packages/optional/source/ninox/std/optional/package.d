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
