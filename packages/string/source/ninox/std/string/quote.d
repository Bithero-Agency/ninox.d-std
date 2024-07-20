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
 * Module containing string quotation
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2024 Mai-Lapyst
 * Authors:   $(HTTP codearq.net/mai-lapyst, Mai-Lapyst)
 */
module ninox.std.string.quote;

import ninox.std.string.utf8 : runeSelf, decodeRune;
import ninox.std.string.conv : unhex;

struct Unquoter {
    // The resulting rune from unquoting.
    dchar result = 0;

    // The tail, i.e. everyting after the unquoted char.
    string tail = null;

    // The quotation character (indicator of end-of input)
    char quote = '\0';

    // The size of the result in byte; can be used to safely cast down `dchar`.
    ubyte size = 0;

    enum Error : ubyte {
        none,
        eoi,
        invalidHexSeq,
        invalidOctalSeq,
        invalidEscSeq,
    }

    // The error code from the last operation.
    Error err;

    // Returns the error as a human-readable string.
    @property string errStr() const pure @safe @nogc nothrow {
        final switch (this.err) {
            case Error.none: return "No error";
            case Error.eoi: return "End of input";
            case Error.invalidHexSeq: return "Invalid hex sequence";
            case Error.invalidOctalSeq: return "Invalid octal sequence";
            case Error.invalidEscSeq: return "Invalid escape sequence";
        }
    }

    // Retrieves the result as an 8-bit wide character.
    pragma(inline) @property char asChar() const pure @safe {
        if (this.err != Error.none || this.size != 1) {
            throw new Exception("Cannot cast result to a 8-bit char");
        }
        return cast(char) this.result;
    }

    // Retrieves the result as an 16-bit wide character.
    pragma(inline) @property wchar asWchar() const pure @safe {
        if (this.err != Error.none || this.size != 2) {
            throw new Exception("Cannot cast result to a 16-bit wchar");
        }
        return cast(wchar) this.result;
    }

    pragma(inline) @property bool hasError() const pure @safe @nogc nothrow {
        return this.err != Error.none;
    }

    pragma(inline) private void setResult(dchar r, string t, ubyte sz) pure @safe @nogc nothrow {
        this.result = r;
        this.tail = t;
        this.size = sz;
        this.err = Error.none;
    }

    pragma(inline) private void setError(Error err) pure @safe @nogc nothrow {
        this.result = 0;
        this.size = 0;
        this.err = err;
    }

    /** 
     * Initializes the unquoter.
     * 
     * Params:
     *   s = The string to unquote from.
     *   quote = The quotation or end-of-input marker.
     */
    this(string s, char quote = '\0') pure @trusted @nogc nothrow {
        this.tail = s;
        this.quote = quote;
    }

    /** 
     * Unquotes the next character.
     * 
     * Returns: The unquoted character.
     */
    @property dchar next() pure @trusted @nogc nothrow {
        alias s = this.tail;

        if (s.length < 1) {
            this.setError(Error.eoi);
            return 0;
        }

        char c = s[0];
        if (c == quote) {
            this.setError(Error.eoi);
            return 0;
        }
        else if (c >= runeSelf) {
            // is utf8
            ubyte sz = 0;
            dchar r = s.decodeRune(&sz);

            if (sz >= 3) {
                this.setResult(r, s[sz..$], 4);
            }
            else {
                this.setResult(r, s[sz..$], 2);
            }
            return r;
        }
        else if (c != '\\') {
            this.setResult(c, s[1..$], 1);
            return c;
        }

        if (s.length <= 1) {
            this.setError(Error.invalidEscSeq);
            return 0;
        }

        c = s[1];
        s = s[2..$];

        dchar r = 0;
        switch (c) {
            case 'a': r = '\a'; break;
            case 'b': r = '\b'; break;
            case 'f': r = '\f'; break;
            case 'n': r = '\n'; break;
            case 'r': r = '\r'; break;
            case 't': r = '\t'; break;
            case 'v': r = '\v'; break;
            case 'x': case 'u': case 'U': {
                ubyte n = (c == 'x') ? 2 : ((c == 'u') ? 4 : 8);
                if (s.length < n) {
                    return 0;
                }
                import std.conv : to;
                import std.ascii : isHexDigit;
                for (int i = 0; i < n; i++) {
                    if (!s[i].isHexDigit) {
                        this.setError(Error.invalidHexSeq);
                        return 0;
                    }
                    r = (r << 4) | s[i].unhex;
                }
                s = s[n..$];
                break;
            }
            case '0': .. case '7': {
                r = c - '0';
                if (s.length < 2) {
                    return 0;
                }
                for (int i = 0; i < 2; i++) {
                    byte b = cast(byte)(s[i] - '0');
                    if (b < 0 || b > 7) {
                        this.setError(Error.invalidOctalSeq);
                        return 0;
                    }
                    r = (r << 3) | b;
                }
                s = s[2..$];

                // size = 2 bc we parse up to '\777' which is 511
                this.setResult(r, s, 2);
                return r;
            }
            case '\\': r = '\\'; break;
            case '\'': case '"': r = c; break;
            default:
                this.setError(Error.invalidEscSeq);
                return 0;
        }

        this.setResult(r, s, 1);
        return r;
    }
}

/** 
 * Unquotes a single character from a string.
 * 
 * Params:
 *   s = The string to unquote a character from.
 *   quote = Optional quotation or end-of-input marker.
 *   tail = Optional pointer to recieve the tail of the unquoting.
 * 
 * Returns: The unquoted character / rune.
 */
pragma(inline) @live dchar unquoteChar(string s, char quote = '\0', scope string* tail = null) pure @trusted @nogc nothrow {
    auto unquoter = Unquoter(s, quote);
    dchar r = unquoter.next();
    if (tail != null)
        *tail = unquoter.tail;
    return r;
}

/** 
 * Unquotes a complete string.
 * 
 * Params:
 *   s = The string to unquote.
 *   quote = Optional quotation or end-of-input marker.
 * 
 * Throws: `Exception` when the unquoting failed.
 * 
 * Returns: The unquoted string.
 */
@live string unquoteString(string s, char quote = '\0') pure @trusted {
    string ret = "";
    auto unquoter = Unquoter(s, quote);
    while (unquoter.tail.length > 0) {
        if (unquoter.tail[0] == quote) {
            break;
        }

        unquoter.next();
        if (unquoter.hasError) {
            throw new Exception("unquoteString: " ~ unquoter.errStr);
        }
        ret ~= unquoter.result;
    }
    return ret;
}

unittest {
    void test(string s, dchar res, string tail_res) {
        import std.conv : to;
        string tail = "";
        dchar r = s.unquoteChar(tail: &tail);
        assert(r == res, "Expected unquoted char to be '" ~ res.to!string ~ "', but was '" ~ r.to!string ~ "' instead");
        assert(tail == tail_res, "Expected tail to be \"" ~ tail_res ~ "\", but was \"" ~ tail ~ "\" instead");
    }

    test("ab", 'a', "b");
    test("\\nb", '\n', "b");
    test("\\x61b", 'a', "b");
    test("\\u0061b", 'a', "b");
    test("\\U00000061b", 'a', "b");
    test("\\070b", '8', "b");
}

unittest {
    assert(`a\t\x61\u0062\U00000063\070`.unquoteString == "a\tabc8");

    assert(`ab'c`.unquoteString('\'') == "ab");
}
