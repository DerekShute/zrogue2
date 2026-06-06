//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const Action = @import("Action.zig");
const Map = @import("Map.zig");
const Pos = @import("Pos.zig");
const queue = @import("queue.zig");
const Region = @import("Region.zig");
const Tile = @import("common").Tile;

const Self = @This();

//
// Types
//

pub const Queue = queue.Queue(Self, "node");

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
moves: i32 = 0,
node: queue.Node = .{},

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

pub fn getMoves(self: *Self) i32 {
    return self.moves;
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

test "entity queue" {
    var eq = Queue.config();
    var vt: VTable = .{};

    const config = Config{
        .tile = @enumFromInt(4),
        .vtable = &vt,
    };
    var e = Self.init(config);

    try expect(@intFromEnum(e.getTile()) == 4);

    eq.enqueue(&e);
    try expect(eq.next() == &e);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
