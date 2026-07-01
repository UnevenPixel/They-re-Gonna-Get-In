// @function Vector2(_x, _y)
/// @param {Real} [_x]
/// @param {Real} [_y]
function Vector2(_x = 0, _y = 0) constructor {
    x = _x;
    y = _y;

    // -------------------------------------------------------
    // Construction / Utility
    // -------------------------------------------------------

    /// @return {Struct.Vector2} A new Vector2 with the same x/y.
    static Copy = function() {
        return new Vector2(x, y);
    }

    /// @param {Real} _x
    /// @param {Real} _y
    /// @return {Struct.Vector2} self
    static Set = function(_x, _y) {
        x = is_struct(_x) ? _x.x : _x;   // is_struct(_x) is true → reads _x.x, never touches _y
        y = is_struct(_x) ? _x.y : _y;   // same check (still true) → reads _x.y, never touches _y
        return self;
    }

    /// @return {Array<Real>}
    static ToArray = function() {
        return [x, y];
    }

    /// @return {String}
    static toString = function() {
        return "(" + string(x) + ", " + string(y) + ")";
    }

    // -------------------------------------------------------
    // Arithmetic (mutating)
    // -------------------------------------------------------

    /// @param {Struct.Vector2} _other
    /// @return {Struct.Vector2} self
    static Add = function(_other) {
        x += _other.x;
        y += _other.y;
        return self;
    }

    /// @param {Struct.Vector2} _other
    /// @return {Struct.Vector2} self
    static Subtract = function(_other) {
        x -= _other.x;
        y -= _other.y;
        return self;
    }

    /// @param {Real} _scalar
    /// @return {Struct.Vector2} self
    static Scale = function(_scalar) {
        x *= _scalar;
        y *= _scalar;
        return self;
    }

    /// @param {Real} _scalar
    /// @return {Struct.Vector2} self
    static Divide = function(_scalar) {
        x /= _scalar;
        y /= _scalar;
        return self;
    }

    /// @param {Struct.Vector2} _other Component-wise multiply (Hadamard product).
    /// @return {Struct.Vector2} self
    static Multiply = function(_other) {
        x *= _other.x;
        y *= _other.y;
        return self;
    }

    /// @return {Struct.Vector2} self
    static Negate = function() {
        x = -x;
        y = -y;
        return self;
    }

    // -------------------------------------------------------
    // Arithmetic ("Get" immutable twins -- built from Copy(),
    // so the math logic above is the single source of truth)
    // -------------------------------------------------------

    static GetAdd = function(_other) {
        return Copy().Add(_other);
    }

    static GetSubtract = function(_other) {
        return Copy().Subtract(_other);
    }

    static GetScale = function(_scalar) {
        return Copy().Scale(_scalar);
    }

    static GetDivide = function(_scalar) {
        return Copy().Divide(_scalar);
    }

    static GetMultiply = function(_other) {
        return Copy().Multiply(_other);
    }

    static GetNegate = function() {
        return Copy().Negate();
    }

    // -------------------------------------------------------
    // Length / Normalize / Clamp
    // -------------------------------------------------------

    /// @return {Real}
    static Length = function() {
        return sqrt(x * x + y* y)
    }

    /// @return {Real}
    static LengthSquared = function() {
        return x * x + y * y;
    }

    /// @return {Struct.Vector2} self, normalized. Zero-length input safely becomes (0,0).
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

    static GetNormalize = function() {
        return Copy().Normalize();
    }

    /// @param {Real} _max
    /// @return {Struct.Vector2} self, with length clamped to _max if it exceeds it.
    static ClampLength = function(_max) {
        var _len = Length();
        if (_len > _max && _len > 0) {
            var _scale = _max / _len;
            x *= _scale;
            y *= _scale;
        }
        return self;
    }

    static GetClampLength = function(_max) {
        return Copy().ClampLength(_max);
    }

    // -------------------------------------------------------
    // Geometry
    // -------------------------------------------------------

    /// @param {Real} _deg
    /// @return {Struct.Vector2} self, rotated by _deg degrees.
    ///         Routed through lengthdir_x/y so it matches GameMaker's own
    ///         angle convention (and the y-axis flip) exactly.
    static Rotate = function(_deg) {
        var _len = Length();
        var _ang = Angle() + _deg;
        x = lengthdir_x(_len, _ang);
        y = lengthdir_y(_len, _ang);
        return self;
    }

    static GetRotate = function(_deg) {
        return Copy().Rotate(_deg);
    }

    /// @param {Struct.Vector2} _other
    /// @param {Real} _t 0..1
    /// @return {Struct.Vector2} self, linearly interpolated toward _other.
    static Lerp = function(_other, _t) {
        x = lerp(x, _other.x, _t);
        y = lerp(y, _other.y, _t);
        return self;
    }

    static GetLerp = function(_other, _t) {
        return Copy().Lerp(_other, _t);
    }

    /// @param {Struct.Vector2} _normal Should be a unit vector.
    /// @return {Struct.Vector2} self, reflected across _normal.
    static Reflect = function(_normal) {
        var _d = Dot(_normal);
        x -= 2 * _d * _normal.x;
        y -= 2 * _d * _normal.y;
        return self;
    }

    static GetReflect = function(_normal) {
        return Copy().Reflect(_normal);
    }

    // -------------------------------------------------------
    // Queries (no mutation -- nothing to make a "Get" twin of)
    // -------------------------------------------------------

    /// @param {Struct.Vector2} _other
    /// @return {Real}
    static Dot = function(_other) {
        return x * _other.x + y * _other.y;
    }

    /// @param {Struct.Vector2} _other
    /// @return {Real} The z-component of the 3D cross product.
    static Cross = function(_other) {
        return x * _other.y - y * _other.x;
    }

    /// @param {Struct.Vector2} _other
    /// @return {Real}
    static Distance = function(_other) {
        return point_distance(x, y, _other.x, _other.y);
    }

    /// @param {Struct.Vector2} _other
    /// @return {Real}
    static DistanceSquared = function(_other) {
        var _dx = _other.x - x;
        var _dy = _other.y - y;
        return _dx * _dx + _dy * _dy;
    }

    /// @return {Real} Direction this vector points, in degrees.
    static Angle = function() {
        return point_direction(0, 0, x, y);
    }

    /// @param {Struct.Vector2} _other
    /// @return {Real} Direction in degrees from this point to _other.
    static AngleTo = function(_other) {
        return point_direction(x, y, _other.x, _other.y);
    }

    /// @param {Struct.Vector2} _other
    /// @param {Real} [_eps]
    /// @return {Bool}
    static Equals = function(_other, _eps = 0.00001) {
        return (abs(x - _other.x) <= _eps) && (abs(y - _other.y) <= _eps);
    }

    /// @param {Real} [_eps]
    /// @return {Bool}
    static IsZero = function(_eps = 0.00001) {
        return LengthSquared() <= (_eps * _eps);
    }
}

// ===========================================================
// Factory functions
// (Plain global functions -- useful for quick definitions)
// ===========================================================

/// @return {Struct.Vector2}
function Vector2Zero() {
    return new Vector2(0, 0);
}

/// @return {Struct.Vector2}
function Vector2One() {
    return new Vector2(1, 1);
}

/// @return {Struct.Vector2} (0, -1) -- "up" on screen.
function Vector2Up() {
    return new Vector2(0, -1);
}

/// @return {Struct.Vector2} (0, 1) -- "down" on screen.
function Vector2Down() {
    return new Vector2(0, 1);
}

/// @return {Struct.Vector2} (-1, 0)
function Vector2Left() {
    return new Vector2(-1, 0);
}

/// @return {Struct.Vector2} (1, 0)
function Vector2Right() {
    return new Vector2(1, 0);
}

/// @param {Real} _deg
/// @param {Real} [_length]
/// @return {Struct.Vector2}
function Vector2FromAngle(_deg, _length = 1) {
    return new Vector2(lengthdir_x(_length, _deg), lengthdir_y(_length, _deg));
}

/// @param {Array<Real>} _arr [x, y]
/// @return {Struct.Vector2}
function Vector2FromArray(_arr) {
    return new Vector2(_arr[0], _arr[1]);
}

/// Shape Structs

function ShapeRect(_x1,_y1,_x2,_y2) constructor {
    x1 = _x1;
    y1 = _y1;
    x2 = _x2;
    y2 = _y2;
    
    static getCenter = function(){
        var _centerPoint = Vector2Zero();
        var _xRelative = (x2 - x1)/2;
        var _yRelative = (y2 - y1)/2;
        
        _centerPoint.Set(x1 + _xRelative, y1 + _yRelative)
        
        return _centerPoint;
    }
}
