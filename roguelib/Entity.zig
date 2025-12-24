//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const MapTile = @import("maptile.zig").MapTile;
const Pos = @import("Pos.zig");
const queue = @import("queue.zig");

const Self = @This();

//
// Types
//

pub const EntityQueue = queue.Queue(Self, "node");

pub const VTable = struct {
    addMessage: ?*const fn (self: *Self, msg: []const u8) void = null,
};

//
// Members
//

// TODO Future: timer, action queue
p: Pos = undefined,
tile: MapTile = undefined,
vtable: *const VTable = undefined,
moves: i32 = 0,
node: queue.Node = .{},

//
// Constructor
//

pub fn config(tile: MapTile, vtable: *const VTable) Self {
    return .{
        .p = Pos.config(-1, -1),
        .tile = tile,
        .vtable = vtable,
    };
}

//
// Methods
//

pub fn getTile(self: *Self) MapTile {
    return self.tile;
}

pub fn getPos(self: *Self) Pos {
    return self.p;
}

pub fn setPos(self: *Self, p: Pos) void {
    self.p = p;
}

// VTable

pub fn addMessage(self: *Self, msg: []const u8) void {
    if (self.vtable.addMessage) |cb| {
        cb(self, msg);
    }
}

pub fn getMoves(self: *Self) i32 {
    return self.moves;
}

// TODO: POS METHODS

//
// Unit Tests
//

const expect = std.testing.expect;

test "entity queue" {
    var eq = EntityQueue.config();
    var vt: VTable = .{};

    var e = Self.config(.player, &vt);

    eq.enqueue(&e);
    try expect(eq.next() == &e);
}

// EOF
