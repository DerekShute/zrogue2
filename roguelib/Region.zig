//!
//! Region
//!

const std = @import("std");
const Pos = @import("Pos.zig");

const Self = @This();

//
// Members
//

from: Pos = undefined,
to: Pos = undefined,

//
// Constructor
//

pub fn config(from: Pos, to: Pos) Self {
    if ((from.getX() < 0) or (from.getY() < 0) or (to.getX() < 0) or (to.getY() < 0)) {
        @panic("Region.config: Invalid position");
    }

    if ((from.getX() > to.getX()) or (from.getY() > to.getY())) {
        @panic("Region.config: Invalid region");
    }
    return .{ .from = from, .to = to };
}

pub fn configRadius(center: Pos, radius: Pos.Dim) Self {
    // Square centered on 'center', radius 'radius'
    const min = Pos.config(center.getX() - radius, center.getY() - radius);
    const max = Pos.config(center.getX() + radius, center.getY() + radius);

    return config(min, max);
}

//
// Iterator
//

pub const Iterator = struct {
    r: *Self,
    x: Pos.Dim,
    y: Pos.Dim,

    pub fn next(self: *Iterator) ?Pos {
        const oldx = self.x;
        const oldy = self.y;
        if (self.y > self.r.to.getY()) {
            return null;
        } else if (self.x >= self.r.to.getX()) { // next row
            self.y = self.y + 1;
            self.x = self.r.from.getX();
        } else {
            self.x = self.x + 1; // next column
        }
        return Pos.config(oldx, oldy);
    }
};

pub fn iterator(self: *Self) Iterator {
    return .{ .r = self, .x = self.from.getX(), .y = self.from.getY() };
}

//
// Methods
//

pub fn getMin(self: *Self) Pos {
    return self.from;
}

pub fn getMax(self: *Self) Pos {
    return self.to;
}

pub fn isInside(self: *Self, p: Pos) bool {
    const from = self.getMin();
    const to = self.getMax();

    if ((p.getX() < from.getX()) or (p.getX() > to.getX()) or (p.getY() < from.getY()) or (p.getY() > to.getY())) {
        return false;
    }
    return true;
}

//
// Unit tests
//
// Invalid regions will panic
//

const expect = std.testing.expect;

test "Region and Region methods" {
    const min = Pos.config(2, 7);
    const max = Pos.config(9, 11);

    var r = Self.config(min, max);
    try expect(min.eql(r.getMin()));
    try expect(max.eql(r.getMax()));

    try expect(r.getMin().eql(min));
    try expect(r.getMax().eql(max));

    try expect(r.isInside(Pos.config(4, 10)));
    try expect(r.isInside(Pos.config(2, 7)));
    try expect(r.isInside(Pos.config(9, 11)));
    try expect(r.isInside(Pos.config(2, 11)));
    try expect(r.isInside(Pos.config(9, 7)));
    try expect(!r.isInside(Pos.config(0, 0)));
    try expect(!r.isInside(Pos.config(-10, -10)));
    try expect(!r.isInside(Pos.config(10, 0)));
    try expect(!r.isInside(Pos.config(0, 10)));
    try expect(!r.isInside(Pos.config(15, 21)));

    // We will call 1x1 valid for now. 1x1 at 0,0 is the uninitialized room
    _ = Self.config(Pos.config(0, 0), Pos.config(0, 0));
}

test "Region iterator" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);

    // Construct the iteration
    var r = Self.config(Pos.config(2, 7), Pos.config(9, 11));
    var i = r.iterator();
    while (i.next()) |pos| {
        const f: usize = @intCast(pos.getX() + pos.getY() * ARRAYDIM);
        try expect(pos.getX() >= 0);
        try expect(pos.getX() <= ARRAYDIM);
        try expect(pos.getY() >= 0);
        try expect(pos.getY() <= ARRAYDIM);
        a[f] = 1;
    }

    // Rigorously consider what should have been touched

    for (0..ARRAYDIM) |y| {
        for (0..ARRAYDIM) |x| {
            const val = a[x + y * ARRAYDIM];
            if ((x >= 2) and (x <= 9) and (y >= 7) and (y <= 11)) {
                try expect(val == 1);
            } else {
                try expect(val == 0);
            }
        }
    }
}

test "Region radius constructor" {
    var r = Self.configRadius(Pos.config(10, 15), 2);

    try expect(r.getMin().getX() == 8);
    try expect(r.getMin().getY() == 13);
    try expect(r.getMax().getX() == 12);
    try expect(r.getMax().getY() == 17);
}

// EOF
