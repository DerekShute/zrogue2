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

// TODO: to init
pub fn config(from: Pos, to: Pos) Self {
    if ((from.getX() < 0) or (from.getY() < 0)) {
        @panic("Region.config: Invalid low position");
    }
    if ((to.getX() < 0) or (to.getY() < 0)) {
        @panic("Region.config: Invalid high position");
    }

    if ((from.getX() > to.getX()) or (from.getY() > to.getY())) {
        @panic("Region.config: Invalid region");
    }
    return .{ .from = from, .to = to };
}

pub fn configRadius(center: Pos, radius: Pos.Dim) Self {
    // Square centered on 'center', radius 'radius'
    const min = Pos.init(center.getX() - radius, center.getY() - radius);
    const max = Pos.init(center.getX() + radius, center.getY() + radius);

    return config(min, max);
}

pub fn iterator(self: *Self) Pos.Range {
    return Pos.Range.init(self.from, self.to);
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
    const min = Pos.init(2, 7);
    const max = Pos.init(9, 11);

    var r = Self.config(min, max);
    try expect(min.eql(r.getMin()));
    try expect(max.eql(r.getMax()));

    try expect(r.getMin().eql(min));
    try expect(r.getMax().eql(max));

    try expect(r.isInside(.init(4, 10)));
    try expect(r.isInside(.init(2, 7)));
    try expect(r.isInside(.init(9, 11)));
    try expect(r.isInside(.init(2, 11)));
    try expect(r.isInside(.init(9, 7)));
    try expect(!r.isInside(.init(0, 0)));
    try expect(!r.isInside(.init(-10, -10)));
    try expect(!r.isInside(.init(10, 0)));
    try expect(!r.isInside(.init(0, 10)));
    try expect(!r.isInside(.init(15, 21)));

    // We will call 1x1 valid for now. 1x1 at 0,0 is the uninitialized room
    _ = config(.init(0, 0), .init(0, 0));
}

test "Region iterator" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);

    // Construct the iteration
    var r = config(.init(2, 7), .init(9, 11));
    var i = r.iterator();
    while (i.next()) |pos| {
        const f: usize = @intCast(pos.getX() + pos.getY() * ARRAYDIM);
        try expect(pos.getX() >= 0);
        try expect(pos.getX() < ARRAYDIM);
        try expect(pos.getY() >= 0);
        try expect(pos.getY() < ARRAYDIM);
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

test "Region iterator entire" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);

    // Construct the iteration
    var r = config(.init(0, 0), .init(13, 13));
    var i = r.iterator();
    while (i.next()) |pos| {
        const f: usize = @intCast(pos.getX() + pos.getY() * ARRAYDIM);
        try expect(pos.getX() >= 0);
        try expect(pos.getX() < ARRAYDIM);
        try expect(pos.getY() >= 0);
        try expect(pos.getY() < ARRAYDIM);
        a[f] = 1;
    }

    // Rigorously consider what should have been touched

    for (0..ARRAYDIM) |y| {
        for (0..ARRAYDIM) |x| {
            const val = a[x + y * ARRAYDIM];
            try expect(val == 1);
        }
    }
}

test "Region radius constructor" {
    var r = Self.configRadius(.init(10, 15), 2);

    try expect(r.getMin().getX() == 8);
    try expect(r.getMin().getY() == 13);
    try expect(r.getMax().getX() == 12);
    try expect(r.getMax().getY() == 17);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
