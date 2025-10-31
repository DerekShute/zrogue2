//!
//! Positions and position-related
//!

const std = @import("std");

//
// Types
//

pub const Dim = i16;

pub const Direction = enum {
    north,
    east,
    south,
    west,
};

const Self = @This();

//
// Members
//

xy: [2]Dim = .{ -1, -1 },

//
// Methods
//

pub inline fn config(x: Dim, y: Dim) Self {
    return .{ .xy = .{ x, y } };
}

pub inline fn direct(d: Direction) Self {
    return switch (d) {
        .north => Self.config(0, -1),
        .east => Self.config(1, 0),
        .south => Self.config(0, 1),
        .west => Self.config(-1, 0),
    };
}

pub inline fn quant(self: Self) usize {
    return @intCast(self.xy[0] * self.xy[1]);
}

pub inline fn getX(self: Self) Dim {
    return self.xy[0];
}

pub inline fn getY(self: Self) Dim {
    return self.xy[1];
}

pub inline fn isDim(self: Self) bool {
    return ((self.getX() >= 0) and (self.getY() >= 0));
}

pub inline fn eql(self: Self, other: Self) bool {
    return ((self.getX() == other.getX()) and (self.getY() == other.getY()));
}

// Implication is that one of these is a delta
pub inline fn add(pos1: Self, pos2: Self) Self {
    return config(pos1.getX() + pos2.getX(), pos1.getY() + pos2.getY());
}

// Chebyshev distance
pub inline fn distance(pos1: Self, pos2: Self) Dim {
    const maxx = @abs(pos1.getX() - pos2.getX());
    const maxy = @abs(pos1.getY() - pos2.getY());
    return if (maxx > maxy) @intCast(maxx) else @intCast(maxy);
}

//
// Unit Tests
//

const expect = std.testing.expect;

test "create a Pos and use its operations" {
    const a = config(5, 5);
    const b: Dim = 5;

    try expect(a.getY() == b);
    try expect(a.getX() == b);
    try expect(a.quant() == 25);
    try expect(a.isDim());
    try expect(a.eql(config(5, 5)));

    // Distance calculations

    try expect(distance(config(1, 1), config(2, 2)) == 1);
    try expect(distance(config(1, 1), config(3, 3)) == 2);
    try expect(distance(config(1, 1), config(0, 0)) == 1);
    try expect(distance(config(1, 1), config(1, 1)) == 0);
    try expect(distance(config(-1, -1), config(0, 0)) == 1);
}

// EOF
