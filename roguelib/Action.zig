//!
//! Entity actions
//!

const std = @import("std");

const Pos = @import("Pos.zig");

const Self = @This();

//
// Types
//

pub const Type = enum {
    none,
    quit,
    ascend,
    descend,
    move, // Directional
    search,
    take, // Positional
    wait,
};

//
// Members
//

kind: Type,
pos: Pos, // MoveAction (delta)

//
// Constructors
//

pub fn config(t: Type) Self {
    return .{ .kind = t, .pos = Pos.config(0, 0) };
}

pub fn configDir(t: Type, d: Pos.Direction) Self {
    return .{ .kind = t, .pos = Pos.direct(d) };
}

pub fn configPos(t: Type, p: Pos) Self {
    return .{ .kind = t, .pos = p };
}

//
// Methods
//

pub fn getPos(self: *Self) Pos {
    return self.pos;
}

//
// Unit Tests
//

const expect = std.testing.expect;

test "entity action" {
    var action = config(.quit);

    try expect(action.getPos().eql(Pos.config(0, 0)));

    action = configDir(.move, .west);
    try expect(action.getPos().eql(Pos.config(-1, 0)));
}

// EOF
