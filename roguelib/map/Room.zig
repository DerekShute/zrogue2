//!
//! Room : generally a rectangle of open space, connected by corridors
//!        (has stuff inside)

const Pos = @import("../Pos.zig");
const Region = @import("../Region.zig");

const Self = @This();

//
// Members
//

r: Region = undefined,
flags: packed struct {
    lit: bool,
    gone: bool,
},

//
// Constructor
//

pub fn config(tl: Pos, br: Pos) Self {
    // (0,0) - (0,0) is reserved as the special 'uninitialized' room
    return .{
        .r = Region.config(tl, br),
        .flags = .{
            .lit = true,
            .gone = false,
        },
    };
}

//
// Methods
//

pub fn isLit(self: *Self) bool {
    return self.flags.lit;
}

pub fn setDark(self: *Self) void {
    self.flags.lit = false;
}

pub fn isGone(self: *Self) bool {
    return self.flags.gone;
}

pub fn setGone(self: *Self) void {
    self.flags.gone = true;
}

// Region Methods

pub fn getRegion(self: *Self) Region {
    // TODO inadvisable
    return self.r;
}

pub fn getMinX(self: *Self) Pos.Dim {
    const min = self.r.getMin();
    return min.getX();
}

pub fn getMaxX(self: *Self) Pos.Dim {
    const max = self.r.getMax();
    return max.getX();
}

pub fn getMinY(self: *Self) Pos.Dim {
    const min = self.r.getMin();
    return min.getY();
}

pub fn getMaxY(self: *Self) Pos.Dim {
    const max = self.r.getMax();
    return max.getY();
}

pub fn isInside(self: *Self, at: Pos) bool {
    return self.r.isInside(at);
}

//
// Unit Tests
//

const expect = @import("std").testing.expect;

test "create a room and test properties" {
    var room = config(Pos.config(10, 10), Pos.config(20, 20));

    try expect(room.getMaxX() == 20);
    try expect(room.getMaxY() == 20);
    try expect(room.getMinX() == 10);
    try expect(room.getMinY() == 10);
    try expect(room.isInside(Pos.config(15, 15))); // Smoke: methods available

    try expect(room.isGone() == false); // Expected default
    room.setGone();
    try expect(room.isGone() == true);

    try expect(room.isLit() == true); // Expected default
    room.setDark();
    try expect(room.isLit() == false);
}

// EOF
