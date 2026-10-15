# Math

`Vector2` and simple shape structs used throughout the project.

## Vector2

A mutable 2D vector. Follows this project's mutate-by-default convention: arithmetic/geometry methods (`Add`, `Subtract`, `Scale`, `Divide`, `Multiply`, `Negate`, `Normalize`, `ClampLength`, `Rotate`, `Lerp`, `Reflect`) mutate `self` and return it for chaining. Each has a `Get`-prefixed immutable twin (`GetAdd`, `GetSubtract`, ...) built from `Copy()` so the mutating method is the single source of truth for the math -- the immutable twin is never a separate reimplementation.

Organized into: construction/utility (`Copy`, `Set`, `ToArray`, `toString`), mutating arithmetic, the `Get`-prefixed immutable twins, length/normalize/clamp, geometry (`Rotate`/`Lerp`/`Reflect` + their `Get` twins), and read-only queries (`Dot`/`Cross`/`Distance`/`Angle`/`Equals`/`IsZero` -- no mutation, so no `Get` twin needed).

`Set(_x, _y)` accepts EITHER two reals OR a single `Vector2` to copy from -- if `_x` is a struct (`is_struct(_x)`), both `x` and `y` are read from it and the `_y` parameter is ignored entirely.

`Rotate(_deg)` is routed through `lengthdir_x`/`lengthdir_y` rather than a raw rotation matrix, so it matches GameMaker's own angle convention (and y-axis flip) exactly.

`Normalize()`/`GetNormalize()`: zero-length input safely becomes `(0,0)` rather than dividing by zero.

## Factory functions

Plain global functions for quick common vectors: `Vector2Zero()`, `Vector2One()`, `Vector2Up()` ((0,-1), "up" on screen), `Vector2Down()` ((0,1)), `Vector2Left()` ((-1,0)), `Vector2Right()` ((1,0)), `Vector2FromAngle(_deg, _length)`, `Vector2FromArray(_arr)`.

## ShapeRect

An axis-aligned rectangle defined by two corners. `getCenter()` computes the midpoint.

## API

- `Vector2(_x, _y)` -- see method list above.
- `Vector2Zero()`, `Vector2One()`, `Vector2Up()`, `Vector2Down()`, `Vector2Left()`, `Vector2Right()`, `Vector2FromAngle(_deg, _length)`, `Vector2FromArray(_arr)`.
- `ShapeRect(_x1, _y1, _x2, _y2)` -- `.getCenter()`.
