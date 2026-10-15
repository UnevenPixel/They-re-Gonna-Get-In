# Animation

`AnimationLibrary` bundles a unit's core sprites (idle, walk, attack) with any number of extra named animations, exposed as struct fields matching each `_special` entry's name -- e.g. `myLib.guard` if one entry is `{name: "guard", sprite: sprGuard}`. `_special` entries are added dynamically via `variable_struct_set`, so a unit's animation library can carry arbitrary named clips beyond the three core ones without this constructor needing to know their names in advance.

## API

- `AnimationLibrary(_idle, _walk, _attack, _special)`.
