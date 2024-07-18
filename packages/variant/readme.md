# ninox-d_std:variant

A variant to hold arbitary data.s

## License

The code in this repository is licensed under AGPL-3.0-or-later; for more details see the `LICENSE` file in the repository.

## Usage

```d
import ninox.std.variant;

auto v = Variant(42);

// Using `.get(T)`, you can retrieve the value
assert(v.get!int == 42);

// `.get(T)` also accepts types where the value of the variant
// can be implicit converted to it:
assert(v.get!size_t == 42);

// To check if the implicit conversion is possible, you can use `.convertsTo(T)`:
assert(v.convertsTo!size_t);

// To check if a variant even holds a value, use `.hasValue`:
assert(v.hasValue);

// ...or view the typeinfo directly by using `.type`:
assert(v.type !is null);

// You also can peek into a variant with `.peek(T)`, but only for exact types:
assert(v.peek!int !is null);
assert(*v.peek!int == 42);
assert(v.peek!size_t null);

// As an extra touch, variants allow detection if an variant and it's value are "truthy".
// This method is expeically usefull if building a template language or similar things.
// 
// Following rules apply for variants to count as "truthy":
//  - Variant must have a value (i.e. `hasValue == true`)
//  - Scalar / numeric values need to be non-zero
//  - Boolean values need to be `true`
//  - Classes or interfaces need to be non-null
//  - Structs are always truthy (as long as the Variant holds a value ofc.)
//  - Arrays (including strings) need to have atleast one element
assert(v.isTruthy);
```

## Differences to phobos's `std.variant`

Phobos implements variants with an template (`VariantN`), which get the maximum size a variant's data can be. This creates the unique problem, that one cannot store arbitarily sized structs in it anymore. While the standard workaround is here to just use classes, this is not a satisfactory answer, as it is ignores people who want to use the gc as less as possible (i.e. allocating classes), or when folks want to use only smaller sized objects.

This implementation also has it's problems; mainly instead of a static data region, it uses an dynamically allocated array for it's data, thus also being not `@nogc`.
