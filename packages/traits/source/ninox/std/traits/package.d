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
