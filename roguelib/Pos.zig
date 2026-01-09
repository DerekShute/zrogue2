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
// Iterator: range
//

pub const Range = struct {
    curr: Self = undefined,
    start: Self = undefined, // Top left
    end: Self = undefined, // Bottom right

    pub fn init(s: Self, e: Self) Range {
        return .{
            .curr = s,
            .start = s,
            .end = e,
        };
    }

    pub fn next(self: *Range) ?Self {
        const old = self.curr;
        const x = old.getX();
        const y = old.getY();
        if (y > self.end.getY()) {
            return null;
        }
        if (x >= self.end.getX()) { // next row
            self.curr = config(self.start.getX(), y + 1);
        } else {
            self.curr = config(x + 1, y); // next column
        }
        return old;
    }
};

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

test "try out Range" {
    var r = Range.init(config(7, 3), config(10, 8));

    var hitlowx: bool = false;
    var hitlowy: bool = false;
    var hithighx: bool = false;
    var hithighy: bool = false;

    while (r.next()) |p| {
        const x = p.getX();
        const y = p.getY();

        try expect(x >= 7);
        try expect(x <= 10);
        try expect(y >= 3);
        try expect(y <= 8);
        if (x == 7) {
            hitlowx = true;
        }
        if (x == 10) {
            hithighx = true;
        }
        if (y == 3) {
            hitlowy = true;
        }
        if (y == 8) {
            hithighy = true;
        }
    }
    try expect(hitlowx and hitlowy and hithighx and hithighy);
}

// EOF
