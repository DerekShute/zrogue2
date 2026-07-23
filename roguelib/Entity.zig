//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const Action = @import("Action.zig");
const Map = @import("Map.zig");
const Pos = @import("Pos.zig");
const Region = @import("Region.zig");
const Tile = @import("common").Tile;

const Self = @This();

//
// Types
//

pub const VTable = struct {
    pub const Error = error{Failed};

    doAction: ?*const fn (self: *Self, map: *Map) Error!Action.Result = null,
};

pub const Config = struct {
    tile: Tile,
    vtable: *const VTable,
};

//
// Members
//

// FUTURE: timer, action queue
p: Pos = undefined,
tile: Tile = undefined,
vtable: *const VTable = undefined,
map_id: usize = undefined, // FUTURE: or pointer, uuid
moves: i32 = 0,

//
// Lifecycle
//

pub fn init(config: Config) Self {
    return .{
        .p = .init(-1, -1),
        .tile = config.tile,
        .vtable = config.vtable,
    };
}

//
// Methods
//

pub fn getTile(self: *Self) Tile {
    return self.tile;
}

pub fn getPos(self: *Self) Pos {
    return self.p;
}

pub fn setPos(self: *Self, p: Pos) void {
    self.p = p;
}

pub fn getMoves(self: *Self) i32 { // REFACTOR: cruft
    return self.moves;
}

pub fn getMapId(self: *Self) usize {
    return self.map_id;
}

pub fn setMapId(self: *Self, id: usize) void {
    self.map_id = id;
}

// VTable

pub fn doAction(self: *Self, map: *Map) !Action.Result {
    if (self.vtable.doAction) |cb| {
        return try cb(self, map);
    }
    return .continue_game;
}

//
// Unit Tests
//

const expect = std.testing.expect;
var testing_vt: VTable = .{};
const testing_config = Config{
    .tile = @enumFromInt(4),
    .vtable = &testing_vt,
};

test "basic use" {
    var e = Self.init(testing_config);
    try expect(@intFromEnum(e.getTile()) == 4);
    e.setMapId(4);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
