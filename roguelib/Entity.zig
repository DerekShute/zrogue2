//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const Action = @import("Action.zig");
const Map = @import("Map.zig");
const MapTile = @import("maptile.zig").MapTile;
const Pos = @import("Pos.zig");
const queue = @import("queue.zig");

const Self = @This();

//
// Types
//

pub const Queue = queue.Queue(Self, "node");

pub const VTable = struct {
    addMessage: ?*const fn (self: *Self, msg: []const u8) void = null,
    getAction: ?*const fn (self: *Self) Action = null,
    revealMap: ?*const fn (self: *Self, map: *Map, pos: Pos) void = null,
    setKnown: ?*const fn (self: *Self, map: *Map, loc: Pos, visible: bool) void = null,
    takeItem: ?*const fn (self: *Self, i: MapTile) void = null,
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

pub fn getMoves(self: *Self) i32 {
    return self.moves;
}

// VTable

pub fn addMessage(self: *Self, msg: []const u8) void {
    if (self.vtable.addMessage) |cb| {
        cb(self, msg);
    }
}

pub fn getAction(self: *Self) Action {
    if (self.vtable.getAction) |cb| {
        return cb(self);
    }
    return Action.config(.none);
}

pub fn revealMap(self: *Self, map: *Map, pos: Pos) void {
    if (self.vtable.revealMap) |cb| {
        cb(self, map, pos);
    }
}

pub fn setKnown(self: *Self, map: *Map, loc: Pos, visible: bool) void {
    if (self.vtable.setKnown) |cb| {
        cb(self, map, loc, visible);
    }
}

pub fn takeItem(self: *Self, i: MapTile) void {
    if (self.vtable.takeItem) |cb| {
        cb(self, i);
    }
}

//
// Unit Tests
//

const expect = std.testing.expect;

test "entity queue" {
    var eq = Queue.config();
    var vt: VTable = .{};

    var e = Self.config(.player, &vt);

    eq.enqueue(&e);
    try expect(eq.next() == &e);
}

// EOF
