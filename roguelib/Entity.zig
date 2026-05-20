//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const Action = @import("Action.zig");
const DisplayTile = @import("common").DisplayTile;
const FOVMap = @import("fov/FOVMap.zig");
const Map = @import("Map.zig");
const MapTile = @import("Tileset.zig").MapTile;
const Pos = @import("Pos.zig");
const queue = @import("queue.zig");

const Self = @This();

//
// Types
//

pub const Queue = queue.Queue(Self, "node");

pub const VTable = struct {
    pub const Error = error{Failed};

    addMessage: ?*const fn (self: *Self, msg: []const u8) void = null,
    getAction: ?*const fn (self: *Self) Error!Action = null,
    setMapTile: ?*const fn (self: *Self, pos: Pos, tile: DisplayTile) void = null,
    takeItem: ?*const fn (self: *Self, i: MapTile) void = null,
};

pub const Config = struct {
    tile: MapTile,
    vtable: *const VTable,
};

//
// Members
//

// FUTURE: timer, action queue
p: Pos = undefined,
tile: MapTile = undefined,
vtable: *const VTable = undefined,
moves: i32 = 0,
node: queue.Node = .{},
fov: ?*FOVMap = null,

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

pub fn setFOV(self: *Self, fov: *FOVMap) void {
    self.fov = fov;
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

pub fn getAction(self: *Self) !Action {
    if (self.vtable.getAction) |cb| {
        return try cb(self);
    }
    return Action.config(.none);
}

pub fn takeItem(self: *Self, i: MapTile) void {
    // FUTURE this is a terrible idea, need an Item reference
    if (self.vtable.takeItem) |cb| {
        cb(self, i);
    }
}

// Field of Vision

pub fn setPosChanged(self: *Self, loc: Pos) void {
    if (self.fov) |fov| {
        fov.setChanged(loc, true);
    }
}

pub fn setPosVisible(self: *Self, loc: Pos, visible: bool) void {
    if (self.fov) |fov| {
        fov.setVisible(loc, visible);
    }
}

//
// It's up to the client and end UI to decide what to do with map areas that
// are no longer visible.  It could remove them from the display, or dim them,
// or only retain known-persistent features.
//
// This could be done piecemeal but that reduces opportunity for consolidation
//
// TODO: still not really cool with this
//
pub fn notifyDisplay(self: *Self, map: *Map) void {
    // FUTURE: consolidate identical tiles, have a count

    if (self.vtable.setMapTile) |smt| {
        if (self.fov) |fov| {
            var i = fov.iterator();
            while (i.next_changed()) |change| {
                var dt = DisplayTile.init; // not visible
                if (change.visible) {
                    const tile = map.getTileset(change.pos);
                    dt = DisplayTile{
                        .entity = @intFromEnum(tile.entity),
                        .floor = @intFromEnum(tile.floor),
                        .item = @intFromEnum(tile.item),
                        .visible = true,
                    };
                }
                smt(self, change.pos, dt);
            }
        }
    }
}

//
// Unit Tests
//

const expect = std.testing.expect;

test "entity queue" {
    var eq = Queue.config();
    var vt: VTable = .{};

    // TODO: this is kind of a problem.  The FOVMap is glued to this context

    var fov = try FOVMap.init(std.testing.allocator, 100, 100);
    defer fov.deinit(std.testing.allocator);

    const config = Config{
        .tile = .player,
        .vtable = &vt,
    };
    var e = Self.init(config);

    e.setFOV(&fov);

    eq.enqueue(&e);
    try expect(eq.next() == &e);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);
pub var fov_fields = genFields(FOVMap); // Harmless lie

// EOF
