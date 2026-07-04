/// @function Vector2(_x, _y)
/// @description A mutable 2D vector. Arithmetic methods (Add, Subtract, Scale, ...)
///        mutate and return self for chaining; each has a Get-prefixed immutable
///        twin (GetAdd, GetSubtract, ...) built from Copy().
/// @param {Real} [_x]
/// @param {Real} [_y]
function Vector2(_x = 0, _y = 0) constructor {
    x = _x;
    y = _y;

    // -------------------------------------------------------
    // Construction / Utility
    // -------------------------------------------------------

    /// @function Copy()
    /// @returns {Struct.Vector2} A new Vector2 with the same x/y.
    static Copy = function() {
        return new Vector2(x, y);
    }

    /// @function Set(_x, _y)
    /// @param {Real|Struct.Vector2} _x A real x value, or a Vector2 to copy
    ///        x/y from -- if a Vector2 is passed, _y is ignored entirely.
    /// @param {Real} [_y] Ignored when _x is a Vector2.
    /// @returns {Struct.Vector2} self
    static Set = function(_x, _y) {
        x = is_struct(_x) ? _x.x : _x;   // is_struct(_x) is true → reads _x.x, never touches _y
        y = is_struct(_x) ? _x.y : _y;   // same check (still true) → reads _x.y, never touches _y
        return self;
    }

    /// @function ToArray()
    /// @returns {Array<Real>}
    static ToArray = function() {
        return [x, y];
    }

    /// @function toString()
    /// @returns {String}
    static toString = function() {
        return "(" + string(x) + ", " + string(y) + ")";
    }

    // -------------------------------------------------------
    // Arithmetic (mutating)
    // -------------------------------------------------------

    /// @function Add(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Struct.Vector2} self
    static Add = function(_other) {
        x += _other.x;
        y += _other.y;
        return self;
    }

    /// @function Subtract(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Struct.Vector2} self
    static Subtract = function(_other) {
        x -= _other.x;
        y -= _other.y;
        return self;
    }

    /// @function Scale(_scalar)
    /// @param {Real} _scalar
    /// @returns {Struct.Vector2} self
    static Scale = function(_scalar) {
        x *= _scalar;
        y *= _scalar;
        return self;
    }

    /// @function Divide(_scalar)
    /// @param {Real} _scalar
    /// @returns {Struct.Vector2} self
    static Divide = function(_scalar) {
        x /= _scalar;
        y /= _scalar;
        return self;
    }

    /// @function Multiply(_other)
    /// @param {Struct.Vector2} _other Component-wise multiply (Hadamard product).
    /// @returns {Struct.Vector2} self
    static Multiply = function(_other) {
        x *= _other.x;
        y *= _other.y;
        return self;
    }

    /// @function Negate()
    /// @returns {Struct.Vector2} self
    static Negate = function() {
        x = -x;
        y = -y;
        return self;
    }

    // -------------------------------------------------------
    // Arithmetic ("Get" immutable twins -- built from Copy(),
    // so the math logic above is the single source of truth)
    // -------------------------------------------------------

    /// @function GetAdd(_other)
    /// @description Immutable twin of Add() -- returns a new Vector2 instead of mutating.
    /// @param {Struct.Vector2} _other
    /// @returns {Struct.Vector2} A new vector, this + _other.
    static GetAdd = function(_other) {
        return Copy().Add(_other);
    }

    /// @function GetSubtract(_other)
    /// @description Immutable twin of Subtract() -- returns a new Vector2 instead of mutating.
    /// @param {Struct.Vector2} _other
    /// @returns {Struct.Vector2} A new vector, this - _other.
    static GetSubtract = function(_other) {
        return Copy().Subtract(_other);
    }

    /// @function GetScale(_scalar)
    /// @description Immutable twin of Scale() -- returns a new Vector2 instead of mutating.
    /// @param {Real} _scalar
    /// @returns {Struct.Vector2} A new vector, this scaled by _scalar.
    static GetScale = function(_scalar) {
        return Copy().Scale(_scalar);
    }

    /// @function GetDivide(_scalar)
    /// @description Immutable twin of Divide() -- returns a new Vector2 instead of mutating.
    /// @param {Real} _scalar
    /// @returns {Struct.Vector2} A new vector, this divided by _scalar.
    static GetDivide = function(_scalar) {
        return Copy().Divide(_scalar);
    }

    /// @function GetMultiply(_other)
    /// @description Immutable twin of Multiply() -- returns a new Vector2 instead of mutating.
    /// @param {Struct.Vector2} _other Component-wise multiply (Hadamard product).
    /// @returns {Struct.Vector2} A new vector, this * _other component-wise.
    static GetMultiply = function(_other) {
        return Copy().Multiply(_other);
    }

    /// @function GetNegate()
    /// @description Immutable twin of Negate() -- returns a new Vector2 instead of mutating.
    /// @returns {Struct.Vector2} A new vector, the negation of this one.
    static GetNegate = function() {
        return Copy().Negate();
    }

    // -------------------------------------------------------
    // Length / Normalize / Clamp
    // -------------------------------------------------------

    /// @function Length()
    /// @returns {Real}
    static Length = function() {
        return sqrt(x * x + y* y)
    }

    /// @function LengthSquared()
    /// @returns {Real}
    static LengthSquared = function() {
        return x * x + y * y;
    }

    /// @function Normalize()
    /// @returns {Struct.Vector2} self, normalized. Zero-length input safely becomes (0,0).
    static Normalize = function() {
        var _len = Length();
        if (_len == 0) {
            x = 0;
            y = 0;
        } else {
            x /= _len;
            y /= _len;
        }
        return self;
    }

    /// @function GetNormalize()
    /// @description Immutable twin of Normalize() -- returns a new Vector2 instead of mutating.
    /// @returns {Struct.Vector2} A new normalized vector. Zero-length input safely becomes (0,0).
    static GetNormalize = function() {
        return Copy().Normalize();
    }

    /// @function ClampLength(_max)
    /// @param {Real} _max
    /// @returns {Struct.Vector2} self, with length clamped to _max if it exceeds it.
    static ClampLength = function(_max) {
        var _len = Length();
        if (_len > _max && _len > 0) {
            var _scale = _max / _len;
            x *= _scale;
            y *= _scale;
        }
        return self;
    }

    /// @function GetClampLength(_max)
    /// @description Immutable twin of ClampLength() -- returns a new Vector2 instead of mutating.
    /// @param {Real} _max
    /// @returns {Struct.Vector2} A new vector, length-clamped to _max if it exceeds it.
    static GetClampLength = function(_max) {
        return Copy().ClampLength(_max);
    }

    // -------------------------------------------------------
    // Geometry
    // -------------------------------------------------------

    /// @function Rotate(_deg)
    /// @param {Real} _deg
    /// @returns {Struct.Vector2} self, rotated by _deg degrees.
    ///         Routed through lengthdir_x/y so it matches GameMaker's own
    ///         angle convention (and the y-axis flip) exactly.
    static Rotate = function(_deg) {
        var _len = Length();
        var _ang = Angle() + _deg;
        x = lengthdir_x(_len, _ang);
        y = lengthdir_y(_len, _ang);
        return self;
    }

    /// @function GetRotate(_deg)
    /// @description Immutable twin of Rotate() -- returns a new Vector2 instead of mutating.
    /// @param {Real} _deg
    /// @returns {Struct.Vector2} A new vector, rotated by _deg degrees.
    static GetRotate = function(_deg) {
        return Copy().Rotate(_deg);
    }

    /// @function Lerp(_other, _t)
    /// @param {Struct.Vector2} _other
    /// @param {Real} _t 0..1
    /// @returns {Struct.Vector2} self, linearly interpolated toward _other.
    static Lerp = function(_other, _t) {
        x = lerp(x, _other.x, _t);
        y = lerp(y, _other.y, _t);
        return self;
    }

    /// @function GetLerp(_other, _t)
    /// @description Immutable twin of Lerp() -- returns a new Vector2 instead of mutating.
    /// @param {Struct.Vector2} _other
    /// @param {Real} _t 0..1
    /// @returns {Struct.Vector2} A new vector, linearly interpolated toward _other.
    static GetLerp = function(_other, _t) {
        return Copy().Lerp(_other, _t);
    }

    /// @function Reflect(_normal)
    /// @param {Struct.Vector2} _normal Should be a unit vector.
    /// @returns {Struct.Vector2} self, reflected across _normal.
    static Reflect = function(_normal) {
        var _d = Dot(_normal);
        x -= 2 * _d * _normal.x;
        y -= 2 * _d * _normal.y;
        return self;
    }

    /// @function GetReflect(_normal)
    /// @description Immutable twin of Reflect() -- returns a new Vector2 instead of mutating.
    /// @param {Struct.Vector2} _normal Should be a unit vector.
    /// @returns {Struct.Vector2} A new vector, reflected across _normal.
    static GetReflect = function(_normal) {
        return Copy().Reflect(_normal);
    }

    // -------------------------------------------------------
    // Queries (no mutation -- nothing to make a "Get" twin of)
    // -------------------------------------------------------

    /// @function Dot(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Real}
    static Dot = function(_other) {
        return x * _other.x + y * _other.y;
    }

    /// @function Cross(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Real} The z-component of the 3D cross product.
    static Cross = function(_other) {
        return x * _other.y - y * _other.x;
    }

    /// @function Distance(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Real}
    static Distance = function(_other) {
        return point_distance(x, y, _other.x, _other.y);
    }

    /// @function DistanceSquared(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Real}
    static DistanceSquared = function(_other) {
        var _dx = _other.x - x;
        var _dy = _other.y - y;
        return _dx * _dx + _dy * _dy;
    }

    /// @function Angle()
    /// @returns {Real} Direction this vector points, in degrees.
    static Angle = function() {
        return point_direction(0, 0, x, y);
    }

    /// @function AngleTo(_other)
    /// @param {Struct.Vector2} _other
    /// @returns {Real} Direction in degrees from this point to _other.
    static AngleTo = function(_other) {
        return point_direction(x, y, _other.x, _other.y);
    }

    /// @function Equals(_other, _eps)
    /// @param {Struct.Vector2} _other
    /// @param {Real} [_eps]
    /// @returns {Bool}
    static Equals = function(_other, _eps = 0.00001) {
        return (abs(x - _other.x) <= _eps) && (abs(y - _other.y) <= _eps);
    }

    /// @function IsZero(_eps)
    /// @param {Real} [_eps]
    /// @returns {Bool}
    static IsZero = function(_eps = 0.00001) {
        return LengthSquared() <= (_eps * _eps);
    }
}

// ===========================================================
// Factory functions
// (Plain global functions -- useful for quick definitions)
// ===========================================================

/// @function Vector2Zero()
/// @returns {Struct.Vector2}
function Vector2Zero() {
    return new Vector2(0, 0);
}

/// @function Vector2One()
/// @returns {Struct.Vector2}
function Vector2One() {
    return new Vector2(1, 1);
}

/// @function Vector2Up()
/// @returns {Struct.Vector2} (0, -1) -- "up" on screen.
function Vector2Up() {
    return new Vector2(0, -1);
}

/// @function Vector2Down()
/// @returns {Struct.Vector2} (0, 1) -- "down" on screen.
function Vector2Down() {
    return new Vector2(0, 1);
}

/// @function Vector2Left()
/// @returns {Struct.Vector2} (-1, 0)
function Vector2Left() {
    return new Vector2(-1, 0);
}

/// @function Vector2Right()
/// @returns {Struct.Vector2} (1, 0)
function Vector2Right() {
    return new Vector2(1, 0);
}

/// @function Vector2FromAngle(_deg, _length)
/// @param {Real} _deg
/// @param {Real} [_length]
/// @returns {Struct.Vector2}
function Vector2FromAngle(_deg, _length = 1) {
    return new Vector2(lengthdir_x(_length, _deg), lengthdir_y(_length, _deg));
}

/// @function Vector2FromArray(_arr)
/// @param {Array<Real>} _arr [x, y]
/// @returns {Struct.Vector2}
function Vector2FromArray(_arr) {
    return new Vector2(_arr[0], _arr[1]);
}

/// Shape Structs

/// @function ShapeRect(_x1, _y1, _x2, _y2)
/// @description An axis-aligned rectangle defined by two corners.
/// @param {Real} _x1
/// @param {Real} _y1
/// @param {Real} _x2
/// @param {Real} _y2
function ShapeRect(_x1,_y1,_x2,_y2) constructor {
    x1 = _x1;
    y1 = _y1;
    x2 = _x2;
    y2 = _y2;

    /// @function getCenter()
    /// @description Computes the midpoint of the rectangle.
    /// @returns {Struct.Vector2} The center point.
    static getCenter = function(){
        var _centerPoint = Vector2Zero();
        var _xRelative = (x2 - x1)/2;
        var _yRelative = (y2 - y1)/2;

        _centerPoint.Set(x1 + _xRelative, y1 + _yRelative)

        return _centerPoint;
    }
}
