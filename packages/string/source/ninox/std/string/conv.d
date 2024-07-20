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
 * Module containing code for converting strings.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2024 Mai-Lapyst
 * Authors:   $(HTTP codearq.net/mai-lapyst, Mai-Lapyst)
 */
module ninox.std.string.conv;

/** 
 * Takes a single nibble (4 bit) of an hex string and returns the numerical value it represents.
 * 
 * Params:
 *   c = The hex character to convert.
 *   ok = Optional pointer to retrieve if the conversion was successfull or not.
 * 
 * Returns: On success the numerical value; on failure `0`.
 *          Use the `ok` param to distinguish a parsed zero with an error.
 */
byte unhex(char c, scope bool* ok = null) pure @safe @nogc nothrow {
    if (c >= '0' && c <= '9') {
        if (ok !is null) *ok = true;
        return cast(byte)(c - '0');
    }
    else if (c >= 'a' && c <= 'f') {
        if (ok !is null) *ok = true;
        return cast(byte)(c - 'a' + 10);
    }
    else if (c >= 'A' && c <= 'F') {
        if (ok !is null) *ok = true;
        return cast(byte)(c - 'A' + 10);
    }
    if (ok !is null) *ok = false;
    return 0;
}

unittest {
    assert('f'.unhex == 0xf);
}
