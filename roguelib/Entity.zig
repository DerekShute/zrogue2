//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const Action = @import("Action.zig");
const Map = @import("Map.zig");
const MapTile = @import("maptile.zig").MapTile;
const Pos = @import("Pos.zig");

const Self = @This();

pub const VTable = struct {
    addMessage: ?*const fn (self: *Self, msg: []const u8) void = null,
    doAction: ?*const fn (self: *Self, map: *Map) Action.Result = null,
};

//
// Members
//

// TODO Future: timer, action queue
p: Pos = undefined,
tile: MapTile = undefined,
vtable: *const VTable = undefined,
moves: i32 = 0,

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

pub fn doAction(self: *Self, map: *Map) Action.Result {
    if (self.vtable.doAction) |cb| {
        return cb(self, map);
    }
    return .continue_game; // default answer: entity does nothing
}

//
// Unit Tests
//

// TODO: need a mock version

// EOF
