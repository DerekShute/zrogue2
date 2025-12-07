//!
//! Entity actions
//!

const std = @import("std");

const Pos = @import("Pos.zig");

const Self = @This();

//
// Types
//

// TODO: 'help' for more comprehensive handling
// TODO: Use Provider.Command, or absorb it?
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

// Return value of action handlers
pub const Result = enum {
    continue_game, // Game still in progress
    end_game, // Quit, death, etc.
    ascend,
    descend,
};

//
// Members
//

kind: Type, // 'type' is a keyword
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

pub fn getType(self: *Self) Type {
    return self.kind;
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
    try expect(action.getType() == .move);
}

// EOF
