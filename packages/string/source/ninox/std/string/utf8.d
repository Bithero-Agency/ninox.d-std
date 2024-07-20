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
 * Module containing code in relation with utf8.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2024 Mai-Lapyst
 * Authors:   $(HTTP codearq.net/mai-lapyst, Mai-Lapyst)
 */
module ninox.std.string.utf8;

/// Indicator / minimum byte value to count as part of an utf-8 rune.
immutable enum runeSelf = 0x80;

/** 
 * Checks if an character is part of an UTF-8 rune / sequence.
 * 
 * Params:
 *   c = The character to check.
 * 
 * Returns: `true` if part of an utf-8 rune, `false` otherwise.
 */
pragma(inline) @property bool isUtf8(char c) pure @safe @nogc nothrow {
    return c >= runeSelf;
}

/** 
 * Decodes a single UTF-8 rune at the start of the string.
 * 
 * Params:
 *   s = The string to decode one rune from.
 *   sz = Optional pointer to recieve the size (in bytes) of the rune that was decoded.
 * 
 * Returns: The decoded rune, or `0` on error.
 */
@live dchar decodeRune(string s, scope ubyte* sz = null) pure @safe @nogc nothrow {
    if (s.length < 1) {
        return '\0';
    }

    char c = s[0];
    if (!c.isUtf8) {
        return c;
    }
    else if (c >= 0xF0) {
        // 4 bytes
        if (sz !is null) *sz = 4;
        return ((s[0] & 0b00000111) << 18)
            | ((s[1] & 0b00111111) << 12)
            | ((s[2] & 0b00111111) << 6)
            | (s[3] & 0b00111111);
    }
    else if (c >= 0xE0) {
        // 3 bytes
        if (sz !is null) *sz = 3;
        return ((s[0] & 0b00001111) << 12)
            | ((s[1] & 0b00111111) << 6)
            | (s[2] & 0b00111111);
    }
    else if (c >= 0xC0) {
        // 2 bytes
        if (sz !is null) *sz = 2;
        return ((s[0] & 0b00011111) << 6)
            | (s[1] & 0b00111111);
    }
    return '\0';
}

unittest {
    assert("a".decodeRune == 'a');

    ubyte sz = 0;
    assert("❁".decodeRune(&sz) == '❁' && sz == 3);
}
